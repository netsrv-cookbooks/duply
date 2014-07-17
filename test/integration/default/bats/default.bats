@test 'conf file exists' {
	[[ -f /etc/duply/root/conf ]]
}

@test 'exclude file exists' {
	[[ -f /etc/duply/root/exclude ]]
}

@test 'a backup execution script exists' {
  [[ -x '/usr/local/sbin/backup_root' ]]
}

@test 'crontab is set to run duply at 1am every day' {
	crontab -l | grep '0 1 \* \* \* /usr/local/sbin/backup_root' > /dev/null
}