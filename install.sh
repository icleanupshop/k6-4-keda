#!/usr/bin/bash
############################################################
# Global Vaiables (Human, do not edit anything in below)   #
############################################################
HOSTNAME=`hostname`
NR_REGION="US"


############################################################
# Functions                                                #
############################################################
function help()
{
   # Display Help
   echo "Welcome human to the k6 4(for) KEDA exprience. This script will install"
   echo "will setup a new k3d cluster with a metrics exported to an local influxDB or"
   echo "to NewRelic. With newrelic metric exports, you can make NRQL quires to scale. Happy days!"
   echo
   echo "Syntax: ./install [-i|k|a|e|l]"
   echo "options:"
   echo "i     install k3d with KEDA and local statsD for NR."
   echo "k     NR ingest license key."
   echo "q     NR browse license key."
   echo "a     NR account number."
   echo "e     To use NR EU, by default statsD will use the US NR,"
   echo "l     IP address for influxDB to listen for connections."
   echo "      This is an interface on your local machine (YOU CAN NOT USE THE loopback device)."

   echo
}

function log() {
    LOG_LEVEL=$1
    LOG_MESSAGE=$2
    echo "$LOG_LEVEL: $LOG_MESSAGE"
}

function fileInMyPath () {
    COMMAND=$1
    which $COMMAND
    if [ $? == 0 ]
    then
        return 0
    else
        return 1
    fi
}

