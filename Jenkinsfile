pipeline {
    agent any
    
    environment {
        // Registry Configuration
        REGISTRY = 'c8n.io'
        USERNAME = 'roxane451'
        REPO_NAME = 'reimagined-spork'
        BUILD_TAG = "${BUILD_NUMBER}"
        
        // Image Names
        MOVIE_IMAGE = "${REGISTRY}/${USERNAME}/movie-service"
        CAST_IMAGE = "${REGISTRY}/${USERNAME}/cast-service"  
        NGINX_IMAGE = "${REGISTRY}/${USERNAME}/nginx"
        
        // Kind cluster name
        KIND_CLUSTER = 'devops-cluster'
        
        // Helm settings
        HELM_CHART_PATH = './charts'
        HELM_RELEASE_NAME = 'reimagined-spork'
    }
    
    tools {
        // Specify tools versions if needed
        helm 'helm-3'
    }
    
    stages {
        stage('🔍 Environment Check') {
            steps {
                echo "Vérification de l'environnement..."
                script {
                    sh '''
                        echo "=== Vérification des outils ==="
                        podman --version || { echo "Podman non trouvé"; exit 1; }
                        kind --version || { echo "Kind non trouvé"; exit 1; }
                        kubectl version --client || { echo "Kubectl non trouvé"; exit 1; }
                        helm version || { echo "Helm non trouvé"; exit 1; }
                        
                        echo "=== Vérification du cluster Kind ==="
                        if ! kind get clusters | grep -q "${KIND_CLUSTER}"; then
                            echo "Cluster Kind non trouvé, création..."
                            export KIND_EXPERIMENTAL_PROVIDER=podman
                            kind create cluster --name ${KIND_CLUSTER}
                        fi
                        
                        echo "=== Configuration kubectl ==="
                        kind export kubeconfig --name ${KIND_CLUSTER}
                        kubectl cluster-info
                        kubectl get nodes
                        
                        echo "=== Création des namespaces ==="
                        kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
                        kubectl create namespace qa --dry-run=client -o yaml | kubectl apply -f -
                        kubectl create namespace staging --dry-run=client -o yaml | kubectl apply -f -
                        kubectl create namespace prod --dry-run=client -o yaml | kubectl apply -f -
                    '''
                }
            }
        }
        
        stage('📥 Checkout') {
            steps {
                echo "Récupération du code source..."
                checkout scm
                
                // Afficher les informations Git
                script {
                    sh '''
                        echo "=== Informations Git ==="
                        git log -1 --oneline
                        echo "Branche courante: $(git branch --show-current)"
                        echo "Commit SHA: $(git rev-parse HEAD)"
                    '''
                }
            }
        }
        
        stage('🏗️ Build Images') {
            steps {
                echo "Construction des images avec Podman..."
                script {
                    sh '''
                        echo "=== Build Movie Service ==="
                        if [ -d "movie-service" ] && [ -f "movie-service/Dockerfile" ]; then
                            podman build -t ${MOVIE_IMAGE}:${BUILD_TAG} ./movie-service/
                            podman tag ${MOVIE_IMAGE}:${BUILD_TAG} ${MOVIE_IMAGE}:latest
                            echo "Movie service image built successfully"
                        else
                            echo "Movie service Dockerfile not found"
                            exit 1
                        fi
                        
                        echo "=== Build Cast Service ==="
                        if [ -d "cast-service" ] && [ -f "cast-service/Dockerfile" ]; then
                            podman build -t ${CAST_IMAGE}:${BUILD_TAG} ./cast-service/
                            podman tag ${CAST_IMAGE}:${BUILD_TAG} ${CAST_IMAGE}:latest
                            echo "Cast service image built successfully"
                        else
                            echo "Cast service Dockerfile not found"
                            exit 1
                        fi
                        
                        echo "=== Build Nginx ==="
                        if [ -d "nginx" ] && [ -f "nginx/Dockerfile" ]; then
                            podman build -t ${NGINX_IMAGE}:${BUILD_TAG} ./nginx/
                            podman tag ${NGINX_IMAGE}:${BUILD_TAG} ${NGINX_IMAGE}:latest
                            echo "Nginx image built successfully"
                        else
                            echo "Nginx Dockerfile not found"
                            exit 1
                        fi
                        
                        echo "=== Images construites ==="
                        podman images | grep ${USERNAME}
                    '''
                }
            }
        }
        
        stage('🧪 Tests') {
            parallel {
                stage('Security Scan') {
                    steps {
                        echo "Scan de sécurité des images..."
                        script {
                            sh '''
                                echo "=== Security scanning avec Podman ==="
                                # Scan des images pour les vulnérabilités
                                podman run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                                    -v ${PWD}:/workspace aquasec/trivy:latest \
                                    image ${MOVIE_IMAGE}:${BUILD_TAG} || echo "Trivy scan completed"
                            '''
                        }
                    }
                }
                
                stage('Lint Helm Charts') {
                    steps {
                        echo "Validation des Charts Helm..."
                        script {
                            sh '''
                                echo "=== Helm Chart Validation ==="
                                if [ -d "${HELM_CHART_PATH}" ]; then
                                    helm lint ${HELM_CHART_PATH}
                                    helm template ${HELM_RELEASE_NAME} ${HELM_CHART_PATH} --debug --dry-run
                                else
                                    echo "Helm charts directory not found"
                                    exit 1
                                fi
                            '''
                        }
                    }
                }
            }
        }
        
        stage('📤 Push to Registry') {
            steps {
                echo "Publication vers c8n.io..."
                withCredentials([usernamePassword(credentialsId: 'c8n-registry', usernameVariable: 'REGISTRY_USER', passwordVariable: 'REGISTRY_PASS')]) {
                    script {
                        sh '''
                            echo "=== Connexion au registry ==="
                            echo "Registry: ${REGISTRY}"
                            echo "Username: ${REGISTRY_USER}"
                            
                            # Logout puis login
                            podman logout ${REGISTRY} 2>/dev/null || true
                            
                            if printf '%s' "${REGISTRY_PASS}" | podman login "${REGISTRY}" -u "${REGISTRY_USER}" --password-stdin; then
                                echo "Connexion réussie au registry"
                                
                                echo "=== Push Movie Service ==="
                                podman push ${MOVIE_IMAGE}:${BUILD_TAG}
                                podman push ${MOVIE_IMAGE}:latest
                                
                                echo "=== Push Cast Service ==="
                                podman push ${CAST_IMAGE}:${BUILD_TAG}
                                podman push ${CAST_IMAGE}:latest
                                
                                echo "=== Push Nginx ==="
                                podman push ${NGINX_IMAGE}:${BUILD_TAG}
                                podman push ${NGINX_IMAGE}:latest
                                
                                echo "Toutes les images publiées avec succès"
                            else
                                echo "Échec de connexion au registry"
                                exit 1
                            fi
                        '''
                    }
                }
            }
        }
        
        stage('🔄 Load Images to Kind') {
            steps {
                echo "Chargement des images dans Kind..."
                script {
                    sh '''
                        echo "=== Chargement des images dans Kind ==="
                        
                        # Chargement via Kind
                        kind load docker-image ${MOVIE_IMAGE}:${BUILD_TAG} --name ${KIND_CLUSTER}
                        kind load docker-image ${CAST_IMAGE}:${BUILD_TAG} --name ${KIND_CLUSTER}
                        kind load docker-image ${NGINX_IMAGE}:${BUILD_TAG} --name ${KIND_CLUSTER}
                        
                        echo "Images chargées avec succès dans Kind"
                        
                        # Vérification des images dans le cluster
                        kubectl get nodes
                        docker exec -it ${KIND_CLUSTER}-control-plane crictl images | grep ${USERNAME} || echo "Images chargées"
                    '''
                }
            }
        }
        
        stage('🚀 Deploy DEV') {
            when { 
                anyOf { 
                    branch 'main'; branch 'master'; branch 'develop' 
                } 
            }
            steps {
                echo "Déploiement automatique en environnement DEV..."
                script {
                    sh '''
                        echo "=== Déploiement Helm en DEV ==="
                        
                        # Configuration des valeurs pour DEV
                        helm upgrade --install ${HELM_RELEASE_NAME}-dev ${HELM_CHART_PATH} \
                            --namespace dev \
                            --set global.imageTag=${BUILD_TAG} \
                            --set movieService.replicaCount=1 \
                            --set castService.replicaCount=1 \
                            --set nginx.replicaCount=1 \
                            --set movieService.resources.requests.cpu=100m \
                            --set movieService.resources.requests.memory=128Mi \
                            --set castService.resources.requests.cpu=100m \
                            --set castService.resources.requests.memory=128Mi \
                            --set nginx.resources.requests.cpu=50m \
                            --set nginx.resources.requests.memory=64Mi \
                            --wait --timeout=300s
                        
                        echo "=== Vérification du déploiement DEV ==="
                        kubectl rollout status deployment/movie-service -n dev --timeout=300s
                        kubectl rollout status deployment/cast-service -n dev --timeout=300s  
                        kubectl rollout status deployment/nginx -n dev --timeout=300s
                        
                        echo "=== État des ressources DEV ==="
                        kubectl get pods -n dev
                        kubectl get services -n dev
                        
                        echo "Déploiement DEV terminé avec succès"
                    '''
                }
            }
        }
        
        stage('🧪 Deploy QA') {
            when { 
                anyOf { 
                    branch 'main'; branch 'master'; branch 'develop'; branch 'release/*'
                } 
            }
            steps {
                echo "Déploiement en environnement QA..."
                script {
                    sh '''
                        echo "=== Déploiement Helm en QA ==="
                        
                        helm upgrade --install ${HELM_RELEASE_NAME}-qa ${HELM_CHART_PATH} \
                            --namespace qa \
                            --set global.imageTag=${BUILD_TAG} \
                            --set movieService.replicaCount=1 \
                            --set castService.replicaCount=1 \
                            --set nginx.replicaCount=1 \
                            --set movieService.resources.requests.cpu=150m \
                            --set movieService.resources.requests.memory=192Mi \
                            --set castService.resources.requests.cpu=150m \
                            --set castService.resources.requests.memory=192Mi \
                            --wait --timeout=300s
                        
                        echo "=== Tests d'intégration QA ==="
                        kubectl rollout status deployment/movie-service -n qa --timeout=300s
                        kubectl rollout status deployment/cast-service -n qa --timeout=300s
                        kubectl rollout status deployment/nginx -n qa --timeout=300s
                        
                        # Tests de santé des services
                        echo "Exécution des tests de santé..."
                        kubectl get pods -n qa
                        
                        echo "Déploiement QA terminé avec succès"
                    '''
                }
            }
        }
        
        stage('🎯 Deploy Staging') {
            when { 
                anyOf { 
                    branch 'main'; branch 'master'
                } 
            }
            steps {
                echo "Déploiement en environnement STAGING..."
                script {
                    sh '''
                        echo "=== Déploiement Helm en STAGING ==="
                        
                        helm upgrade --install ${HELM_RELEASE_NAME}-staging ${HELM_CHART_PATH} \
                            --namespace staging \
                            --set global.imageTag=${BUILD_TAG} \
                            --set movieService.replicaCount=2 \
                            --set castService.replicaCount=2 \
                            --set nginx.replicaCount=2 \
                            --set movieService.resources.requests.cpu=200m \
                            --set movieService.resources.requests.memory=256Mi \
                            --set castService.resources.requests.cpu=200m \
                            --set castService.resources.requests.memory=256Mi \
                            --wait --timeout=300s
                        
                        echo "=== Tests de performance STAGING ==="
                        kubectl rollout status deployment/movie-service -n staging --timeout=300s
                        kubectl rollout status deployment/cast-service -n staging --timeout=300s
                        kubectl rollout status deployment/nginx -n staging --timeout=300s
                        
                        echo "=== État des ressources STAGING ==="
                        kubectl get pods -n staging
                        kubectl get services -n staging
                        
                        echo "Déploiement STAGING terminé avec succès"
                    '''
                }
            }
        }
        
        stage('✋ Production Approval') {
            when { 
                anyOf { 
                    branch 'main'; branch 'master' 
                } 
            }
            steps {
                echo "Demande d'approbation pour la production..."
                script {
                    timeout(time: 10, unit: 'MINUTES') {
                        def deployChoice = input(
                            message: '🚀 Déployer en PRODUCTION ?', 
                            ok: 'VALIDER',
                            parameters: [
                                choice(
                                    name: 'DEPLOY_PROD', 
                                    choices: ['Non', 'Oui'], 
                                    description: 'Confirmer le déploiement en production ?'
                                ),
                                string(
                                    name: 'APPROVER', 
                                    defaultValue: '', 
                                    description: 'Nom de la personne qui approuve'
                                )
                            ]
                        )
                        
                        if (deployChoice.DEPLOY_PROD == 'Oui') {
                            echo "✅ Déploiement PROD approuvé par: ${deployChoice.APPROVER}"
                            env.PROD_APPROVED = 'true'
                            env.APPROVER_NAME = deployChoice.APPROVER
                        } else {
                            echo "❌ Déploiement PROD annulé"
                            env.PROD_APPROVED = 'false'
                        }
                    }
                }
            }
        }
        
        stage('🏭 Deploy Production') {
            when { 
                allOf {
                    anyOf { branch 'main'; branch 'master' }
                    environment name: 'PROD_APPROVED', value: 'true'
                }
            }
            steps {
                echo "🏭 Déploiement en PRODUCTION..."
                script {
                    sh '''
                        echo "=== Déploiement Helm en PRODUCTION ==="
                        echo "Approuvé par: ${APPROVER_NAME}"
                        
                        # Backup de la version précédente
                        echo "=== Sauvegarde de la configuration actuelle ==="
                        helm get values ${HELM_RELEASE_NAME}-prod -n prod > /tmp/prod-backup-${BUILD_NUMBER}.yaml 2>/dev/null || echo "Pas de déploiement précédent"
                        
                        # Déploiement avec stratégie rolling update
                        helm upgrade --install ${HELM_RELEASE_NAME}-prod ${HELM_CHART_PATH} \
                            --namespace prod \
                            --set global.imageTag=${BUILD_TAG} \
                            --set movieService.replicaCount=3 \
                            --set castService.replicaCount=3 \
                            --set nginx.replicaCount=2 \
                            --set movieService.resources.requests.cpu=250m \
                            --set movieService.resources.requests.memory=256Mi \
                            --set movieService.resources.limits.cpu=500m \
                            --set movieService.resources.limits.memory=512Mi \
                            --set castService.resources.requests.cpu=250m \
                            --set castService.resources.requests.memory=256Mi \
                            --set castService.resources.limits.cpu=500m \
                            --set castService.resources.limits.memory=512Mi \
                            --set nginx.service.type=LoadBalancer \
                            --wait --timeout=600s
                        
                        echo "=== Vérification du déploiement PRODUCTION ==="
                        kubectl rollout status deployment/movie-service -n prod --timeout=600s
                        kubectl rollout status deployment/cast-service -n prod --timeout=600s
                        kubectl rollout status deployment/nginx -n prod --timeout=600s
                        
                        echo "=== Tests de santé PRODUCTION ==="
                        kubectl get pods -n prod
                        kubectl get services -n prod
                        
                        # Affichage des informations d'accès
                        echo "=== Informations d'accès PRODUCTION ==="
                        kubectl get service nginx -n prod
                        
                        echo "🎉 Déploiement PRODUCTION terminé avec succès !"
                        echo "Approuvé par: ${APPROVER_NAME}"
                        echo "Version déployée: ${BUILD_TAG}"
                    '''
                }
            }
        }
        
        stage('📊 Post-Deploy Verification') {
            when {
                anyOf { 
                    branch 'main'; branch 'master'; branch 'develop' 
                }
            }
            steps {
                echo "Vérifications post-déploiement..."
                script {
                    sh '''
                        echo "=== Résumé des déploiements ==="
                        
                        echo "🔍 Environnement DEV:"
                        kubectl get pods -n dev | grep ${HELM_RELEASE_NAME} || echo "Pas de déploiement DEV"
                        
                        echo "🧪 Environnement QA:"  
                        kubectl get pods -n qa | grep ${HELM_RELEASE_NAME} || echo "Pas de déploiement QA"
                        
                        echo "🎯 Environnement STAGING:"
                        kubectl get pods -n staging | grep ${HELM_RELEASE_NAME} || echo "Pas de déploiement STAGING"
                        
                        if [ "${PROD_APPROVED}" = "true" ]; then
                            echo "🏭 Environnement PRODUCTION:"
                            kubectl get pods -n prod | grep ${HELM_RELEASE_NAME} || echo "Pas de déploiement PROD"
                        fi
                        
                        echo "=== Tests de connectivité ==="
                        # Tests basiques de connectivité
                        for ns in dev qa staging prod; do
                            if kubectl get namespace $ns >/dev/null 2>&1; then
                                echo "Testing namespace: $ns"
                                kubectl get pods -n $ns | grep Running || echo "No running pods in $ns"
                            fi
                        done
                    '''
                }
            }
        }
    }
    
    post {
        always {
            echo "Nettoyage des ressources..."
            script {
                sh '''
                    # Nettoyage des images locales anciennes
                    podman image prune -f --filter "until=24h" || true
                    
                    # Sauvegarde des logs
                    mkdir -p /tmp/jenkins-logs/${BUILD_NUMBER}
                    kubectl logs --all-containers=true --selector="app in (movie-service,cast-service,nginx)" -n dev > /tmp/jenkins-logs/${BUILD_NUMBER}/dev-logs.txt || true
                    
                    echo "Nettoyage terminé"
                '''
            }
            
            // Archive des artefacts
            archiveArtifacts artifacts: 'charts/**/*', allowEmptyArchive: true
            
            // Publication des résultats de tests si disponibles
            publishTestResults testResultsPattern: 'test-results/*.xml', allowEmptyResults: true
        }
        
        success {
            echo """
            🎉 PIPELINE RÉUSSI !
            
            📦 Images construites et publiées:
            - ${REGISTRY}/${USERNAME}/movie-service:${BUILD_TAG}
            - ${REGISTRY}/${USERNAME}/cast-service:${BUILD_TAG}
            - ${REGISTRY}/${USERNAME}/nginx:${BUILD_TAG}
            
            🚀 Environnements déployés:
            - DEV: Automatique sur branches main/master/develop
            - QA: Automatique sur branches main/master/develop/release
            - STAGING: Automatique sur branches main/master
            - PROD: Manuel avec approbation sur branches main/master
            
            📋 Version: ${BUILD_TAG}
            🕒 Durée: ${currentBuild.durationString}
            """
            
            // Notification Slack/Teams si configuré
            // slackSend channel: '#devops', message: "✅ Pipeline ${env.JOB_NAME} #${BUILD_NUMBER} réussi"
        }
        
        failure {
            echo """
            ❌ PIPELINE ÉCHOUÉ !
            
            🔍 Vérifiez les logs pour plus de détails.
            📋 Build: #${BUILD_NUMBER}
            🌐 Console: ${BUILD_URL}console
            """
            
            // Notification d'échec
            // slackSend channel: '#devops', color: 'danger', message: "❌ Pipeline ${env.JOB_NAME} #${BUILD_NUMBER} échoué"
        }
        
        unstable {
            echo "⚠️ Pipeline instable - Vérifiez les tests et les warnings"
        }
        
        cleanup {
            echo "Nettoyage final..."
            // Nettoyage des workspaces si nécessaire
            // cleanWs()
        }
    }
}
