docker stop k6-4-keda-newrelic-statsd
docker stop k6-4-keda-influxdb
docker stop k6-4-keda-k6
k3d cluster delete k6-4-keda-${HOSTNAME}
