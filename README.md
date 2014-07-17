# Duply
A Chef cookbook to install and configures Duply and Duplicity for secure backups of Linux nodes.

In LVM mode the cookbook will mount a snapshot of the logical volume and backup from there, minimising downtime.

It can also backup non-LVM systems, but care should be taken to ensure the file system remains consistent.

## Limitations
* Only Amazon S3 is supported as a back-end.
* Pre/post scripts must be supplied via other means (e.g. a wrapper cookbook)

## Usage
You will need to set some attributes before using this cookbook:

* If `[:duply][:s3][:use_iam_profile]` is false (default), you must provide valid credentials via attributes:
  * `[:duply][:s3][:aws_access_key]` must be set to your access key.
  * `[:duply][:s3][:aws_secret_key]` must be set to your secret key.
* `[:duply][:s3][:bucket]` must be set to the name of the bucket you wish you use (e.g. myorg-backups).
* If auto-generating the GPG key you must set `[:duply][:gpg_key_email]`

Backups will be encrypted with GPG and uploaded to *bucket/node_name* (e.g. myorg-backups/web1).

You need to configure a databag with the appropriate configuration.

You can change the name of the bag via the `[:duply][:databag]` attribute, it defaults to *duply*.

If the type is missing then the backup will be normal.  If it is set to *lvm* then a snapshot will
be created, mounted and the backup generated from there.

```
{
  "id" : "myjobname",
  "jobs" : [{
   "id": "root",
   "type": "lvm",
   "target_vg": "my_volume_group",  	(lvm only)
   "target_lv": "my_logical_volume",	(lvm only)
   "schedule": "0 1 * * *",
   "includes": ["/home"],
   "excludes": ["**/**"]
   }]
}
```

### Matching Files
This is configured via two attributes:

* `[:duply][:exclude]` - an array of string paths to exclude, defaults to ['**/**']
* `[:duply][:include]` - an array of string paths to include, defaults to ['/home']

## Security

### Distributing keys via other means
If you do not want a GPG key automatically created (see below) and are distributing keys via other means,
simply set `[:duply][:gpg_key_id]` and `[:duply][:gpg_pw]` accordingly.

The keys must be on root's default keyring.

### Generating keys automatically
A GPG key pair will automatically be created for you if `[:duply][:gpg_key_id]` is empty (default). 

* The name of the GPG key owner will default to "*node_name* Backup"
  * Can be configured via `[:duply][:gpg_key_name]`
* You must configure the email address to use by configuring the attribute `[:duply][:gpg_key_email]`.

#### Important

* Make sure you copy the generate public and secret keys onto secure storage
  * The keys can be found in /etc/duply/s3/*.asc
* Make sure you record the secret key passphrase and keep it somewhere safe
  * It can be viewed in the logs and via the node attribute `[:duply][:gpg_pw]`

**If either the secret key or the passphrase is lost, you will not be able to restore a backup.**

## Duplicity Options

`[:duply][:params]` is an array of option strings relevant to S3.  Defaults to:

* `--s3-use-rrs` - uses reduced redundancy storage.
* `--s3-use-new-style` - use new-style subdomain bucket addressing.

## Notes
### Key Generation in Virtualised Environments
Due to GPG's reliance on /dev/random (a blocking random number generator) the run can become blocked waiting for
sufficient entropy to become available.

That is something that can take a very long time in VMs due to lack of keyboard to hit or mouse to wiggle.

One option is to distribute keys to hosts via other means and set the `[:duply][:gpg_key_id]` attribute.

Alternatively you may wish to use a symmetric key (not impl'd yet) or install [haveged](http://www.issihosts.com/haveged/) 
to keep the entropy pool full. `duply::haveged` is a recipe to install the latter.

### Using AWS IAM
It is recommended that use use an IAM account for S3.  Here is an example IAM permissions policy:

```json
"Statement": [
{
  "Effect": "Allow",
  "Action": [
    "s3:ListBucket"
  ],
  "Resource": [ "arn:aws:s3:::your-bucket"]
},
{
  "Effect": "Allow",
  "Action": [
    "s3:PutObject",
    "s3:GetObject",
    "s3:GetObjectVersion"
  ],
  "Resource": [ "arn:aws:s3:::your-bucket/*"]
}
```
More advanced policies are possible if you are in EC2 - e.g. locking down the node to only a path within the bucket.

## Development
1. Clone this repository from GitHub:

        $ git clone git@github.com:netsrv-cookbooks/duply.git

2. Create a git branch

        $ git checkout -b my_bug_fix

3. Install dependencies:

        $ bundle install

4. Make your changes/patches/fixes, committing appropriately
5. Copy .kitchen.local.yml.dist to .kitchen.local.yml and edit it, setting attributes appropriately
6. Run the tests:
    - `bundle exec foodcritic -f any .`
    - `bundle exec rubocop`
    - `bundle exec kitchen test`

  In detail:
    - Foodcritic will catch any Chef-specific style errors
    - Rubocop will check for Ruby-specific style errors
    - Test Kitchen will run and converge the recipes

This cookbook supplies its own Vagrant template (see test/templates/Vagrantfile.erb) so that a
second disk can be attached to the VMs.  This enables testing of the LXC snapshot feature.  As a result 
only VirtualBox is currently supported for kitchen tests.

## License & Authors
- Author:: Colin Woodcock (<cwoodcock@netsrv-consulting.com>)

```text
Copyright 2014, NetSrv Consulting Ltd.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
