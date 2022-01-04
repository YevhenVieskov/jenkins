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

https://faun.pub/the-ci-octopus-extremely-scalable-jenkins-master-slaves-on-kubernetes-2607704a9513

Prerequisites

Let’s first install kubectlvia the Kubernetes website.

Next, let’s install minikube via the Minikube Kubernetes Page. They will ask you to install kubectl which you have already done. Horray!

As a note here again my machine is running Hyperkit as the VM for minikube and I installed minikube through curl not brew.

Let’s run a few commands… minikube start which you can confirm with minikube status. Next… eval $(minikube docker-env)will set the docker environment to minikube. This command has no output so a success is actually just the lack of an error in this case. If we didn’t run this, we would build docker containers outside the VM minikube is running in.

Setting up the Jenkins Master Repository

Let’s create some new local files that will all be part of the same repository under this cool directory ci-octopus.

init.groovy

This file is pretty important and was missing from a lot of the tutorials and sources we found. The tutorials explained how to configure the jenkins kubernetes plugin through the UI, running kubectl commands to get info for the config.

That is all fine and good, but what happens when the jenkins-master node goes down? The new pod will have a different IP and the kubernetes plugin will require different config and manual attention (not very kubernetes-style). That is where this script comes in. It is the “post-init” hook that Jenkins will fire when the instance first starts up… So let’s paste the following code into it.

