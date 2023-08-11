influxd &


export INFLUXDB_TOKEN=${INFLUXDB_TOKEN:="k6"}
export INFLUXDB_PASSWORD=${INFLUXDB_PASSWORD:='changeMe'}
export INFLUXDB_HOST=${INFLUXDB_HOST:='http://localhost'}
export INFLUXDB_PORT=${INFLUXDB_PORT:='8086'}
export INFLUXDB_USERNAME=${INFLUXDB_USERNAME:='k6'}
export INFLUXDB_BUCKET=${INFLUXDB_BUCKET:='k6'}
export INFLUXDB_ORG=${INFLUXDB_ORG:='k6'}
export INFLUXDB_RETENTION=${INFLUXDB_RETENTION:='0'}

sleep 5

influx setup --host ${INFLUXDB_HOST}:${INFLUXDB_PORT} --skip-verify -f --username ${INFLUXDB_USERNAME} --password ${INFLUXDB_PASSWORD} --token ${INFLUXDB_TOKEN} --org ${INFLUXDB_ORG} --bucket ${INFLUXDB_BUCKET} --retention ${INFLUXDB_RETENTION} --name k6                                                                           

bash
