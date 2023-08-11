# k6-4-keda
A simple container to inject load on to a k3d cluster hosting KEDA for scaling. This getup is will release an
echo service kubernetes deplyoment along with docker containers to provide a k6 load injector. Metrics from the
k3d and k6 are sent to 2 collectors. An internal influxDB collector (scraper) and a NRI-statsD collector. K6 and the
collectors are docker containers seperate from the k3d cluster used to host the echo server. K6 and collectors are 
seprate from the k3d echo service to prevent cross contamination between the load injector and the target.

#Pre-Reqs
You need to have k3d version 5.5.2 install with docker version 20.10.25 in the path of the user executing k6-4-keda

The following ports need to be free on all interfaces on the host running this stack:

TCP/UDP 8086 - InfluxDB
TCP     80   - echo-service


#Installation
Run the install.sh shell script and provide the following (PLEASE NOTE: InfluxDB is always setup by default, NRI is optional)
./install.sh -k ******************************FFFFNRAL -a ******* -q NRAK-**************************************** -l 192.168.0.20

-k [NR INGEST API KEY]
-a [NR ACCOUNT NUMBER]
-q [NR BROWSER API KEY]
-l [LOCAL IP ADDRESS] #PLEASE NOTE: This MUST be the IP of the main interface on the local machine running the state. It can NOT be the loopback device.


When install is completed, you can then kick off a k6 load test with:
inject_k6_local -v 100 -d 5m #This will start a k6 test with 100 virtual users for 5 minutes


You can also edit the k6 test script located in to minuplate what requests k6 sends to the echo service 

/test-scripts/test.js

You can also change the KEDA shared object located, from outside the k6 docker container, by directly editing the 
KEDA shared object direct from the k3d cluster

kubectl edit scaledobject -n default --context k3d-k6-4-keda-${HOSTNAME}


#Issues
There are places to review logs if there are issues. First, check the statsD logs using:

docker logs newrelic-statsd -f

and the logs for KEDA using:

kubectl logs pod/keda-operator -n keda --context k3d-k6-4-keda-${HOSTNAME}

#Uninstall
When you're done, please run ./uninstall.sh to remove everything installed.
Please remember to docker rmi any docker images created for this stack.

 “The greatest trick the devil ever pulled was convincing the world he did not exist.”  Kaiser Sousse 