function install () {
    #k3d
    echo "INFO: Checking if k3d is in my PATH..."
    which k3d

    #kubectl
    log "INFO" "Checking if kubectl is in my PATH..."
    if [ $(fileInMyPath kubectl) ]
    then
        log "INFO" "Nice you have kubectl in my path."
    else
        log "FATAL" "No kubectl, exiting."
        exit 1
    fi

    if [ $? == 0 ]
    then
        echo "INFO: I can see it, I can see it! But, is it the right version..."
        k3d_version_output=`k3d --version`
        k3d_version=`echo $k3d_version_output | cut -d ' ' -f 3`
        if [ $k3d_version == 'v5.5.2' ]
        then
            echo "INFO: Found the right version, v5.5.2"
        else
            echo "FATAL: Yeah, you have k3d, but not version v5.5.2. Exiting, laters."
            exit 1
        fi
    else
            echo "FATAL: This where we part ways, NO k3d in my path, so cant help you. Sort yourself out, dude."
            exit 1
    fi

    if [ $(fileInMyPath helm) ]
    then
        log "INFO" "You got helm, nice, we need that big time."
    else
        log "FATAL" "No helm. This is where out story ends. Please install if you want me to give you the business"
        exit 1
    fi


    #Create k3d cluster to host KEDA and its bits
    K6_K3D_CLUSTER_NAME=k6-4-keda-${HOSTNAME} 
    log "INFO" "Setting k3d cluster name to ${K6_K3D_CLUSTER_NAME}.DONE"

    log "INFO" "Creating k3d cluster with name ${K6_K3D_CLUSTER_NAME}."
    k3d cluster create $K6_K3D_CLUSTER_NAME
    log "INFO" "Creating k3d cluster with name ${K6_K3D_CLUSTER_NAME}.DONE"

    #Remove traefik as we dont need it in the k3d cluster
    kubectl delete service traefik -n kube-system --context k3d-${K6_K3D_CLUSTER_NAME}


    #Release KSM into the k3d cluster 
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    helm install --kube-context k3d-${K6_K3D_CLUSTER_NAME} kube-state-metrics prometheus-community/kube-state-metrics


    #Release echo-server deployment and ingress into the k3d cluster
    kubectl apply -f ./echo-server/deployment.yaml --context k3d-${K6_K3D_CLUSTER_NAME}
    kubectl apply -f ./echo-server/service-load-balancer.yaml --context k3d-${K6_K3D_CLUSTER_NAME}

    #NRI Stats
    docker stop k6-4-keda-newrelic-statsd 
    docker run --rm  -d\
    --name k6-4-keda-newrelic-statsd \
    -h $(hostname) \
    -e NR_ACCOUNT_ID=${NR_ACCOUNT_ID} \
    -e NR_API_KEY=${NR_API_KEY} \
    -p 8125:8125/udp \
    ${NR_EU_OPTION} \
    newrelic/nri-statsd:test

    #Build and run influxDB docker image/container
    docker stop k6-4-keda-infuxdb
    docker build --tag k6-4-keda-influxdb influxdb
    docker run --rm -it -d --name k6-4-keda-influxdb --network host k6-4-keda-influxdb

    #Build k6 docker image
    docker build --tag k6-4-keda-k6 k6


    #Install NR agent for NR into the k3d cluster (This streams k8. metrics into NR)
    helm install --kube-context k3d-${K6_K3D_CLUSTER_NAME} newrelic-infrastructure ./newrelic-infrastructure \
    --set cluster=k3d-${K6_K3D_CLUSTER_NAME} \
    --set licenseKey=${NR_API_KEY}

    #Install KEDA
    helm repo add kedacore https://kedacore.github.io/charts
    helm repo update
    helm install --kube-context k3d-${K6_K3D_CLUSTER_NAME} keda kedacore/keda --namespace keda --create-namespace

    #Install the KEDA scaledobject CRD for a simple scaling event
    #sed -i -r "s/<<LOCAL_IP>>/$LOCAL_IP/g" echo-server/keda.yaml
    ( cat echo-server/keda.yaml | \
    NR_ACCOUNT_ID=${NR_ACCOUNT_ID} \
    NR_BROWSE_KEY=${NR_BROWSE_KEY} \
    NR_REGION=${NR_REGION} \
    LOCAL_IP=${LOCAL_IP} \
    INFLUXDB_TOKEN=${INFLUXDB_TOKEN} \
    envsubst ) | \
    k apply --context k3d-${K6_K3D_CLUSTER_NAME} -f - 

    RETRIES=10
    WAIT_TIME_BETWEEN_RETRIES=10
    ATTEMPTS=0
    log "INFO" "Getting IP of echo-server kubernetes LB..."
    while [ $ATTEMPTS -le $RETRIES ]
    do
        ((ATTEMPTS++))
        log "INFO" "Attempt number $ATTEMPTS."
        ECHO_SERVER_IP_ADDRESS=`kubectl  get service helloweb | grep -v NAME |  tr -s ' ' | cut -d ' ' -f 4`
        if [[ $ECHO_SERVER_IP_ADDRESS =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
        then
            log "INFO" "Got it $ECHO_SERVER_IP_ADDRESS"
            ATTEMPTS=11
        else
		sleep $WAIT_TIME_BETWEEN_RETRIES
	fi
    done
    sed -i -r "s/<<ECHO_SERVER_IP_ADDRESS>>/$ECHO_SERVER_IP_ADDRESS/g" ./k6/test.js
    
    log "INFO" "I think it is installed.  Running a quick 1 VU k6 test for 1 minute, just to check things out, then I'll drop you into a bash within the k6 container. You're welcome."

    docker run -it --name k6-4-keda-k6 --rm --network host -e K6_VIRTUAL_USER_COUNT=1 -e K6_OUTPUT_INTEGRATION=statsd -e K6_TEST_DURATION='1m' k6-4-keda-k6 

    log "INFO" "Hope that work, because I'm done, you're on your own from now on. Bonne chance!"



}


############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts "h:e:a:k:q:l:" option; do
   case $option in
      h) # display Help
         help
         exit;;
      e) #OPTIONAL: TO use the EU NR ingest endpoints
         NR_EU_OPTION="-e NR_EU_REGION=true \\"
         NR_REGION="EU";;
      a) # Set NR account number
         NR_ACCOUNT_ID=$OPTARG;;
      k) #Set NR ingest(write) key
         NR_API_KEY=$OPTARG;;
      q) #Set NR browse(read only) key so KEDA scaled objects can send NRQL
         NR_BROWSE_KEY=$OPTARG;;   
      l) #Set the IP address for influxDB in the local host
         LOCAL_IP=$OPTARG;;  
     \?) # Invalid option
         echo "Error: Invalid option"
         exit;;    
   esac
done

############################################################
# The business                                             #
############################################################
install