import org.csanchez.jenkins.plugins.kubernetes.*
import jenkins.model.*def JENKINS_MASTER_PORT_50000_TCP_ADDR = System.env.JENKINS_MASTER_PORT_50000_TCP_ADDR
def JENKINS_MASTER_POD_IP = System.env.JENKINS_MASTER_POD_IP
def JENKINS_MASTER_SERVICE_PORT_HTTP = System.env.JENKINS_MASTER_SERVICE_PORT_HTTP
def JENKINS_SLAVE_AGENT_PORT = System.env.JENKINS_SLAVE_AGENT_PORT
def j = Jenkins.getInstance()
j.setNumExecutors(0)
def k = new KubernetesCloud(‘jenkins-master’)k.setJenkinsTunnel(JENKINS_MASTER_PORT_50000_TCP_ADDR+”:”+JENKINS_SLAVE_AGENT_PORT);k.setServerUrl(“${YOUR_MINIKUBE_HOST_URL}”);
k.setJenkinsUrl(“http://”+JENKINS_MASTER_POD_IP+”:”+JENKINS_MASTER_SERVICE_PORT_HTTP);
k.setNamespace(“default”);j.clouds.replace(k);
j.save();

What this script is doing is grabbing a number of environment variables that are available on the container, instantiating a new KubernetesCloud, formatting the variables, and assigning them to the correct properties for the kubernetes config.

The only value that you will have to add to this script is on the setServerURL call. This value YOUR_MINIKUBE_HOST_URL will be the output of the following command kubectl cluster-info | grep -Eom1 "https://(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?:[0-9]{1,3})"  In other cloud environments this URL will be static (not changing) and can be hard-coded or injected as a secret during the deployment.

cd ci-octopus && vi init.groovy and update the setServerUrl with the your value.

As a side note here as much as possible, wherever possible, it is best to follow the infrastructure as code paradigm… Forcing yourself to operate outside a UI will pay dividends in the future when things go down or a new developer is attempting to grok your cloud infrastructure!
Dockerfile

Now we can build our jenkins-master container.

vi Dockerfile

Paste the following code into the Dockerfile and read through the comments to get an understanding of what we are installing on to the image. The most important plugins are the ssh-slaves, kubernetes, and workflow-aggregator plugins.

FROM jenkins/jenkins:lts# Distributed Builds plugins (managing slaves)
RUN /usr/local/bin/install-plugins.sh ssh-slaves# install Notifications and Publishing plugins (unused at the moment)
RUN /usr/local/bin/install-plugins.sh slack# UI 
RUN /usr/local/bin/install-plugins.sh greenballs# Scaling (main plugin)
RUN /usr/local/bin/install-plugins.sh kubernetes#GitHub Integration (not used but important)
RUN /usr/local/bin/install-plugins.sh github#Pipeline for creating pipeline jobs
RUN /usr/local/bin/install-plugins.sh workflow-aggregator#Groovy post-init script
COPY init.groovy /usr/share/jenkins/ref/init.groovy.d/init.groovyUSER jenkins

If you like you can collapse all the plugin installs into a single command a la..

RUN /usr/local/bin/install-plugins.sh ssh-slaves slack greenballs kubernetes github workflow-aggregator

Before finishing the docker stuff let’s run one more command to build our image with our desired tag.

docker build -t jenkins-master:1.0 .

Kubernetes Pod Deployment

Lets run this command, vi jenkins-master-deployment.yaml and paste the following code into it…

apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins-master
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jenkins-master
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: jenkins-master
    spec:
      serviceAccountName: default
      containers:
        - name: jenkins
          image: jenkins-master:1.0
          imagePullPolicy: Never
          env:
            - name: JAVA_OPTS
              value: -Djenkins.install.runSetupWizard=false
            - name: JENKINS_MASTER_POD_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
          ports:
            - name: http-port
              containerPort: 8080
            - name: jnlp-port
              containerPort: 50000
          volumeMounts:
            - name: jenkins-home
              mountPath: /var/jenkins_home
      volumes:
        - name: jenkins-home
          emptyDir: {}

Most of the code above the spec object is standard. We are going to name the pod jenkins-master with a Recreate deployment strategy. Once we get into the spec object there are a couple important things going on. The serviceAccountName is the account we will give permissions to be able to interact with the kubernetes API. The image property will be the name of the container that we built in the previous docker-build step as the -t argument jenkins-master.

We add in two environment variables, one that disables the Jenkins setup wizard and will auto-setup Jenkins on container spin-up, the second is the ip of the pod once it has spun up injected as status.podIP. We expose two ports 8080 for external traffic to Jenkins and 50000 because is the default port for the jnlp-slaves communication.
Kubernetes Service

Now that we have the deployment lets create the kubernetes service with a vi jenkins-master-service.yaml pasting the following code into it...

apiVersion: v1
kind: Service
metadata:
  name: jenkins-master
spec:
  type: NodePort
  ports:
    - port: 8080
      name: "http"
      nodePort: 30000
      targetPort: 8080
    - port: 50000
      name: "slave"
      nodePort: 30010
      targetPort: 50000
  selector:
    app: jenkins-master

This will tell kubernetes to how to access the pod defined in our deployment. nodePort is what the service takes in traffic on and targetPort is the port exposed on the container. We open up port 8080 for incoming traffic and 50000 for communication with the jenkins-slaves instances. When we go to hit the Jenkins URL within minikube, we will use port 30000. Incoming traffic on the node flows from port 30000 to 8080 on the jenkins-master container.
Kubernetes ClusterRole

Last, but certainly not least we have to give some permissions to the default serviceAccount we added to our deployment. Let’s run the following command vi jenkins-master-role.yaml and paste the following…

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  namespace: default
  name: service-reader
rules:
  - apiGroups: [""]
    resources: ["services"]
    verbs: ["get", "watch", "list"]
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]
  - apiGroups: [""]
    resources: ["pods/exec"]
    verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]
  - apiGroups: [""]
    resources: ["pods/log"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get"]

This role will allow our jenkins-master to provision slaves via the Kubernetes API. The apiGroups: [""] refers to the core API group. Next, vi jenkins-master-role-binding.yaml and paste in the following…

kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: service-reader-pod
subjects:
  - kind: ServiceAccount
    name: default
    namespace: default
roleRef:
  kind: ClusterRole
  name: service-reader
  apiGroup: rbac.authorization.k8s.io

This will bind our new ClusterRole service-reader to the default service account listed in our jenkins-master-deployment.yaml.
Deploy and Test

Theres no more to do! Time to deploy to the K8s baby!

kubectl apply -f .

You should see the following output to confirm the success.

deployment.apps/jenkins-master created
clusterrolebinding.rbac.authorization.k8s.io/service-reader-pod created
clusterrole.rbac.authorization.k8s.io/service-reader created
service/jenkins-master created

If so, mega congrats! We are almost there.

Go ahead and visit the url generated from the following command.

echo “http://$(minikube ip):30000”

This should get you to the Jenkins UI. From here we will click on “create new job”, type in a name, “Test Job 1”, choose type “pipeline”, and click “OK”.

On the left hand side click on configure and scroll down to the pipeline groovy editor and paste the following snippet.

def POD_LABEL = "testpod"
podTemplate(label:POD_LABEL, cloud: "jenkins-master", containers: [
    containerTemplate(name: 'build', image: 'node:12.13.1', ttyEnabled: true, command: 'cat')
  ]) {
    node(POD_LABEL) {
        stage('Run Shell') {
            container('build') {
                sh "sleep 30"
            }
        }
    }
}

Save and click “Build Now”, then navigate “Back to Dashboard”

https://devopscube.com/setup-prometheus-monitoring-on-kubernetes/

How to Setup Prometheus Monitoring On Kubernetes Cluster

Let’s get started with the setup.
Create a Namespace & ClusterRole

First, we will create a Kubernetes namespace for all our monitoring components. If you don’t create a dedicated namespace, all the Prometheus kubernetes deployment objects get deployed on the default namespace.

Execute the following command to create a new namespace named monitoring.

kubectl create namespace monitoring

Prometheus uses Kubernetes APIs to read all the available metrics from Nodes, Pods, Deployments, etc. For this reason, we need to create an RBAC policy with read access to required API groups and bind the policy to the monitoring namespace.

Step 1: Create a file named clusterRole.yaml and copy the following RBAC role.

    In the role, given below, you can see that we have added get, list, and watch permissions to nodes, services endpoints, pods, and ingresses. The role binding is bound to the monitoring namespace. If you have any use case to retrieve metrics from any other object, you need to add that in this cluster role.

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources:
  - nodes
  - nodes/proxy
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
- apiGroups:
  - extensions
  resources:
  - ingresses
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: default
  namespace: monitoring

Step 2: Create the role using the following command.

kubectl create -f clusterRole.yaml

Create a Config Map To Externalize Prometheus Configurations

All configurations for Prometheus are part of prometheus.yaml file and all the alert rules for Alertmanager are configured in prometheus.rules.

    prometheus.yaml: This is the main Prometheus configuration which holds all the scrape configs, service discovery details, storage locations, data retention configs, etc)
    prometheus.rules: This file contains all the Prometheus alerting rules

