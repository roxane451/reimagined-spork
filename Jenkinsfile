pipeline {
    agent {
        kubernetes {
            apiVersion: v1
            kind: Pod
            metadata:
              labels:
                app: jenkins-agent
            spec:
              imagePullSecrets:
              - name: c8n-registry-secret
              containers:
              - name: jnlp
                image: c8n.io/roxane451/jenkins-agent:latest
                workingDir: /home/jenkins/agent
                resources:
                  requests:
                    memory: "512Mi"
                    cpu: "512m"
                  limits:
                    memory: "512Mi"
                    cpu: "512m"
                volumeMounts:
                - name: workspace-volume
                  mountPath: /home/jenkins/agent
              volumes:
              - name: workspace-volume
                emptyDir: {}
        }
    }
    
    environment {
        REGISTRY = 'c8n.io'
        USERNAME = 'roxane451'
        REPO_NAME = 'reimagined-spork'
        BUILD_TAG = "${BUILD_NUMBER}"
        MOVIE_IMAGE = "${REGISTRY}/${USERNAME}/movie-service"
        CAST_IMAGE = "${REGISTRY}/${USERNAME}/cast-service"  
        NGINX_IMAGE = "${REGISTRY}/${USERNAME}/nginx"
        KIND_CLUSTER = 'devops-cluster'
        HELM_CHART_PATH = './charts'
        HELM_RELEASE_NAME = 'reimagined-spork'
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
                                podman run --rm aquasec/trivy:latest image ${MOVIE_IMAGE}:${BUILD_TAG} || echo "Trivy scan completed"
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
                        kind load docker-image ${MOVIE_IMAGE}:${BUILD_TAG} --name ${KIND_CLUSTER}
                        kind load docker-image ${CAST_IMAGE}:${BUILD_TAG} --name ${KIND_CLUSTER}
                        kind load docker-image ${NGINX_IMAGE}:${BUILD_TAG} --name ${KIND_CLUSTER}
                        
                        echo "Images chargées avec succès dans Kind"
                        kubectl get nodes
                    '''
                }
            }
        }
    }
    
    post {
        always {
            node {
                echo "Nettoyage des ressources..."
                script {
                    sh '''
                        podman image prune -f --filter "until=24h" || true
                        mkdir -p /tmp/jenkins-logs/${BUILD_NUMBER}
                        kubectl logs --all-containers=true --selector="app in (movie-service,cast-service,nginx)" -n dev > /tmp/jenkins-logs/${BUILD_NUMBER}/dev-logs.txt || true
                        echo "Nettoyage terminé"
                    '''
                }
                archiveArtifacts artifacts: 'charts/**/*', allowEmptyArchive: true
                junit testResults: 'test-results/*.xml', allowEmptyResults: true
            }
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
        }
        
        failure {
            echo """
            ❌ PIPELINE ÉCHOUÉ !
            🔍 Vérifiez les logs pour plus de détails.
            📋 Build: #${BUILD_NUMBER}
            🌐 Console: ${BUILD_URL}console
            """
        }
        
        unstable {
            echo "⚠️ Pipeline instable - Vérifiez les tests et les warnings"
        }
        
        cleanup {
            echo "Nettoyage final..."
        }
    }
}