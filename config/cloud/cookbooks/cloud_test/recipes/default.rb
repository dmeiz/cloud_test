require_recipe "apt"
#require_recipe "apache2"
require_recipe "mysql::server"
#require_recipe "ruby_enterprise" # leaving this out because we're bootstrapping the instance with ree

# this didn't work
#package "bundler" do
#  action :install
#  provider Chef::Provider::Package::Rubygems
#end
%w(whois zip unzip vim libgd2-xpm git-core graphicsmagick libxml2-dev libxslt1-dev).each do |name|
  package name do
  end
end

# this template allows users in the admin group to sudo without entering their
# own password
#
template "/etc/sudoers" do
  owner "root"
  group "root"
  mode "0440"
  source "sudoers"
end

template "/etc/timezone" do
  owner "root"
  group "root"
  mode "0644"
  source "timezone"
end

execute "set timezone" do
  command "dpkg-reconfigure --frontend noninteractive tzdata"
end

template "/home/ubuntu/.profile" do
  owner "ubuntu"
  group "ubuntu"
  mode "0755"
  source "profile"
end

template "/home/ubuntu/.gemrc" do
  owner "ubuntu"
  group "ubuntu"
  mode "0755"
  source "gemrc"
end

execute "update rubygems" do
  command "/usr/local/bin/gem update --system" 
end

execute "update bundler" do
  command "gem install -v 1.0.18 bundler" 
end
