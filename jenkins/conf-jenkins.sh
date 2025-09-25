#!/bin/bash

# Créer un volume persistant pour Jenkins
podman volume create jenkins-data

podman run -d \
  --name jenkins \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /usr/local/bin/minikube:/usr/local/bin/minikube:ro \
  -v /usr/local/bin/kubectl:/usr/local/bin/kubectl:ro \
  -v ~/.minikube:/var/jenkins_home/.minikube:Z \
  -v ~/.kube:/var/jenkins_home/.kube:Z \
  --privileged \
  jenkins/jenkins:lts
