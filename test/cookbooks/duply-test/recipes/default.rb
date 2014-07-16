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

# Extend the LVM VG with disk2 so snapshots can be created
execute 'vgextend vagrant-vg /dev/sdb' do
  not_if 'pvdisplay | grep "/dev/sdb" > /dev/null'
end
