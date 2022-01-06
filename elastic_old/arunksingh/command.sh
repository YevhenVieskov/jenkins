#/bin/bash
# Verify the cluster status-
kubectl get elastic -n elastic-system
# Verify the pvc it creates when you deploy the cluster
kubectl get pvc -n elastic-system
kubectl get pv -n elastic-system
kubectl get pods -n elastic-system
kubectl get service -n elastic-system
kubectl get secret -n elastic-system
kubectl get events -n elastic-system

# Its always good to have alias
alias 'kgp'='kubectl get pods -n elastic-system -o wide'
alias 'kgn'='kubectl get nodes -o wide'
alias 'kel'='k get elastic -n elastic-system -o wide'
