#!/usr/bin/with-contenv sh
# shellcheck shell=sh

CRONTAB_PATH="/var/spool/cron/crontabs"

COLLECTOR_CRON_SCHEDULE=${COLLECTOR_CRON_SCHEDULE:-"0 0 * * *"}

# Init
rm -rf ${CRONTAB_PATH}
mkdir -m 0644 -p ${CRONTAB_PATH}
touch ${CRONTAB_PATH}/scrutiny

# Cron
if [ -n "$COLLECTOR_CRON_SCHEDULE" ]; then
  echo "Creating scrutiny collector cron task with the following period fields : $COLLECTOR_CRON_SCHEDULE"
  echo "${COLLECTOR_CRON_SCHEDULE} scrutiny-collector-metrics run" >> ${CRONTAB_PATH}/scrutiny
else
  echo "COLLECTOR_CRON_SCHEDULE env var empty..."
fi

# Fix perms
echo "Fixing crontabs permissions..."
chmod -R 0644 ${CRONTAB_PATH}

# Create service
mkdir -p /etc/services.d/cron
cat > /etc/services.d/cron/run <<EOL
#!/usr/bin/execlineb -P
with-contenv
exec busybox crond -f -L /dev/stdout
EOL
chmod +x /etc/services.d/cron/run
