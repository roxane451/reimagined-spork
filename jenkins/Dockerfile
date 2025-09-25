FROM jenkins/jenkins:lts

USER root

# Installer kubectl, helm et podman
RUN apt-get update && apt-get install -y \
    curl \
    git \
    sudo \
    gnupg2 \
    lsb-release \
    software-properties-common \
    iptables \
    podman \
    fuse-overlayfs \
    && apt-get clean

# Installer kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl

# Installer Helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Configurer podman pour Jenkins
RUN groupadd -g 1000 jenkins && usermod -aG podman jenkins

USER jenkins

# Créer dossier Kubernetes config
RUN mkdir -p /var/jenkins_home/.kube

# Exposer Jenkins
EXPOSE 8080
EXPOSE 50000

