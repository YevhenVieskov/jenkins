# Jenkins in Kubernetes monitoring with Prometheus and Graphana 

## Deployment algorithm

1. Run minikube cluster.

    `minikube start`

2. Create folder for persistent volume.

    `minikube ssh`

    `sudo mkdir /data/jenkins_home`

Minikube configured for hostPath sets the permissions on /data to the root account only. Once the volume is created you will need to manually change the permissions to allow the jenkins account to write its data.

3. Change permission to `jenkins_home`.
   
   `sudo chown -R 1000:1000 /data/jenkins-volume`

4. Exit from minikube.

   `exit`



## Links

1. [Install Jenkins on kubernetes](https://www.jenkins.io/doc/book/installing/kubernetes/)
