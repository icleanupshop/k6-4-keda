docker build --tag k6 k6

if [ $? != 0 ]
then
	echo "FATAL: Docker build failed, stopped here, dude."
	exit -1
fi
	
docker run -it --name k6 --rm --network host -e K6_VIRTUAL_USER_COUNT=$1 -e K6_OUTPUT_INTEGRATION=statsd -e K6_TEST_DURATION='10m' k6
