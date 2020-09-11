#!/bin/bash

if [[ -z $HELM_BINARY_PATH ]]; then
  HELM_BINARY_PATH="$(which helm)"
  if [[ -z $HELM_BINARY_PATH ]]; then
    echo "helm not found. Download it from https://github.com/helm/helm/releases"
    exit 1;
  fi
elif [[ ! -x $HELM_BINARY_PATH ]]; then
  echo "'\$HELM_BINARY_PATH=$HELM_BINARY_PATH' does not point to an executable."
  exit 1;
fi


echo "-- Adding 'kiwigrid' repo"
$HELM_BINARY_PATH repo add kiwigrid https://kiwigrid.github.io || exit 1

SERVICE_NAME="graphite"
HELM_CHART_NAME="kiwigrid/graphite"
echo "-- Installing 'HELM_CHART_NAME' helm chart. Service name: '$SERVICE_NAME'"
$HELM_BINARY_PATH install $SERVICE_NAME $HELM_CHART_NAME --version 0.7.0 \
  --set service.type="NodePort" || exit 1


echo "-- Successfully installed helm chart for '$SERVICE_NAME'"
echo "-- To uninstall, run: $HELM_BINARY_PATH uninstall $SERVICE_NAME"
