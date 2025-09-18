# reimagined-spork

# Pipeline CI/CD avec Jenkins, Podman, GitHub Container Registry et Kubernetes

## Présentation

Ce projet configure un pipeline CI/CD pour déployer une application sur un cluster Kubernetes, avec quatre environnements : **dev**, **QA**, **staging** et **prod**. L'objectif est d'optimiser le cycle de développement et de déploiement en utilisant **Podman** pour la conteneurisation, **GitHub Container Registry** pour le stockage des images, **Jenkins** pour l'automatisation et **Helm** pour gérer les déploiements Kubernetes.

Le pipeline suit les bonnes pratiques DevOps : déploiements automatisés pour les environnements non-productifs et déploiement manuel pour la production (branche `master` uniquement). Podman offre une conteneurisation sécurisée sans démon, et GitHub Container Registry simplifie la gestion des images.

---

## Objectifs

- Automatiser les étapes de build, test, construction d’images et déploiement via Jenkins.
- Utiliser Podman pour la création et la gestion des conteneurs.
- Stocker les images dans GitHub Container Registry avec versionnement.
- Déployer l’application sur Kubernetes avec des namespaces distincts.
- Gérer les déploiements avec des charts Helm.
- Assurer un déploiement manuel en production pour plus de contrôle.

---

## Prérequis

Pour démarrer, vous aurez besoin :
- D’un compte GitHub avec un dépôt et un accès à GitHub Container Registry (ghcr.io).
- **Podman** installé pour gérer les conteneurs.
- **Jenkins** configuré avec les plugins Git, Pipeline et Credentials.
- Un cluster **Kubernetes** avec les namespaces `dev`, `qa`, `staging` et `prod`.
- **Helm** pour gérer les déploiements.
- Un accès à `kubectl` configuré et un Personal Access Token (PAT) pour GitHub Container Registry.

---

## Architecture

### Composants principaux

1. **Dépôt GitHub** :
   - Stocke le code source.
   - Déclenche le pipeline via un webhook à chaque push.

2. **Jenkins** :
   - Gère un pipeline avec les étapes : build, test, construction d’images avec Podman, push vers GitHub Container Registry, et déploiement.

3. **GitHub Container Registry** :
   - Stocke les images de conteneurs de manière sécurisée et versionnée.

4. **Cluster Kubernetes** :
   - Utilise quatre namespaces : `dev`, `qa`, `staging`, `prod`.
   - Déploiements automatisés pour `dev`, `qa` et `staging`, manuel pour `prod`.

5. **Charts Helm** :
   - Gèrent les configurations et déploiements pour chaque environnement.

### Flux de déploiement

1. Push du code sur GitHub.
2. Webhook déclenche le pipeline Jenkins.
3. Jenkins compile, teste, construit l’image avec Podman et la pousse vers GitHub Container Registry.
4. Déploiement automatique via Helm dans `dev`, `qa` et `staging`.
5. Déploiement manuel en `prod` après validation, uniquement depuis la branche `master`.
