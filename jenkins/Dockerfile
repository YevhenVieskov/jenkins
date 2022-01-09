FROM jenkins/jenkins:lts

# Distributed Builds plugins (managing slaves)
RUN /usr/local/bin/install-plugins.sh ssh-slaves

# install Notifications and Publishing plugins (unused at the moment)
RUN /usr/local/bin/install-plugins.sh slack

# UI 
RUN /usr/local/bin/install-plugins.sh greenballs

# Scaling (main plugin)
RUN /usr/local/bin/install-plugins.sh kubernetes

#GitHub Integration (not used but important)
RUN /usr/local/bin/install-plugins.sh github

#Pipeline for creating pipeline jobs
RUN /usr/local/bin/install-plugins.sh workflow-aggregator

#Metrics plugin for Jenkins
RUN /usr/local/bin/install-plugins.sh metrics

#Jenkins Prometheus Plugin expose an endpoint (default /prometheus) with metrics where a Prometheus Server can scrape.
RUN /usr/local/bin/install-plugins.sh prometheus:2.0.10

#Jenkins test result aggregator https://github.com/jenkinsci/test-results-aggregator-plugin
RUN /usr/local/bin/install-plugins.sh test-results-aggregator

#Jenkins test result analizer https://github.com/jenkinsci/test-results-analizer
RUN /usr/local/bin/install-plugins.sh test-results-analyzer:0.3.5

#Jenkins logstash plugin https://github.com/jenkinsci/logstash-plugin
RUN /usr/local/bin/install-plugins.sh logstash

#Groovy post-init script
COPY init.groovy /usr/share/jenkins/ref/init.groovy.d/init.groovy

USER jenkins
