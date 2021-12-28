#!/bin/bash
#kubectl apply -f jenkins-ns.yaml
kubectl apply -f volumes.yaml #-n jenkins
kubectl apply -f jenkins-master-deployment.yaml #-n jenkins
kubectl apply -f jenkins-master-service.yaml #-n jenkins
kubectl apply -f jenkins-master-role.yaml #-n jenkins
kubectl apply -f jenkins-master-role-binding.yaml #-n jenkins

