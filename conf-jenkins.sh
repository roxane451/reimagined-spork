FROM jenkins/jenkins:lts

USER root

# Mettre à jour les paquets et installer Podman
RUN apt-get update && \
    apt-get install -y podman && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Revenir à l'utilisateur Jenkins pour la compatibilité
USER jenkins
