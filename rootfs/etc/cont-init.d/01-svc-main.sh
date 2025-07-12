#!/usr/bin/with-contenv sh
# shellcheck shell=sh

SCRUTINY_WEB_INFLUXDB_HOST=${SCRUTINY_WEB_INFLUXDB_HOST:-localhost}
SCRUTINY_WEB_INFLUXDB_PORT=${SCRUTINY_WEB_INFLUXDB_PORT:-8086}

echo "Waiting for InfluxDB to be ready..."
until curl --output /dev/null --silent --head --fail "http://${SCRUTINY_WEB_INFLUXDB_HOST}:${SCRUTINY_WEB_INFLUXDB_PORT}/health"; do
  sleep 2
done
echo "InfluxDB is ready!"

echo "Running Scrutiny collector..."
scrutiny-collector-metrics run

mkdir -p /etc/services.d/scrutiny
cat > /etc/services.d/scrutiny/run <<EOL
#!/usr/bin/execlineb -P
with-contenv
scrutiny start
EOL
chmod +x /etc/services.d/scrutiny/run
