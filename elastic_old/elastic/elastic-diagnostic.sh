#!/bin/bash
kubectl get elasticsearch
kubectl get pods --selector='elasticsearch.k8s.elastic.co/cluster-name=quickstart'
kubectl logs -f quickstart-es-default-0
kubectl get service quickstart-es-http
PASSWORD=$(kubectl get secret quickstart-es-elastic-user -o go-template='{{.data.elastic | base64decode}}')

curl -u "elastic:$PASSWORD" -k "https://quickstart-es-http:9200"
kubectl port-forward service/quickstart-es-http 9200
curl -u "elastic:$PASSWORD" -k "https://localhost:9200"








