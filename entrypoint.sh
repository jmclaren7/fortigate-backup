#!/bin/sh

# Check if FG_CRON environment variable is set
if [ -z "$FG_CRON" ]; then
  echo "FG_CRON environment variable is not set. Exiting."
  exit 1
fi

# Save the environment variables so they can be accessed by the cron job
printenv | grep -v "no_proxy" >> /etc/environment

# Create the cron job
mkdir /etc/cron.d
echo "$FG_CRON /usr/bin/pwsh /fg-backup.ps1 >> /var/log/fg-backup.log 2>&1" > /etc/cron.d/fg-backup
echo "Cron job schedule: $FG_CRON"

# Give execution rights on the cron job file
chmod 0644 /etc/cron.d/fg-backup

# Apply cron job
crontab /etc/cron.d/fg-backup

# Create the log file to be able to run tail
touch /var/log/fg-backup.log

# Start the cron service
crond

# Tail the log file to keep the container running
tail -f /var/log/fg-backup.log