By externalizing Prometheus configs to a Kubernetes config map, you don’t have to build the Prometheus image whenever you need to add or remove a configuration. You need to update the config map and restart the Prometheus pods to apply the new configuration.

The config map with all the Prometheus scrape config and alerting rules gets mounted to the Prometheus container in /etc/prometheus location as prometheus.yaml and prometheus.rules files.

Step 1: Create a file called config-map.yaml and copy the file contents from this link –> Prometheus Config File.

Step 2: Execute the following command to create the config map in Kubernetes.

kubectl create -f config-map.yaml

It creates two files inside the container.

    Note: In Prometheus terms, the config for collecting metrics from a collection of endpoints is called a job. 

The prometheus.yaml contains all the configurations to discover pods and services running in the Kubernetes cluster dynamically. We have the following scrape jobs in our Prometheus scrape configuration.

    kubernetes-apiservers: It gets all the metrics from the API servers.
    kubernetes-nodes: It collects all the kubernetes node metrics.
    kubernetes-pods: All the pod metrics get discovered if the pod metadata is annotated with prometheus.io/scrape and prometheus.io/port annotations.
    kubernetes-cadvisor: Collects all cAdvisor metrics.
    kubernetes-service-endpoints: All the Service endpoints are scrapped if the service metadata is annotated with prometheus.io/scrape and prometheus.io/port annotations. It can be used for black-box monitoring.

prometheus.rules contains all the alert rules for sending alerts to the Alertmanager.
Create a Prometheus Deployment

Step 1: Create a file named prometheus-deployment.yaml and copy the following contents onto the file. In this configuration, we are mounting the Prometheus config map as a file inside /etc/prometheus as explained in the previous section.

    Note: This deployment uses the latest official Prometheus image from the docker hub. Also, we are not using any persistent storage volumes for Prometheus storage as it is a basic setup. When setting up Prometheus for production uses cases, make sure you add persistent storage to the deployment.

apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus-deployment
  namespace: monitoring
  labels:
    app: prometheus-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus-server
  template:
    metadata:
      labels:
        app: prometheus-server
    spec:
      containers:
        - name: prometheus
          image: prom/prometheus
          args:
            - "--storage.tsdb.retention.time=12h"
            - "--config.file=/etc/prometheus/prometheus.yml"
            - "--storage.tsdb.path=/prometheus/"
          ports:
            - containerPort: 9090
          resources:
            requests:
              cpu: 500m
              memory: 500M
            limits:
              cpu: 1
              memory: 1Gi
          volumeMounts:
            - name: prometheus-config-volume
              mountPath: /etc/prometheus/
            - name: prometheus-storage-volume
              mountPath: /prometheus/
      volumes:
        - name: prometheus-config-volume
          configMap:
            defaultMode: 420
            name: prometheus-server-conf
  
        - name: prometheus-storage-volume
          emptyDir: {}

    You Might Like: Kubernetes Deployment Tutorial For Beginners

Step 2: Create a deployment on monitoring namespace using the above file.

kubectl create  -f prometheus-deployment.yaml 

Step 3: You can check the created deployment using the following command.

kubectl get deployments --namespace=monitoring

You can also get details from the kubernetes dashboard like shown below.
prometheus on kubernetes
Setting Up Kube State Metrics

Kube state metrics service will provide many metrics which is not available by default. Please make sure you deploy Kube state metrics to monitor all your kubernetes API objects like deployments, pods, jobs, cronjobs etc..

Please follow this article to setup Kube state metrics on kubernetes ==> How To Setup Kube State Metrics on Kubernetes
Connecting To Prometheus Dashboard

You can view the deployed Prometheus dashboard in three different ways.

    Using Kubectl port forwarding
    Exposing the Prometheus deployment as a service with NodePort or a Load Balancer.
    Adding an Ingress object if you have an Ingress controller deployed.

Let’s have a look at all three options.
Using Kubectl port forwarding

Using kubectl port forwarding, you can access a pod from your local workstation using a selected port on your localhost. This method is primarily used for debugging purposes.

Step 1: First, get the Prometheus pod name.

kubectl get pods --namespace=monitoring

The output will look like the following.

➜  kubectl get pods --namespace=monitoring
NAME                                     READY     STATUS    RESTARTS   AGE
prometheus-monitoring-3331088907-hm5n1   1/1       Running   0          5m

Step 2: Execute the following command with your pod name to access Prometheus from localhost port 8080.

    Note: Replace prometheus-monitoring-3331088907-hm5n1 with your pod name.

kubectl port-forward prometheus-monitoring-3331088907-hm5n1 8080:9090 -n monitoring

Step 3: Now, if you access http://localhost:8080 on your browser, you will get the Prometheus home page.
Exposing Prometheus as a Service [NodePort & LoadBalancer]

To access the Prometheus dashboard over a IP or a DNS name, you need to expose it as Kubernetes service.

Step 1: Create a file named prometheus-service.yaml and copy the following contents. We will expose Prometheus on all kubernetes node IP’s on port 30000.

    Note: If you are on AWS, Azure, or Google Cloud, You can use Loadbalancer type, which will create a load balancer and automatically points it to the Kubernetes service endpoint.

apiVersion: v1
kind: Service
metadata:
  name: prometheus-service
  namespace: monitoring
  annotations:
      prometheus.io/scrape: 'true'
      prometheus.io/port:   '9090'
spec:
  selector: 
    app: prometheus-server
  type: NodePort  
  ports:
    - port: 8080
      targetPort: 9090 
      nodePort: 30000

The annotations in the above service YAML makes sure that the service endpoint is scrapped by Prometheus. The prometheus.io/port should always be the target port mentioned in service YAML

Step 2: Create the service using the following command.

kubectl create -f prometheus-service.yaml --namespace=monitoring

Step 3: Once created, you can access the Prometheus dashboard using any of the Kubernetes nodes IP on port 30000. If you are on the cloud, make sure you have the right firewall rules to access port 30000 from your workstation.

How To Setup Grafana On Kubernetes

Let’s look at the Grafana setup in detail.

Step 1: Create file named grafana-datasource-config.yaml

vi grafana-datasource-config.yaml

Copy the following contents.

    Note: The following data source configuration is for Prometheus. If you have more data sources, you can add more data sources with different YAMLs under the data section.

apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: monitoring
data:
  prometheus.yaml: |-
    {
        "apiVersion": 1,
        "datasources": [
            {
               "access":"proxy",
                "editable": true,
                "name": "prometheus",
                "orgId": 1,
                "type": "prometheus",
                "url": "http://prometheus-service.monitoring.svc:8080",
                "version": 1
            }
        ]
    }

Step 2: Create the configmap using the following command.

kubectl create -f grafana-datasource-config.yaml

Step 3: Create a file named deployment.yaml

vi deployment.yaml

Copy the following contents on the file.

apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      name: grafana
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:latest
        ports:
        - name: grafana
          containerPort: 3000
        resources:
          limits:
            memory: "1Gi"
            cpu: "1000m"
          requests: 
            memory: 500M
            cpu: "500m"
        volumeMounts:
          - mountPath: /var/lib/grafana
            name: grafana-storage
          - mountPath: /etc/grafana/provisioning/datasources
            name: grafana-datasources
            readOnly: false
      volumes:
        - name: grafana-storage
          emptyDir: {}
        - name: grafana-datasources
          configMap:
              defaultMode: 420
              name: grafana-datasources

    Note: This Grafana deployment does not use a persistent volume. If you restart the pod all changes will be gone. Use a persistent volume if you are deploying Grafana for your project requirements. It will persist all the configs and data that Grafana uses.

Step 4: Create the deployment

kubectl create -f deployment.yaml

Step 5: Create a service file named service.yaml

vi service.yaml

Copy the following contents. This will expose Grafana on NodePort 32000. You can also expose it using ingress or a Loadbalancer based on your requirement.

apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: monitoring
  annotations:
      prometheus.io/scrape: 'true'
      prometheus.io/port:   '3000'
spec:
  selector: 
    app: grafana
  type: NodePort  
  ports:
    - port: 3000
      targetPort: 3000
      nodePort: 32000

Step 6: Create the service.

kubectl create -f service.yaml

Now you should be able to access the Grafana dashboard using any node IP on port 32000. Make sure the port is allowed in the firewall to be accessed from your workstation.

http://<your-node-ip>:32000

You can also use port forwarding using the following command.

kubectl port-forward -n monitoring <grafana-pod-name> 3000 &

For example,

vagrant@dcubelab:~$ kubectl get po -n monitoring
NAME                       READY   STATUS    RESTARTS   AGE
grafana-64c89f57f7-kjqrb   1/1     Running   0          10m
vagrant@dcubelab:~$ kubectl port-forward -n monitoring grafana-64c89f57f7-kjqrb 3000 &

You will be able to access Grafana a from http://localhost:3000

Use the following default username and password to log in. Once you log in with default credentials, it will prompt you to change the default password.

User: admin
Pass: admin

Grafana dashboard on Kubernetes
Setup Kubernetes Dashboards on Grafana

There are many prebuilt Grafana templates available for Kubernetes. To know more, see Grafana Kubernetes Dashboard templates

Setting up a dashboard from a template is pretty easy. Follow the steps given below to set up a Grafana dashboard to monitor kubernetes deployments.

Step 1: Get the template ID from grafana public template. as shown below.
image

Step 2: Head over to grafana and select the import option.
image 1

Step 3: Enter the dashboard ID you got it step 1
image 2

Step 4: Grafana will automatically fetch the template from Grafana website. You can change the values as shown in the image below and click import.
image 3

You should see the dashboard immediately.


## Deploy ECK in your Kubernetes cluster



    Install custom resource definitions and the operator with its RBAC rules:

    kubectl create -f https://download.elastic.co/downloads/eck/1.9.1/crds.yaml
    kubectl apply -f https://download.elastic.co/downloads/eck/1.9.1/operator.yaml

    If you are running a version of Kubernetes before 1.16 you have to use the legacy version of the manifests:

    kubectl create -f https://download.elastic.co/downloads/eck/1.9.1/crds-legacy.yaml
    kubectl apply -f https://download.elastic.co/downloads/eck/1.9.1/operator-legacy.yaml

    Monitor the operator logs:

    kubectl -n elastic-system logs -f statefulset.apps/elastic-operator

## Deploy an Elasticsearch cluster

