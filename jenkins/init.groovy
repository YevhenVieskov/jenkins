import org.csanchez.jenkins.plugins.kubernetes.*
import jenkins.model.*

def JENKINS_MASTER_PORT_50000_TCP_ADDR = System.env.JENKINS_MASTER_PORT_50000_TCP_ADDR
def JENKINS_MASTER_POD_IP = System.env.JENKINS_MASTER_POD_IP
def JENKINS_MASTER_SERVICE_PORT_HTTP = System.env.JENKINS_MASTER_SERVICE_PORT_HTTP
def JENKINS_SLAVE_AGENT_PORT = System.env.JENKINS_SLAVE_AGENT_PORT
def j = Jenkins.getInstance()
j.setNumExecutors(0)
def k = new KubernetesCloud(‘jenkins-master’)k.setJenkinsTunnel(JENKINS_MASTER_PORT_50000_TCP_ADDR+”:”+JENKINS_SLAVE_AGENT_PORT);k.setServerUrl(“${YOUR_MINIKUBE_HOST_URL}”);

k.setJenkinsUrl(“http://”+JENKINS_MASTER_POD_IP+”:”+JENKINS_MASTER_SERVICE_PORT_HTTP);
k.setNamespace(“default”);j.clouds.replace(k);
j.save();
