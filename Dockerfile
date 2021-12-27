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

#Groovy post-init script
COPY init.groovy /usr/share/jenkins/ref/init.groovy.d/init.groovy

USER jenkins
