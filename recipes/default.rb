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

# Figure out where to send the backups
target = "s3://s3-#{region}.amazonaws.com/#{bucket}/#{Chef::Config[:node_name]}"
log('Duply endpoint') do
  message "Duply S3 target: #{target}"
end

include_recipe 'yum-epel' if platform_family?('rhel')

# Configure Duply
directory '/etc/duply/s3' do
  action :create
  recursive true
end

# Using lazy variables because if we are generating a key that
# will not be available until convergence
template '/etc/duply/s3/conf' do
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
      source: node[:duply][:source]
    }
  }
end

template '/etc/duply/s3/exclude' do
  action :create
  source 'exclude.erb'
  variables(
    excludes: node[:duply][:exclude],
    includes: node[:duply][:include]
  )
end

# Setup cron
schedule = node[:duply][:schedule].split(' ')

fail 'Is [:duply][:schedule] a cron string?' unless schedule.length == 5

cron 'backup' do
  minute schedule[0]
  hour schedule[1]
  day schedule[2]
  month schedule[3]
  weekday schedule[4]
  command 'duply s3 backup'
end
