@test 'conf file exists' {
	[[ -f /etc/duply/s3/conf ]]
}

@test 'exclude file exists' {
	[[ -f /etc/duply/s3/exclude ]]
}

@test 'crontab is set to run duply at 1am every day' {
	crontab -l | grep '0 1 \* \* \* duply s3 backup' > /dev/null
}