mkdir -p /etc/dpkg/dpkg.cfg.d
cat >/etc/dpkg/dpkg.cfg.d/01_nodoc <<EOF
path-exclude /usr/share/doc/*
path-include /usr/share/doc/*/copyright
path-exclude /usr/share/man/*
path-exclude /usr/share/groff/*
path-exclude /usr/share/info/*
path-exclude /usr/share/lintian/*
path-exclude /usr/share/linda/*
EOF

export DEBIAN_FRONTEND=noninteractive
export APTARGS="-qq -o=Dpkg::Use-Pty=0"

apt-get clean ${APTARGS}
apt-get update ${APTARGS}

apt-get upgrade -y ${APTARGS}
apt-get dist-upgrade -y ${APTARGS}

# Update to the latest kernel
apt-get install -y linux-generic linux-image-generic ${APTARGS}

# build-essential
apt-get install -y build-essential ${APTARGS}

# for docker devicemapper
apt-get install -y thin-provisioning-tools ${APTARGS}

# some tools
apt-get install -y ${APTARGS} python-pip python3-pip git jq curl wget vim language-pack-en sysstat htop


# Install and setup python3.6 as default + idle
apt-get update
apt-get install -y software-properties-common
add-apt-repository -y ppa:jonathonf/python-3.6
apt-get update
apt-get install -y python3.6
update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.5 1
update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.6 2
echo -ne '\n' | update-alternatives --config python3

# Install Ruby, Rails, Mysql
#######################
# Function definition #
#######################

funcPermissions()
{
	[ "$(stat -c "%U %G" $1)" == "vagrant vagrant" ] || {
           chown -R vagrant.vagrant $1
        }
}

######################
# Main script starts #
######################

# Debug mode enabled
set -x

# Frequently used paths defined as variables
RBENV_PATH="/home/vagrant/.rbenv"
RUBY_BUILD_PATH="/home/vagrant/.rbenv/plugins/ruby-build"
GEMRC_PATH="/home/vagrant/.gemrc"
PROFILE="/home/vagrant/.bash_profile"

# Fix locale problem
grep LC_ALL="en_US.UTF-8" /etc/environment || {
  echo 'LC_ALL="en_US.UTF-8"' >> /etc/environment
}

# Install the dependencies required for rbenv and ruby
for PACKAGE in autoconf bison build-essential libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm3 libgdbm-dev libsqlite3-dev libmysqlclient-dev nodejs
do
	dpkg -l ${PACKAGE} || {
          apt-get update
	  apt-get install -y ${PACKAGE}
	}
done

# Install MySQL Server in a Non-Interactive mode. Default root password will be "vagrant"
dpkg --get-selections | grep mysql-server- || {
  export DEBIAN_FRONTEND=noninteractive
  debconf-set-selections <<< 'mysql-server mysql-server/root_password password vagrant'
  debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password vagrant'
  apt-get update
  apt-get install -y mysql-server
}

# Configure MySQL to listen on all IPs, if not configured
grep "bind-address		= 0.0.0.0" /etc/mysql/mysql.conf.d/mysqld.cnf || {
  cp /etc/mysql/mysql.conf.d/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf.bak
  cp /vagrant/conf/mysqld.cnf /etc/mysql/mysql.conf.d/
  systemctl restart mysql.service
}

# Allow root to connect from localhost without password
# ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '';
mysql -uroot -pvagrant -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '';"

# Install rbenv
[ -d ${RBENV_PATH} ] || {
  git clone https://github.com/rbenv/rbenv.git ${RBENV_PATH}
}

# Change permissions from root/root to vagrant/vagrant on .rbenv
funcPermissions ${RBENV_PATH}

# Check if .bash_profile exists and add some configuration
[ -f ${PROFILE} ] || {
  touch ${PROFILE}
  chown vagrant.vagrant ${PROFILE}
}

# Add rbenv to your path
grep '.rbenv/bin' ${PROFILE} || {
  echo 'export PATH="$HOME/.rbenv/bin:$PATH"' | sudo tee -a ${PROFILE}
}

grep 'rbenv init -' ${PROFILE} || {
 echo 'eval "$(rbenv init -)"' | sudo tee -a ${PROFILE}
}

# Install ruby-build
[ -d ${RUBY_BUILD_PATH} ] || {
  git clone https://github.com/rbenv/ruby-build.git ${RUBY_BUILD_PATH}
}

# Change permissions of ruby-build from root/root to vagrant/vagrant on ruby-build
funcPermissions ${RUBY_BUILD_PATH}

# Turn off local documentation for all gems we install
[ -f ${GEMRC_PATH} ] || {
  > ${GEMRC_PATH}
}

grep 'gem: --no-document' ${GEMRC_PATH} || {
  echo 'gem: --no-document' | sudo tee -a ${GEMRC_PATH}
}

# change permissions from root/root to vagrant/vagrant on .gemrc
funcPermissions $GEMRC_PATH



# prep for LXD
cat > /etc/security/limits.d/lxd.conf <<EOF
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
* soft memlock unlimited
* hard memlock unlimited
EOF

cat > /etc/sysctl.conf <<EOF
fs.inotify.max_queued_events=1048576
fs.inotify.max_user_instances=1048576
fs.inotify.max_user_watches=1048576
vm.max_map_count=262144
kernel.dmesg_restrict=1
net.ipv4.neigh.default.gc_thresh3=8192
net.ipv6.neigh.default.gc_thresh3=8192
EOF

# container top
wget https://github.com/bcicen/ctop/releases/download/v0.7.1/ctop-0.7.1-linux-amd64 -O /usr/local/bin/ctop
chmod +x /usr/local/bin/ctop

# Hide Ubuntu splash screen during OS Boot, so you can see if the boot hangs
apt-get remove -y plymouth-theme-ubuntu-text
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/GRUB_CMDLINE_LINUX_DEFAULT=""/' /etc/default/grub
update-grub

# Reboot with the new kernel
shutdown -r now
