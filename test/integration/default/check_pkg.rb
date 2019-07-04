describe package('build-essential') do
  it { should be_installed }
end

describe package('libssl-dev') do
  it { should be_installed }
end

describe package('libyaml-dev') do
  it { should be_installed }
end

describe package('libreadline6-dev') do
  it { should be_installed }
end

describe package('zlib1g-dev') do
  it { should be_installed }
end

describe package('libmysqlclient-dev') do
  it { should be_installed }
end

describe package('libffi-dev') do
  it { should be_installed }
end

describe package('libgdbm3') do
  it { should be_installed }
end

describe package('libgdbm-dev') do
  it { should be_installed }
end

describe package('libsqlite3-dev') do
  it { should be_installed }
end

describe package('libmysqlclient-dev') do
  it { should be_installed }
end

describe package('nodejs') do
  it { should be_installed }
end

describe service('mysql') do
  it { should be_enabled }
  it { should be_installed }
  it { should be_running }
end

describe bash('/home/vagrant/.rbenv/shims/rails -v') do
  its('stdout') { should match 'Rails 5.2.3' }
  its('exit_status') { should eq 0 }
end

describe bash('/home/vagrant/.rbenv/shims/ruby -v') do
  its('stdout') { should match "ruby 2.6.3p62 (2019-04-16 revision 67580) [x86_64-linux]\n" }
  its('exit_status') { should eq 0 }
end
