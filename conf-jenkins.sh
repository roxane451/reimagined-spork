#!/bin/bash

# Créer un volume persistant pour Jenkins
podman volume create jenkins-data

# Lancer Jenkins avec Podman (sans socket)
podman run -d \
  --name jenkins \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins-data:/var/jenkins_home \
  --privileged \
  jenkins/jenkins:lts

# Récupérer le mot de passe initial
podman logs jenkins | grep -A 5 "Please use the following password"
