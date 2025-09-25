# DevOps - Pipeline CI/CD avec Podman, Kind et Jenkins

## 🎯 Contexte et Objectifs
En tant qu’ingénieur **DevOps junior**, l’objectif est de mettre en place un **pipeline CI/CD complet** pour une application microservices.  
La solution doit être **compatible avec macOS** et tirer parti de **Podman** pour la conteneurisation.

Le pipeline devra permettre :
- La **construction** et le **push** des images vers une registry distante.  
- Le **déploiement automatisé** sur différents environnements Kubernetes via **Kind**.  
- L’**orchestration CI/CD** à l’aide de **Jenkins**.  
- Le **packaging et déploiement** avec **Helm Charts**.  

---

## 🛠️ Architecture Technique

### ⚙️ Technologies utilisées
- **Conteneurisation** : [Podman](https://podman.io/) (compatible macOS)  
- **Orchestration Kubernetes** : [Kind](https://kind.sigs.k8s.io/) (Kubernetes in Docker, compatible Podman)  
- **Registry d’images** : [c8n.io](https://c8n.io/)  
- **CI/CD** : [Jenkins](https://www.jenkins.io/)  
- **SCM** : [GitHub](https://github.com/)  
- **Packaging & déploiement** : [Helm](https://helm.sh/)  

### 🌍 Environnements cibles
- **dev** 
- **qa** 
- **staging**
- **prod**

---

## 📦 Flux du Pipeline CI/CD

1. **Commit & Push GitHub**  
   → Déclenchement automatique du pipeline Jenkins.  

2. **Build & Push d’images**  
   - Construction des images avec **Podman**.  
   - Publication vers la registry **c8n.io**.  

3. **Déploiement sur Kind**  
   - Déploiement de l’application dans l’environnement cible.  
   - Utilisation de **Helm Charts** pour gérer les releases.  

4. **Validation et Promotion**  
   - Tests automatisés sur **dev**.  
   - Promotion progressive vers **qa**, **staging**, puis **prod**.  

---

## 📂 Organisation du projet

```bash
.
├── charts/            # Helm Charts pour le déploiement
├── jenkins/           # Pipelines Jenkinsfile & jobs
├── k8s/               # Manifests Kubernetes
├── src/               # Code source microservices
└── README.md          # Documentation
