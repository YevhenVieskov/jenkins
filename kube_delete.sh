#!/bin/bash
kubectl delete -f volumes.yaml -n jenkins 
kubectl delete -f jenkins-master-service.yaml -n jenkins
kubectl delete -f jenkins-master-role.yaml -n jenkins
kubectl delete -f jenkins-master-role-binding.yaml -n jenkins
kubectl delete -f jenkins-ns.yaml