Apply a simple Elasticsearch cluster specification, with one Elasticsearch node:

If your Kubernetes cluster does not have any Kubernetes nodes with at least 2GiB of free memory, the pod will be stuck in Pending state. See Manage compute resources for more information about resource requirements and how to configure them.

cat <<EOF | kubectl apply -f -
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: quickstart
spec:
  version: 7.16.2
  nodeSets:
  - name: default
    count: 1
    config:
      node.store.allow_mmap: false
EOF

The operator automatically creates and manages Kubernetes resources to achieve the desired state of the Elasticsearch cluster. It may take up to a few minutes until all the resources are created and the cluster is ready for use.

Setting node.store.allow_mmap: false has performance implications and should be tuned for production workloads as described in the Virtual memory section.
Monitor cluster health and creation progress
edit

Get an overview of the current Elasticsearch clusters in the Kubernetes cluster, including health, version and number of nodes:

kubectl get elasticsearch

NAME          HEALTH    NODES     VERSION   PHASE         AGE
quickstart    green     1         7.16.2     Ready         1m

When you create the cluster, there is no HEALTH status and the PHASE is empty. After a while, the PHASE turns into Ready, and HEALTH becomes green. The HEALTH status comes from Elasticsearch’s cluster health API.

You can see that one Pod is in the process of being started:

kubectl get pods --selector='elasticsearch.k8s.elastic.co/cluster-name=quickstart'

NAME                      READY   STATUS    RESTARTS   AGE
quickstart-es-default-0   1/1     Running   0          79s

Access the logs for that Pod:

kubectl logs -f quickstart-es-default-0

Request Elasticsearch access
edit

A ClusterIP Service is automatically created for your cluster:

kubectl get service quickstart-es-http

NAME                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
quickstart-es-http   ClusterIP   10.15.251.145   <none>        9200/TCP   34m

    Get the credentials.

    A default user named elastic is automatically created with the password stored in a Kubernetes secret:

    PASSWORD=$(kubectl get secret quickstart-es-elastic-user -o go-template='{{.data.elastic | base64decode}}')

    Request the Elasticsearch endpoint.

    From inside the Kubernetes cluster:

    curl -u "elastic:$PASSWORD" -k "https://quickstart-es-http:9200"

    From your local workstation, use the following command in a separate terminal:

    kubectl port-forward service/quickstart-es-http 9200

    Then request localhost:

    curl -u "elastic:$PASSWORD" -k "https://localhost:9200"

Disabling certificate verification using the -k flag is not recommended and should be used for testing purposes only. See: Setup your own certificate

{
  "name" : "quickstart-es-default-0",
  "cluster_name" : "quickstart",
  "cluster_uuid" : "XqWg0xIiRmmEBg4NMhnYPg",
  "version" : {...},
  "tagline" : "You Know, for Search"
}


## Deploy a Kibana Instance

To deploy your Kibana instance go through the following steps.

    Specify a Kibana instance and associate it with your Elasticsearch cluster:

    cat <<EOF | kubectl apply -f -
    apiVersion: kibana.k8s.elastic.co/v1
    kind: Kibana
    metadata:
      name: quickstart
    spec:
      version: 7.16.2
      count: 1
      elasticsearchRef:
        name: quickstart
    EOF

    Monitor Kibana health and creation progress.

    Similar to Elasticsearch, you can retrieve details about Kibana instances:

    kubectl get kibana

    And the associated Pods:

    kubectl get pod --selector='kibana.k8s.elastic.co/name=quickstart'

    Access Kibana.

    A ClusterIP Service is automatically created for Kibana:

    kubectl get service quickstart-kb-http

    Use kubectl port-forward to access Kibana from your local workstation:

    kubectl port-forward service/quickstart-kb-http 5601

    Open https://localhost:5601 in your browser. Your browser will show a warning because the self-signed certificate configured by default is not verified by a known certificate authority and not trusted by your browser. You can temporarily acknowledge the warning for the purposes of this quick start but it is highly recommended that you configure valid certificates for any production deployments.

    Login as the elastic user. The password can be obtained with the following command:

    kubectl get secret quickstart-es-elastic-user -o=jsonpath='{.data.elastic}' | base64 --decode; echo

