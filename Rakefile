require "rubygems"
require "bundler/setup"
require 'yaml'
require 'fog'
require 'hydra'
require 'hydra/tasks'

require 'ruby-debug'
Debugger.start

#Fog.mock!

include Rake::DSL
Hydra::TestTask.new('hydra:units') do |t|
  RAILS_ENV = 'test'
  t.environment = 'test'
#  t.verbose = true
#  t.add_files 'test/unit/single_test.rb'
  t.add_files 'test/**/*_test.rb'
end

namespace :cloud do
  task :environment do
  end

  task :config => :environment do
    raise %q(Couldn't find config/cloud.yml) unless File.exists?('config/cloud.yml')
    @config = YAML.load_file('config/cloud.yml')
    @state = File.exists?('cloud-state.yml') ? YAML.load_file('cloud-state.yml') : {}
    @compute = Fog::Compute.new(
      :provider => 'AWS',
      :aws_access_key_id => @config['access_key_id'],
      :aws_secret_access_key => @config['secret_access_key']
    )
  end

  namespace :master do
    desc 'Create the master instance'
    task :create => :config do
      print 'Creating master instance...'
      instance = create_instance('master', @config['seed_ami'])
      instance.wait_for { ready? }

      @state['master_id'] = instance.id
      save_yaml('cloud-state.yml', @state)

      puts 'ok'
    end

    desc 'Install packages necessary to run chef'
    task :bootstrap => :config do
      instance = @compute.servers.get(@state['master_id'])
      instance.private_key = File.read(@config['private_key_path'])
      puts instance.ssh("sudo apt-get update").first.stdout
      puts instance.ssh("sudo apt-get -y install gcc").first.stdout
      puts instance.ssh("wget http://rubyenterpriseedition.googlecode.com/files/ruby-enterprise_1.8.7-2011.03_i386_ubuntu10.04.deb").first.stdout
      puts instance.ssh("sudo dpkg -i ruby-enterprise_1.8.7-2011.03_i386_ubuntu10.04.deb").first.stdout
      puts instance.ssh("sudo gem install --no-ri --no-rdoc chef").first.stdout
      puts "Bootstrap complete"
    end

    desc 'Start master instance'
    task :start => :config do
      print 'Starting master instance...'
      instance = @compute.servers.get(@state['master_id'])
      instance.start
      instance.wait_for { ready? }
      puts 'ok'
    end

    desc 'Stop master instance'
    task :stop => :config do
      print 'Stopping master instance...'
      instance = @compute.servers.get(@state['master_id'])
      instance.stop
      instance.wait_for { state == 'stopped' }
      puts "ok"
    end

    desc 'Display master status'
    task :status => :config do
      puts @compute.servers.get(@state['master_id']).inspect
    end

    desc 'Ssh into master instance'
    task :ssh => :config do
      instance = @compute.servers.get(@state['master_id'])
      system("ssh -i #{@config['private_key_path']} -o 'StrictHostKeyChecking no' ubuntu@#{instance.dns_name}")
    end

    desc 'Configure master instance using chef'
    task :chef => :config do
      instance = @compute.servers.get(@state['master_id'])
      instance.private_key = File.read(@config['private_key_path'])

      print 'Copying chef configuration files...'
      instance.scp("config/cloud/cookbooks", "/home/ubuntu", :recursive => true)
      instance.scp("config/cloud/solo.rb", "/home/ubuntu")
      instance.scp("config/cloud/node.json", "/home/ubuntu")
      puts 'ok'

      print 'Running chef...'
      instance.ssh("sudo chef-solo -c /home/ubuntu/solo.rb -j /home/ubuntu/node.json")
      puts 'ok'
    end

    desc 'Sync working directory to master instance'
    task :sync => :config do
      instance = @compute.servers.get(@state['master_id'])
      instance.private_key = File.read(@config['private_key_path'])

      print 'Syncing working directory...'
      system(%Q(rsync -r -q -e "ssh -q -i #{@config['private_key_path']} -o 'UserKnownHostsFile /dev/null' -o 'StrictHostKeyChecking no'" --exclude .git --exclude log --exclude public/assets ./ ubuntu@#{instance.dns_name}:/home/ubuntu/cloud_test/))
      puts 'ok'
    end

    desc 'Run bundle on master instance'
    task :bundle => :config do
      instance = @compute.servers.get(@state['master_id'])
      instance.private_key = File.read(@config['private_key_path'])

      print 'Running bundle...'
      instance.ssh('cd cloud_test; bundle')
      puts 'ok'
    end

    desc 'Prepare database for testing on master instance'
    task :prepare_db => :config do
      instance = @compute.servers.get(@state['master_id'])
      instance.private_key = File.read(@config['private_key_path'])

      print 'Preparing database on master instance...'
      instance.ssh('mysqladmin -uroot drop -f phil_dev; mysqladmin -uroot create phil_dev')
      instance.ssh('mysqladmin -uroot drop -f phil_test; mysqladmin -uroot create phil_test')
      instance.ssh('cd cloud_test; RAILS_ENV=development rake db:structure:load; RAILS_ENV=test rake db:structure:load')
      puts 'ok'
    end

    desc 'Create ami from master instance'
    task :ami => :config do
      print 'Creating AMI from master instance...'
      resp = @compute.create_image(@state['master_id'], 'cloud_test', 'cloud_test')
      image_id = resp.body['imageId']
      Fog.wait_for do
        resp = @compute.describe_images('ImageId' => image_id)
        resp.body['imagesSet'].first['imageState'] == 'available'
      end
      @state['cluster_ami'] = image_id
      save_yaml('cloud-state.yml', @state)
      puts 'ok'
    end
  end

  namespace :cluster do
    desc 'Create cluster'
    task :create => :config do
      print "Creating cluster with #{@config['cluster_size']} instances..."
      instances = []
      @config['cluster_size'].times do |i|
        instances << create_instance('cluster', @state['cluster_ami'] || @config['cluster_ami'])
      end

      Fog.wait_for {instances.all? {|instance| instance.reload.ready?}} # reload instance to get its dns_name
#      Fog.wait_for {servers.all? {|server| Kernel.system("ssh -o 'StrictHostKeyChecking no' razoo@#{server.dns_name} 'cd'")}}
      @state['cluster_ids'] = instances.map(&:id)
      save_yaml('cloud-state.yml', @state)
      write_hydra_yml
#      update_hydra_config
      puts 'ok'
    end

    desc 'Start cluster'
    task :start => :config do
      print "Starting cluster..."
      instances = @compute.servers.select {|instance| @state['cluster_ids'].include?(instance.id)}
      instances.each {|instance| instance.start}
      Fog.wait_for {instances.all? {|instance| instance.reload.ready?}}
      write_hydra_yml
      puts 'ok'
    end

    desc 'Show cluster status'
    task :status => :config do
      @compute.servers.all('instance-id' => @state['cluster_ids']).each do |instance|
        puts "#{instance.id} #{instance.dns_name} #{instance.state}"
      end
    end

    desc 'Show cluster load'
    task :load => :config do
      instances = @compute.servers.all('instance-id' => @state['cluster_ids'])
      private_key = File.read(@config['private_key_path'])
      instances.each {|instance| instance.private_key = private_key}
      while true do
        thread_group = ThreadGroup.new
        instances.each do |instance|
          thread = Thread.new do
            puts instance.ssh('uptime').first.stdout
          end
          thread_group.add thread
        end

        thread_group.list.each {|thread| thread.join}
        sleep 2
      end
    end

    desc 'Sync cluster instances'
    task :sync => :config do
      print 'Syncing...'

      thread_group = ThreadGroup.new
      exclude = %w(.git log public/assets .snapshot db/refresh_data tmp yard .yardoc db/populate doc).collect {|dir| "--exclude #{dir}"}.join(" ")
      @compute.servers.all('instance-id' => @state['cluster_ids']).each do |instance|
        thread = Thread.new do
          system(%Q(rsync -r -q -e "ssh -q -i #{@config['private_key_path']} -o 'UserKnownHostsFile /dev/null' -o 'StrictHostKeyChecking no'" #{exclude} ./ ubuntu@#{instance.dns_name}:/home/ubuntu/cloud_test/))
        end
        thread_group.add thread
      end

      thread_group.list.each {|thread| thread.join}

      puts 'ok'
    end

    desc 'Bundle cluster instances'
    task :bundle => :config do
      print 'Syncing and bundling...'

      thread_group = ThreadGroup.new
      @compute.servers.all('instance-id' => @state['cluster_ids']).each do |instance|
        thread = Thread.new do
          system("ssh -q -i #{@config['private_key_path']} -o 'UserKnownHostsFile /dev/null' -o 'StrictHostKeyChecking no' ubuntu@#{instance.dns_name} 'cd cloud_test; bundle install'")
        end
        thread_group.add thread
      end

      thread_group.list.each {|thread| thread.join}

      puts 'ok'
    end

    desc 'Prepare database on cluster instances'
    task :prepare_db => :config do
      print 'Preparing db...'

      thread_group = ThreadGroup.new
      @compute.servers.all('instance-id' => @state['cluster_ids']).each do |instance|
        thread = Thread.new do
          #system("ssh -q -i #{@config['private_key_path']} -o 'UserKnownHostsFile /dev/null' -o 'StrictHostKeyChecking no' ubuntu@#{instance.dns_name} 'mysqladmin -uroot drop -f phil_dev; mysqladmin -uroot create phil_dev'")
          #system("ssh -q -i #{@config['private_key_path']} -o 'UserKnownHostsFile /dev/null' -o 'StrictHostKeyChecking no' ubuntu@#{instance.dns_name} 'mysqladmin -uroot drop -f phil_test; mysqladmin -uroot create phil_test'")
          system("ssh -q -i #{@config['private_key_path']} -o 'UserKnownHostsFile /dev/null' -o 'StrictHostKeyChecking no' ubuntu@#{instance.dns_name} 'cd cloud_test; RAILS_ENV=development rake db:structure:load; RAILS_ENV=test rake db:structure:load'")
        end
        thread_group.add thread
      end

      thread_group.list.each {|thread| thread.join}

      puts 'ok'
    end

    desc 'Ssh into first cluster instance'
    task :ssh => :config do
      instance = @compute.servers.get(@state['cluster_ids'].first)
      system("ssh -i #{@config['private_key_path']} -o 'StrictHostKeyChecking no' ubuntu@#{instance.dns_name}")
    end

    desc 'Stop cluster'
    task :stop => :config do
      print "Stopping cluster..."
      instances = @compute.servers.select {|instance| @state['cluster_ids'].include?(instance.id)}
      instances.each {|instance| instance.stop}
      Fog.wait_for {instances.all? {|instance| instance.reload.state == 'stopped'}}
      puts 'ok'
    end
  end
end

def create_instance(name, ami)
  @compute.servers.create(
    :name => name,
    :image_id => ami,
    :key_name => @config['key_name'],
    :flavor_id => @config['flavor_id'],
    :groups => @config['security_group']
  )
end

def save_yaml(path, hash)
  File.open(path, 'w') do |f|
    f.write(hash.to_yaml)
  end
end

def write_hydra_yml
  hydra = {}
  hydra['workers'] = @compute.servers.all('instance-id' => @state['cluster_ids']).map do |instance|
    {
      'type' => 'ssh',
      'connect' => "ubuntu@#{instance.dns_name}",
      'ssh_opts' => "-q -i #{@config['private_key_path']} -o 'UserKnownHostsFile /dev/null' -o 'StrictHostKeyChecking no'",
      'directory' => '/home/ubuntu/cloud_test',
      'runners' => 1
    }
  end
  save_yaml('config/hydra.yml', hydra)
end
