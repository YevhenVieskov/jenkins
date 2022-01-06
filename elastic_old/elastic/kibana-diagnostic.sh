kubectl get kibana


kubectl get pod --selector='kibana.k8s.elastic.co/name=quickstart'



kubectl get service quickstart-kb-http



kubectl port-forward service/quickstart-kb-http 5601



kubectl get secret quickstart-es-elastic-user -o=jsonpath='{.data.elastic}' | base64 --decode; echo


