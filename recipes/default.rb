#
# Copyright (C) 2014 NetSrv Consulting Ltd.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

region = node[:duply][:s3][:region]
bucket = node[:duply][:s3][:bucket]
fail '[:duply][:s3][:bucket] must be your bucket name' if bucket.empty?

# Install some packages
%w(duply duplicity python-boto).each do |p|
  package p do
    action :install
  end
end

# Generate GPG keys if necessary
include_recipe 'duply::genkey' if node[:duply][:gpg_key_id].empty?

# How are we accessing S3?
if node[:duply][:s3][:use_iam_profile]    # For AWS instances
  log('Duply using IAM profile')
else                                      # For outside AWS
  log('Duply using supplied credentials')
  if node[:duply][:s3][:aws_access_key].empty?
    fail 'AWS access key must be configured'
  end
  if node[:duply][:s3][:aws_secret_key].empty?
    fail 'AWS secret key must be configured'
  end
end

include_recipe 'yum-epel' if platform_family?('rhel')

# Get the configuration for the current node
duply = data_bag_item(node[:duply][:databag], Chef::Config[:node_name])

duply['jobs'].each do |job|
  
  Chef::Log.info("Job: #{job['id']}")
  Chef::Log.info("Excludes: #{job['excludes']}")
  Chef::Log.info("Includes: #{job['includes']}")
  
  # ---------------------------------------------------------------- #
  # --- Setup some variables that we will use in resources later --- #
  # ---------------------------------------------------------------- #
  mountpoint = File.join(node[:duply][:mount_under], "duply_#{job['id']}")
  target = "s3://s3-#{region}.amazonaws.com/#{bucket}/#{Chef::Config[:node_name]}/#{job['id']}"
  script_vars = { name: job['id'] }
  
  case job['type']
  when 'lvm'
    # When backing up LVM we mount the snapshot
    base = mountpoint
    
    # Make sure base ends with a trailing /
    base << '/' unless base.end_with?('/')
    
    script_template = 'backup_lvm.erb'
    script_vars.merge!({
      snapshot_size: node[:duply][:snapshot_size],
      target_vg: job['target_vg'],
      target_lv: job['target_lv'],
      mount_point: mountpoint,
      min_free: node[:duply][:min_free]
    })
  else
    # When backing up directly we need to be relative to root
    base = '/'
    script_template = 'backup_default.erb'
  end

  # -- End var config
  
  directory "/etc/duply/#{job['id']}" do
    action :create
    recursive true
  end
  
  directory mountpoint do
    action :create
    recursive true
  end

  # Using lazy variables because the GPG key may not be known at compile time
  template "/etc/duply/#{job['id']}/conf" do
    action :create
    source 'conf.erb'
    mode '0600'
    sensitive true
    variables lazy {
      {
        gpg_key_id: node[:duply][:gpg_key_id],
        passphrase: node[:duply][:gpg_pw],
        target: target,
        username: node[:duply][:s3][:aws_access_key],
        password: node[:duply][:s3][:aws_secret_key],
        source: base,
        params: node[:duply][:params]
      }
    }
  end
  
  template "/etc/duply/#{job['id']}/exclude" do
    action :create
    source 'exclude.erb'
    variables(
      prefix: base == '/' ? '' : base,
      excludes: job['excludes'],
      includes: job['includes']
    )
  end
  
  template "/usr/local/sbin/backup_#{job['id']}" do
    action :create
    source script_template
    mode '0755'
    variables(script_vars)
  end

  # Setup cron
  schedule = job['schedule'].split(' ')

  cron "Backup job #{job['id']}" do
    minute schedule[0]
    hour schedule[1]
    day schedule[2]
    month schedule[3]
    weekday schedule[4]
    command "/usr/local/sbin/backup_#{job['id']}"
  end

end
