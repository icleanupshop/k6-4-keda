#k6 run --vus 10000 --duration 30m ./echo-server.js


docker build --tag k6 k6

if [ $? != 0 ]
then
	echo "FATAL: Docker build failed, stopped here, dude."
	exit -1
fi
	
docker run -it --name k6 --rm --network host -e K6_VIRTUAL_USER_COUNT=10000 k6
