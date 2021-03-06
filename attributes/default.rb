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

# The additional parameters passed to Duplicity
default[:duply][:params] = ['--s3-use-new-style','--s3-use-rrs']

default[:duply][:gpg_key_id] = ''
default[:duply][:gpg_pw] = ''
default[:duply][:gpg_key_server] = 'keys.gnupg.net'

# Only used during key generation
default[:duply][:gpg_key_name] = "#{Chef::Config[:node_name]} Backup"
default[:duply][:gpg_key_email] = ''

default[:duply][:mount_under] = '/mnt'

# The minimum amount of space that must exist on the target VG (in bytes)
default[:duply][:min_free] = '256000'

# The amount of free VG space to consume for the snapshot
default[:duply][:snapshot_size] = '100%FREE'

# The name of the databag to use
default[:duply][:databag] = 'duply'

default[:duply][:s3][:region] = 'eu-west-1'
default[:duply][:s3][:bucket] = ''
default[:duply][:s3][:use_iam_profile] = false
default[:duply][:s3][:aws_access_key] = ''
default[:duply][:s3][:aws_secret_key] = ''
