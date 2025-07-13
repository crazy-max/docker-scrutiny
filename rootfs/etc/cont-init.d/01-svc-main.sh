#!/usr/bin/with-contenv sh
# shellcheck shell=sh

SCRUTINY_WEB_INFLUXDB_HOST=${SCRUTINY_WEB_INFLUXDB_HOST:-localhost}
SCRUTINY_WEB_INFLUXDB_PORT=${SCRUTINY_WEB_INFLUXDB_PORT:-8086}

echo "Waiting for InfluxDB to be ready..."
until curl --output /dev/null --silent --head --fail "http://${SCRUTINY_WEB_INFLUXDB_HOST}:${SCRUTINY_WEB_INFLUXDB_PORT}/health"; do
  sleep 2
done
echo "InfluxDB is ready!"

echo "S.M.A.R.T version: $(apk list --installed smartmontools | cut -d' ' -f1 | cut -d'-' -f2-)"

mkdir -p /etc/services.d/scrutiny
cat > /etc/services.d/scrutiny/run <<EOL
#!/usr/bin/execlineb -P
with-contenv
scrutiny start
EOL
chmod +x /etc/services.d/scrutiny/run

mkdir -p /etc/services.d/scrutiny-collector-oneshot
cat > /etc/services.d/scrutiny-collector-oneshot/run <<EOL
#!/usr/bin/with-contenv bash

if [ -f /tmp/.scrutiny-collector-oneshot-done ]; then
  s6-svc -d /run/s6/services/scrutiny-collector-oneshot
  exit 0
fi

echo "Waiting for scrutiny service to start..."
s6-svwait -u /run/s6/services/scrutiny
until curl --output /dev/null --silent --head --fail "http://localhost:8080/api/health"; do
  sleep 2
done

echo "Running scrutiny collector on startup..."
scrutiny-collector-metrics run

touch /tmp/.scrutiny-collector-oneshot-done
s6-svc -d /run/s6/services/scrutiny-collector-oneshot
exit 0
EOL
chmod +x /etc/services.d/scrutiny-collector-oneshot/run
