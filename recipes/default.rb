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
  
  # libraries/hash.rb contains the magic that allows us to access
  # the json data via dots which cuts down on the cruft
  
  log("Job: #{job['id']}")

  # Configure Duply
  directory "/etc/duply/#{job['id']}" do
    action :create
    recursive true
  end

  mountpoint = File.join(node[:duply][:mount_under], "duply_#{job['id']}")
  
  directory mountpoint do
    action :create
    recursive true
  end

  target = "s3://s3-#{region}.amazonaws.com/#{bucket}/#{Chef::Config[:node_name]}/#{job['id']}"

  # Using lazy variables because the GPG key may not be known at compile time
  template "/etc/duply/#{job['id']}/conf" do
    action :create
    source 'conf.erb'
    mode '0600'
    variables lazy {
      {
        gpg_key_id: node[:duply][:gpg_key_id],
        passphrase: node[:duply][:gpg_pw],
        target: target,
        username: node[:duply][:s3][:aws_access_key],
        password: node[:duply][:s3][:aws_secret_key],
        source: mountpoint
      }
    }
  end  

  template "/etc/duply/#{job['id']}/exclude" do
    action :create
    source 'exclude.erb'
    variables(
      source: mountpoint,
      excludes: job['excludes'],
      includes: job['includes']
    )
  end

  template "/usr/local/sbin/backup_#{job['id']}" do
    action :create
    source 'backup.erb'
    mode '0755'
    variables(
      name: job['id'],
      snapshot_size: node[:duply][:snapshot_size],
      target_vg: job['target_vg'],
      target_lv: job['target_lv'],
      mount_point: mountpoint,
      min_free: node[:duply][:min_free]
    )
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
