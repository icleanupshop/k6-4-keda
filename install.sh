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
   echo "Syntax: ./install [-i|k|a|e]"
   echo "options:"
   echo "i     install k3d with KEDA and local statsD for NR."
   echo "k     NR ingest license key."
   echo "a     NR account number."
   echo "e     To use NR EU, by default statsD will use the US NR."
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
        echo $k3d_version
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
    docker stop newrelic-statsd 
    docker run --rm  -d\
    --name newrelic-statsd \
    -h $(hostname) \
    -e NR_ACCOUNT_ID=${NR_ACCOUNT_ID} \
    -e NR_API_KEY=${NR_API_KEY} \
    -p 8125:8125/udp \
    ${NR_EU_OPTION} \
    newrelic/nri-statsd:test


    #Install NR agent for NR into the k3d cluster (This streams k8. metrics into NR)
    helm install --kube-context k3d-${K6_K3D_CLUSTER_NAME} newrelic-infrastructure ./newrelic-infrastructure \
    --set cluster=k3d-${K6_K3D_CLUSTER_NAME} \
    --set licenseKey=${NR_API_KEY}

    #Install KEDA
    helm repo add kedacore https://kedacore.github.io/charts
    helm repo update
    helm install keda kedacore/keda --namespace keda --create-namespace

    #Install the KEDA scaledobject CRD for a simple scaling event
    ( cat echo-server/keda.yaml | NR_ACCOUNT_ID=${NR_ACCOUNT_ID} NR_API_KEY=${NR_API_KEY} NR_REGION=${NR_REGION} envsubst) | k apply -f -

    log "INFO" "I think it is installed.  Now you can run ./run.sh to kick off a k6 test"




}


############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts "h:e:a:k:" option; do
   case $option in
      h) # display Help
         help
         exit;;
      e) #OPTIONAL: TO use the EU NR ingest endpoints
         NR_EU_OPTION="-e NR_EU_REGION=true \\"
         NR_REGION="EU";;
      a) # Set NR account number
         NR_ACCOUNT_ID=$OPTARG;;
      k) 
         NR_API_KEY=$OPTARG;;
     \?) # Invalid option
         echo "Error: Invalid option"
         exit;;    
   esac
done

############################################################
# The business                                             #
############################################################
install