## Run Metricbeat on Kubernetes

Kubernetes deploy manifests
edit

You deploy Metricbeat as a DaemonSet to ensure that there’s a running instance on each node of the cluster. These instances are used to retrieve most metrics from the host, such as system metrics, Docker stats, and metrics from all the services running on top of Kubernetes.

In addition, one of the Pods in the DaemonSet will constantly hold a leader lock which makes it responsible for handling cluster-wide monitoring. This instance is used to retrieve metrics that are unique for the whole cluster, such as Kubernetes events or kube-state-metrics. You can find more information about leader election configuration options at Autodiscover.

Note: If you are upgrading from older versions, please make sure there are no redundant parts as left-overs from the old manifests. Deployment specification and its ConfigMaps might be the case.

Everything is deployed under the kube-system namespace by default. To change the namespace, modify the manifest file.

To download the manifest file, run:

curl -L -O https://raw.githubusercontent.com/elastic/beats/7.16/deploy/kubernetes/metricbeat-kubernetes.yaml

If you are using Kubernetes 1.7 or earlier: Metricbeat uses a hostPath volume to persist internal data. It’s located under /var/lib/metricbeat-data. The manifest uses folder autocreation (DirectoryOrCreate), which was introduced in Kubernetes 1.8. You need to remove type: DirectoryOrCreate from the manifest and create the host folder yourself.
Settings
edit

By default, Metricbeat sends events to an existing Elasticsearch deployment, if present. To specify a different destination, change the following parameters in the manifest file:

- name: ELASTICSEARCH_HOST
  value: elasticsearch
- name: ELASTICSEARCH_PORT
  value: "9200"
- name: ELASTICSEARCH_USERNAME
  value: elastic
- name: ELASTICSEARCH_PASSWORD
  value: changeme

Red Hat OpenShift configuration
edit

If you are using Red Hat OpenShift, you need to specify additional settings in the manifest file and enable the container to run as privileged.

    Modify the DaemonSet container spec in the manifest file:

      securityContext:
        runAsUser: 0
        privileged: true

    In the manifest file, edit the metricbeat-daemonset-modules ConfigMap, and specify the following settings under kubernetes.yml in the data section:

      kubernetes.yml: |-
        - module: kubernetes
          metricsets:
            - node
            - system
            - pod
            - container
            - volume
          period: 10s
          host: ${NODE_NAME}
          hosts: ["https://${NODE_NAME}:10250"]
          bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
          ssl.certificate_authorities:
            - /path/to/kubelet-service-ca.crt

    kubelet-service-ca.crt can be any CA bundle that contains the issuer of the certificate used in the Kubelet API. According to each specific installation of Openshift this can be found either in secrets or in configmaps. In some installations it can be available as part of the service account secret, in /var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt. In case of using Openshift installer for GCP then the following configmap can be mounted in Metricbeat Pod and use ca-bundle.crt in ssl.certificate_authorities:

    Name:         kubelet-serving-ca
    Namespace:    openshift-kube-apiserver
    Labels:       <none>
    Annotations:  <none>

    Data
    ====
    ca-bundle.crt:

    Under the metricbeat ClusterRole, add the following resources:

      - nodes/metrics
      - nodes/stats

    Grant the metricbeat service account access to the privileged SCC:

    oc adm policy add-scc-to-user privileged system:serviceaccount:kube-system:metricbeat

    This command enables the container to be privileged as an administrator for OpenShift.

    Override the default node selector for the kube-system namespace (or your custom namespace) to allow for scheduling on any node:

    oc patch namespace kube-system -p \
    '{"metadata": {"annotations": {"openshift.io/node-selector": ""}}}'

    This command sets the node selector for the project to an empty string. If you don’t run this command, the default node selector will skip master nodes.

Load Kibana dashboards
edit

Metricbeat comes packaged with various pre-built Kibana dashboards that you can use to visualize metrics about your Kubernetes environment.

If these dashboards are not already loaded into Kibana, you must install Metricbeat on any system that can connect to the Elastic Stack, and then run the setup command to load the dashboards. To learn how, see Load Kibana dashboards.

If you are using a different output other than Elasticsearch, such as Logstash, you need to Load the index template manually and Load Kibana dashboards.
Deploy
edit

