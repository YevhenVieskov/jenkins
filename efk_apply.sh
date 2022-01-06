#!/bin/bash
kubectl apply -f ./efk/efk-ns.yaml
kubectl create -f ./efk/elastic.yaml -n logging
kubectl create -f ./efk/kibana.yaml -n logging
kubectl create -f ./efk/filebeat-kubernetes.yaml -n logging

kubectl create -f ./efk/metricbeat/metricbeat-daemonset.yaml -n logging
kubectl create -f ./efk/metricbeat/metricbeat-daemonset-configmap.yaml -n logging
kubectl create -f ./efk/metricbeat/metricbeat-role.yaml  -n logging
kubectl create -f ./efk/metricbeat/metricbeat-role-binding.yaml  -n logging
kubectl create -f ./efk/metricbeat/metricbeat-service-account.yaml  -n logging
