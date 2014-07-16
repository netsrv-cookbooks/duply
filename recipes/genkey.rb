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

if node[:duply][:gpg_key_email].empty?
  fail 'Please set [:duply][:gpg_key_email]'
end

passphrase = (0...16).map { (65 + rand(26)).chr }.join

# TODO: do not expose passphrase
node.default[:duply][:gpg_pw] = passphrase

template "#{Chef::Config[:file_cache_path]}/gpgscript" do
  action :create
  source 'genkey.erb'
  variables(
    name: node[:duply][:gpg_key_name],
    email: node[:duply][:gpg_key_email],
    passphrase: passphrase
  )
end

ruby_block 'generate gpg key' do
  block do
    cmd = "gpg --batch --gen-key #{Chef::Config[:file_cache_path]}/gpgscript"
    gpg = Mixlib::ShellOut.new(cmd)
    gpg.run_command
    gpg.error!          # fail if non-zero exit
    puts gpg.stderr     # For reasons known only to little mice GPG writes to stderr

    # Extract 'gpg: key ABCDEF1234'
    keystr = gpg.stderr.match('gpg: key [^\s]+').to_s

    # Extract the id part
    node.normal[:duply][:gpg_key_id] = keystr[9...keystr.length]
  end
end

log('generated key') do
  message '!!!Generated new GPG key - please copy keys and passphrase!!!'
  level :warn
end
