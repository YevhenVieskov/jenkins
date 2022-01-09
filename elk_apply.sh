#!/bin/bash
kubectl apply -f ./elk/elk-ns.yaml
kubectl create -f ./elk/elastic.yaml -n logging
kubectl create -f ./elk/kibana.yaml -n logging
kubectl create -f ./elk/filebeat-kubernetes.yaml -n logging

kubectl create -f ./elk/metricbeat/metricbeat-daemonset.yaml -n logging
kubectl create -f ./elk/metricbeat/metricbeat-daemonset-configmap.yaml -n logging
kubectl create -f ./elk/metricbeat/metricbeat-role.yaml  -n logging
kubectl create -f ./elk/metricbeat/metricbeat-role-binding.yaml  -n logging
kubectl create -f ./elk/metricbeat/metricbeat-service-account.yaml  -n logging
