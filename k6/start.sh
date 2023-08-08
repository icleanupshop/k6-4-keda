influxd &

influx setup --skip-verify --username k6 --password Qwerty123 --token k6 --org k6 --bucket k6 --retention 0 

fg
#K6_INFLUXDB_ORGANIZATION="k6" \
#K6_INFLUXDB_BUCKET="k6" \
#K6_INFLUXDB_TOKEN="k6" \
#K6_INFLUXDB_ADDR="127.0.0.1:8086" \
#k6 run --vus 10000 --duration 30m /test_scripts/test.js -o xk6-influxdb