Metricbeat gets some metrics from kube-state-metrics. If kube-state-metrics is not already running, deploy it now (see the Kubernetes deployment docs).

To deploy Metricbeat to Kubernetes, run:

kubectl create -f metricbeat-kubernetes.yaml

To check the status, run:

$ kubectl --namespace=kube-system  get ds/metricbeat

NAME       DESIRED   CURRENT   READY     UP-TO-DATE   AVAILABLE   NODE-SELECTOR   AGE
metricbeat   32        32        0         32           0           <none>          1m

Metrics should start flowing to Elasticsearch.
Deploying Metricbeat to collect cluster-level metrics in large clusters
edit

The size and the number of nodes in a Kubernetes cluster can be fairly large at times, and in such cases the Pod that will be collecting cluster level metrics might face performance issues due to resources limitations. In this case users might consider to avoid using the leader election strategy and instead run a dedicated, standalone Metricbeat instance using a Deployment in addition to the DaemonSet.


 
## Configure Kibana Dashboard Loading


Metricbeat comes packaged with example Kibana dashboards, visualizations, and searches for visualizing Metricbeat data in Kibana.

To load the dashboards, you can either enable dashboard loading in the setup.dashboards section of the metricbeat.yml config file, or you can run the setup command. Dashboard loading is disabled by default.

When dashboard loading is enabled, Metricbeat uses the Kibana API to load the sample dashboards. Dashboard loading is only attempted when Metricbeat starts up. If Kibana is not available at startup, Metricbeat will stop with an error.

To enable dashboard loading, add the following setting to the config file:

setup.dashboards.enabled: true

Configuration options
edit

You can specify the following options in the setup.dashboards section of the metricbeat.yml config file:
setup.dashboards.enabled
edit

If this option is set to true, Metricbeat loads the sample Kibana dashboards from the local kibana directory in the home path of the Metricbeat installation.

When dashboard loading is enabled, Metricbeat overwrites any existing dashboards that match the names of the dashboards you are loading. This happens every time Metricbeat starts.

If no other options are set, the dashboard are loaded from the local kibana directory in the home path of the Metricbeat installation. To load dashboards from a different location, you can configure one of the following options: setup.dashboards.directory, setup.dashboards.url, or setup.dashboards.file.

## Configure Kibana Endpoint
Kibana dashboards are loaded into Kibana via the Kibana API. This requires a Kibana endpoint configuration. For details on authenticating to the Kibana API, see Authentication.

You configure the endpoint in the setup.kibana section of the metricbeat.yml config file.

Here is an example configuration:

setup.kibana.host: "https://localhost:5601"


## Jenkins and K6 Integration

We started using K6 so that we could confidently automate the API integration testing scripts and also perform load test. 

K6 does not output results in the JUnit XML required by Jenkins does to run tests and display them according to Jenkins metrics for continuous deployment. Hence, a groovy script is required to accept JSON results from K6 Tests, convert them into Jenkins understandable format (JUnit XML) and show metrics depending on the type of test and requirements.





######################################
kubectl exec --stdin --tty prometheus-deployment-599bbd9457-ngw8d -n monitoring  -- /bin/sh

Login to Grafana, and add Dashboard with ID: 9964

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

12. Deploy ECK in your Kubernetes cluster https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-deploy-eck.html


13. Deploy an Elasticsearch cluster https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-deploy-elasticsearch.html

14. Deploy a Kibana instance https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-deploy-kibana.html

15. Run Metricbeat on Kubernetes https://www.elastic.co/guide/en/beats/metricbeat/current/running-on-kubernetes.html#running-on-kubernetes

16. Configure Kibana dasboard loading https://www.elastic.co/guide/en/beats/metricbeat/current/configuration-dashboards.html
17.  Configure Kibana Endpoint https://www.elastic.co/guide/en/beats/metricbeat/current/setup-kibana-endpoint.html

17. Load testing with Jenkins. https://k6.io/blog/integrating-load-testing-with-jenkins/

18. Jenkins and K6 don’t go together, until now. https://medium.com/@devanshuagrawal/jenkins-and-k6-dont-go-together-until-now-d9c89227ae03

19. K6-to-Junit-XML-Jenkins. https://github.com/devns98/K6-to-JUnit-XML-Jenkins

