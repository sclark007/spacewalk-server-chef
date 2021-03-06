directory '/opt/spacewalk' do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

package 'perl-WWW-Mechanize' do
  action :install
end

# install scripts/crons for repo sync
remote_file '/opt/spacewalk/spacewalk-debian-sync.pl' do
  owner 'root'
  group 'root'
  mode '0755'
  source 'https://raw.githubusercontent.com/stevemeier/spacewalk-debian-sync/master/spacewalk-debian-sync.pl'
end

# fixes the missing compression lzma in python-debian-0.1.21-10.el6
# see https://bugzilla.redhat.com/show_bug.cgi?id=1021625
cookbook_file '/usr/lib/python2.6/site-packages/debian/debfile.py' do
  source 'debfile.py'
  owner 'root'
  group 'root'
  mode '0644'
end

node['spacewalk']['sync']['channels'].each do |name, url|
  cron "sw-repo-sync_#{name}" do
    hour node['spacewalk']['sync']['cron']['h']
    minute node['spacewalk']['sync']['cron']['m']
    command "/opt/spacewalk/spacewalk-debian-sync.pl --username '#{node['spacewalk']['sync']['user']}' --password '#{node['spacewalk']['sync']['password']}' --channel '#{name}' --url '#{url}'"
  end
end

# install scripts/crons for errata import
if node['spacewalk']['server']['errata']
  %w(perl-XML-Simple perl-Text-Unidecode).each do |pkg|
    package pkg do
      action :install
    end
  end

  %w(errata-import.pl parseUbuntu.py).each do |file|
    remote_file "/opt/spacewalk/#{file}" do
      owner 'root'
      group 'root'
      mode '0755'
      source "https://raw.githubusercontent.com/philicious/spacewalk-scripts/master/#{file}"
    end
  end

  template '/opt/spacewalk/spacewalk-errata.sh' do
    source 'spacewalk-errata-ubuntu.sh.erb'
    owner 'root'
    group 'root'
    mode '0755'
    variables(user: node['spacewalk']['sync']['user'],
              pass: node['spacewalk']['sync']['password'],
              server: node['spacewalk']['hostname'],
              exclude: node['spacewalk']['errata']['exclude-channels'])
  end

  cron 'sw-errata-import' do
    hour node['spacewalk']['errata']['cron']['h']
    minute node['spacewalk']['errata']['cron']['m']
    command '/opt/spacewalk/spacewalk-errata.sh'
  end

  directory '/opt/spacewalk/errata' do
    owner 'root'
    group 'root'
    mode '0755'
    action :create
  end
end
