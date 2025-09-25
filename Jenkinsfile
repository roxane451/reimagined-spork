pipeline {
    agent any
    
    environment {
        REGISTRY = 'c8n.io'
        USERNAME = 'roxane451'
        REPO_NAME = 'reimagined-spork'
        BUILD_TAG = "${BUILD_NUMBER}"
        
        // Images pour registry externe
        MOVIE_IMAGE = "${REGISTRY}/${USERNAME}/movie-service"
        CAST_IMAGE = "${REGISTRY}/${USERNAME}/cast-service"
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo "Récupération du code..."
                checkout scm
            }
        }
        
        stage('Build Images') {
            steps {
                echo "Construction des images..."
                script {
                    sh '''
                        # Build Movie Service
                        if [ -d "movie-service" ] && [ -f "movie-service/Dockerfile" ]; then
                            podman build -t ${MOVIE_IMAGE}:${BUILD_TAG} ./movie-service/
                            podman tag ${MOVIE_IMAGE}:${BUILD_TAG} ${MOVIE_IMAGE}:latest
                            echo "Movie service built"
                        else
                            echo "ERROR: Movie service Dockerfile not found"
                            exit 1
                        fi
                        
                        # Build Cast Service  
                        if [ -d "cast-service" ] && [ -f "cast-service/Dockerfile" ]; then
                            podman build -t ${CAST_IMAGE}:${BUILD_TAG} ./cast-service/
                            podman tag ${CAST_IMAGE}:${BUILD_TAG} ${CAST_IMAGE}:latest
                            echo "Cast service built"
                        else
                            echo "ERROR: Cast service Dockerfile not found"
                            exit 1
                        fi
                        
                        echo "Images construites:"
                        podman images | grep "${USERNAME}" || echo "Aucune image trouvée"
                    '''
                }
            }
        }
        
        stage('Push to Registry') {
            steps {
                echo "Publication vers c8n.io..."
                withCredentials([usernamePassword(credentialsId: 'c8n-registry', usernameVariable: 'REGISTRY_USER', passwordVariable: 'REGISTRY_PASS')]) {
                    sh '''
                        echo "Registry: ${REGISTRY}"
                        echo "Username: ${REGISTRY_USER}"
                        
                        # Nettoyage des connexions précédentes
                        podman logout ${REGISTRY} 2>/dev/null || true
                        
                        echo "Connexion au registry..."
                        if printf '%s' "${REGISTRY_PASS}" | podman login "${REGISTRY}" -u "${REGISTRY_USER}" --password-stdin; then
                            echo "Connexion réussie"
                            
                            # Push vers registry externe
                            echo "Push movie service..."
                            podman push ${MOVIE_IMAGE}:${BUILD_TAG}
                            podman push ${MOVIE_IMAGE}:latest
                            echo "Movie service pushed"
                            
                            echo "Push cast service..."
                            podman push ${CAST_IMAGE}:${BUILD_TAG}
                            podman push ${CAST_IMAGE}:latest
                            echo "Cast service pushed"
                            
                            echo "Images publiées sur registry"
                        else
                            echo "Échec de connexion au registry"
                            exit 1
                        fi
                    '''
                }
            }
        }
        
        stage('Deploy DEV') {
            when { 
                anyOf { 
                    branch 'main'; branch 'master'; branch 'develop' 
                } 
            }
            steps {
                echo "Déploiement automatique en DEV avec Helm..."
                script {
                    sh '''
                        # Vérifier que Minikube est démarré
                        if ! minikube status | grep -q "Running"; then
                            echo "Démarrage de Minikube..."
                            minikube start --driver=podman
                        fi
                        
                        # Configurer kubectl pour Minikube
                        eval $(minikube docker-env)
                        
                        # Créer le namespace dev s'il n'existe pas
                        kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
                        
                        # Vérifier si Helm est installé
                        if ! command -v helm &> /dev/null; then
                            echo "Helm n'est pas installé. Installation..."
                            curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
                        fi
                        
                        # Déploiement avec Helm
                        helm upgrade --install reimagined-spork-dev ./charts \\
                            --namespace dev \\
                            --set image.repository=${MOVIE_IMAGE} \\
                            --set image.tag=${BUILD_TAG} \\
                            --set image.pullPolicy=Always \\
                            --set castService.image.repository=${CAST_IMAGE} \\
                            --set castService.image.tag=${BUILD_TAG} \\
                            --set castService.image.pullPolicy=Always \\
                            --set environment=dev \\
                            --set replicaCount=1 \\
                            --wait --timeout=300s
                        
                        # Vérifier le déploiement
                        kubectl get pods -n dev -l app.kubernetes.io/instance=reimagined-spork-dev
                        
                        echo "Déploiement DEV terminé"
                        
                        # Afficher l'URL d'accès
                        echo "Services disponibles en DEV:"
                        kubectl get services -n dev
                        
                        # Si un service de type NodePort existe, afficher l'URL
                        if kubectl get service -n dev -o jsonpath='{.items[?(@.spec.type=="NodePort")].metadata.name}' | grep -q .; then
                            echo "Accès via Minikube:"
                            minikube service list -n dev
                        fi
                    '''
                }
            }
        }
        
        stage('Production Approval') {
            when { 
                anyOf { 
                    branch 'main'; branch 'master' 
                } 
            }
            steps {
                script {
                    timeout(time: 10, unit: 'MINUTES') {
                        def deployProd = input(
                            message: 'Déployer en PRODUCTION ?', 
                            ok: 'DÉPLOYER',
                            parameters: [
                                choice(
                                    name: 'DEPLOY_PROD', 
                                    choices: ['Non', 'Oui'], 
                                    description: 'Confirmer le déploiement en production ?'
                                )
                            ]
                        )
                        env.DEPLOY_PROD = deployProd
                    }
                }
            }
        }
        
        stage('Deploy PROD') {
            when { 
                allOf {
                    anyOf { branch 'main'; branch 'master' }
                    environment name: 'DEPLOY_PROD', value: 'Oui'
                }
            }
            steps {
                echo "Déploiement PRODUCTION avec Helm..."
                script {
                    sh '''
                        # Configurer kubectl pour Minikube
                        eval $(minikube docker-env)
                        
                        # Créer le namespace prod s'il n'existe pas
                        kubectl create namespace prod --dry-run=client -o yaml | kubectl apply -f -
                        
                        # Déploiement production avec Helm - configuration robuste
                        helm upgrade --install reimagined-spork-prod ./charts \\
                            --namespace prod \\
                            --set image.repository=${MOVIE_IMAGE} \\
                            --set image.tag=${BUILD_TAG} \\
                            --set image.pullPolicy=Always \\
                            --set castService.image.repository=${CAST_IMAGE} \\
                            --set castService.image.tag=${BUILD_TAG} \\
                            --set castService.image.pullPolicy=Always \\
                            --set environment=prod \\
                            --set replicaCount=3 \\
                            --set resources.limits.cpu=500m \\
                            --set resources.limits.memory=512Mi \\
                            --set resources.requests.cpu=250m \\
                            --set resources.requests.memory=256Mi \\
                            --set castService.resources.limits.cpu=500m \\
                            --set castService.resources.limits.memory=512Mi \\
                            --set castService.resources.requests.cpu=250m \\
                            --set castService.resources.requests.memory=256Mi \\
                            --set autoscaling.enabled=true \\
                            --set autoscaling.minReplicas=2 \\
                            --set autoscaling.maxReplicas=5 \\
                            --set autoscaling.targetCPUUtilizationPercentage=80 \\
                            --wait --timeout=600s
                        
                        # Vérifier le déploiement
                        kubectl get pods -n prod -l app.kubernetes.io/instance=reimagined-spork-prod
                        
                        echo "Déploiement PROD terminé"
                        
                        # Afficher les services et leur statut
                        echo "Services disponibles en PROD:"
                        kubectl get services -n prod
                        kubectl get hpa -n prod || echo "Pas d'HPA configuré"
                        
                        # Si un service de type NodePort existe, afficher l'URL
                        if kubectl get service -n prod -o jsonpath='{.items[?(@.spec.type=="NodePort")].metadata.name}' | grep -q .; then
                            echo "Accès via Minikube:"
                            minikube service list -n prod
                        fi
                        
                        # Vérifier la santé globale
                        echo "État des déploiements:"
                        kubectl get deployments -n prod
                    '''
                }
            }
        }
    }
    
    post {
        always {
            script {
                sh '''
                    # Nettoyage des images inutiles
                    podman image prune -f || true
                    
                    # Affichage du statut final des déploiements Helm
                    echo "=== ÉTAT FINAL DES DÉPLOIEMENTS HELM ==="
                    
                    if helm list -n dev | grep -q reimagined-spork-dev; then
                        echo "DEV - Helm Release Status:"
                        helm status reimagined-spork-dev -n dev
                    fi
                    
                    if helm list -n prod | grep -q reimagined-spork-prod; then
                        echo "PROD - Helm Release Status:"
                        helm status reimagined-spork-prod -n prod
                    fi
                    
                    echo "Tous les namespaces:"
                    kubectl get namespaces | grep -E "(dev|prod)" || echo "Aucun namespace dev/prod trouvé"
                '''
            }
        }
        
        success {
            echo """
            Pipeline réussi !
            
            Images construites:
            - Registry externe: ${REGISTRY}/${USERNAME}/*:${BUILD_TAG}
            
            Déploiements Helm:
            - DEV: reimagined-spork-dev (namespace: dev)
            - PROD: ${env.DEPLOY_PROD == 'Oui' ? 'reimagined-spork-prod (namespace: prod)' : 'Non déployé'}
            
            Commandes utiles:
            - helm list --all-namespaces
            - kubectl get all -n dev
            - kubectl get all -n prod
            - minikube service list
            """
        }
        
        failure {
            echo """
            Pipeline échoué !
            
            Vérifications à effectuer:
            - Statut de Minikube: minikube status
            - Images disponibles: podman images
            - Helm releases: helm list --all-namespaces
            - Logs des pods: kubectl logs -n <namespace> -l app.kubernetes.io/instance=reimagined-spork-<env>
            - Chart Helm: helm template ./charts --debug
            """
        }
        
        cleanup {
            echo "Nettoyage en cours..."
            sh '''
                # Déconnexion du registry
                podman logout ${REGISTRY} 2>/dev/null || true
                
                echo "Les releases Helm et ressources Kubernetes sont conservées"
                echo "Pour nettoyer:"
                echo "- helm uninstall reimagined-spork-dev -n dev"
                echo "- helm uninstall reimagined-spork-prod -n prod"
            '''
        }
    }
}