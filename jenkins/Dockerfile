FROM jenkins/jenkins:lts

USER root

# Installer Podman, curl, gnupg, helm, kubectl
RUN apt-get update && apt-get install -y \
    podman \
    curl \
    gnupg2 \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Installer kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl

# Installer helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Ajouter Jenkins au groupe Podman
RUN usermod -aG podman jenkins || true

# Copier ta configuration Jenkins dans l'image
# Assure-toi que ./jenkins_home contient ton JENKINS_HOME actuel
COPY jenkins_home /var/jenkins_home
RUN chown -R jenkins:jenkins /var/jenkins_home

USER jenkins

EXPOSE 8080
