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

2. [Persistent Volume for Jenkins on Kubernetes] (https://stackoverflow.com/questions/61589595/persistent-volume-for-jenkins-on-kubernetes)

3. [Deploying Jenkins on Kubernetes for Scalability and Fault Tolerance] (https://faun.pub/the-ci-octopus-extremely-scalable-jenkins-master-slaves-on-kubernetes-2607704a9513)

4. [Kubernetes monitoring with prometheus]
(https://acloudguru.com/hands-on-labs/kubernetes-monitoring-with-prometheus?utm_campaign=11244863417&utm_source=google&utm_medium=cpc&utm_content=469352928666&utm_term=_&adgroupid=115625160932&gclid=EAIaIQobChMIzqGCicX39AIVZoODBx1DfwA_EAAYASAAEgKYkfD_BwE)

5. [How to Setup Prometheus Monitoring On Kubernetes Cluster]  (https://devopscube.com/setup-prometheus-monitoring-on-kubernetes/)

6. [Metrics] (https://plugins.jenkins.io/metrics/)

7. [Monitoring Jenkins] (https://www.jenkins.io/doc/book/system-administration/monitoring/)

8. [Jenkins Events, Logs, and Metrics] (https://towardsdatascience.com/jenkins-events-logs-and-metrics-7c3e8b28962b)

9. [Pipeline as code] (https://livebook.manning.com/book/pipeline-as-code/chapter-5/v-4/266)

10. [How To Gather Infrastructure Metrics with Metricbeat on Ubuntu 18.04] (https://www.stackovercloud.com/2019/03/15/how-to-gather-infrastructure-metrics-with-metricbeat-on-ubuntu-18-04/)

11. [Monitoring Jenkins with Grafana and Prometheus] (https://medium.com/@eng.mohamed.m.saeed/monitoring-jenkins-with-grafana-and-prometheus-a7e037cbb376)
