#!/bin/bash

# install Jenkins on Kubernetes
kubectl apply -f ./jenkins/jenkins-ns.yaml
kubectl apply -f ./jenkins/volumes.yaml -n jenkins
kubectl apply -f ./jenkins/jenkins-master-deployment.yaml -n jenkins
kubectl apply -f ./jenkins/jenkins-master-service.yaml -n jenkins
kubectl apply -f ./jenkins/jenkins-master-role.yaml -n jenkins
kubectl apply -f ./jenkins/jenkins-master-role-binding.yaml -n jenkins

# install Prometheus on Kubernetes
kubectl apply  -f ./prometheus/prometheus-ns.yaml -n monitoring
kubectl create -f ./prometheus/clusterRole.yaml -n monitoring
kubectl create -f ./prometheus/config-map.yaml -n monitoring
kubectl create -f ./prometheus/prometheus-deployment.yaml -n monitoring
kubectl create -f ./prometheus/prometheus-service.yaml -n monitoring

# install Graphana on Kubernetes
kubectl create -f ./graphana/grafana-datasource-config.yaml -n monitoring
kubectl create -f ./graphana/deployment.yaml -n monitoring
kubectl create -f ./graphana/service.yaml -n monitoring


