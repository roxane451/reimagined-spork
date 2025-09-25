FROM jenkins/jenkins:lts

# Passer en root pour installations
USER root

# Installer les dépendances système
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    gnupg \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    lsb-release \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Installer kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl

# Installer Helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Installer Podman
RUN sh -c "echo 'deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/Debian_12/ /' > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list" \
    && wget -nv https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable/Debian_12/Release.key -O- | apt-key add - \
    && apt-get update \
    && apt-get install -y podman \
    && rm -rf /var/lib/apt/lists/*

# Configurer Podman pour Jenkins
RUN echo "jenkins ALL=(ALL) NOPASSWD: /usr/bin/podman" >> /etc/sudoers \
    && mkdir -p /home/jenkins/.config/containers \
    && chown -R jenkins:jenkins /home/jenkins

# Installer Kind
RUN curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64 \
    && chmod +x ./kind \
    && mv ./kind /usr/local/bin/kind

# Revenir à l'utilisateur jenkins
USER jenkins

# Copier la configuration existante if existe
COPY --chown=jenkins:jenkins jenkins_home/ /var/jenkins_home/
