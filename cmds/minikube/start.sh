#! /bin/bash

set -e
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $ROOT_DIR

source ../../config.sh

function tab() {
  osascript 2>/dev/null <<EOF
    tell application "System Events"
      tell process "Terminal" to keystroke "t" using command down
    end
    tell application "Terminal"
      activate
      do script with command "cd \"$PWD\"; $*" in window 1
    end tell
EOF
}

# start minikube (k8s)
minikube start

# mount home directory into minikube space
# https://minikube.sigs.k8s.io/docs/handbook/mount/
# This must be started before the cluster is up
if [[ $AUTO_EXTRAS == 'true' ]]; then
  echo "launching minikube $HOME mount in new tab"
  tab minikube mount $HOME:/hosthome

  echo "starting k8s dashboard process in new tab"
  tab minikube dashboard

  # ensure the casita images are built in minikube vm 
  ./build.sh
else
  echo "warning, not mounting fs, run as \"AUTO_EXTRAS=true ./cmds/minikube.sh\" to auto mount fs, bind ports and start dashboard" 
fi

# start helm
echo "starting helm deployments" 

./install-helm-repos.sh
./deploy-airflow.sh
./deploy-kafka.sh

# helm uninstall airflow --namespace=airflow

# port forward main web service
if [[ $AUTO_EXTRAS == 'true' ]]; then
  echo "starting webserver port foward process in new tab" 
  tab kubectl port-forward svc/airflow-webserver 8080:8080 --namespace airflow

  echo "opening terminal to airflow worker container"
  kubectl exec --stdin --tty airflow-worker-0 --namespace=airflow -- bash 
fi