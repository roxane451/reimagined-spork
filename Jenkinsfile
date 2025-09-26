pipeline {
    agent {
        kubernetes {
            yaml '''
                apiVersion: v1
                kind: Pod
                spec:
                  securityContext:
                    runAsUser: 0
                    fsGroup: 0
                  containers:
                  - name: podman
                    image: quay.io/podman/stable:latest
                    command:
                    - sleep
                    args:
                    - 99d
                    securityContext:
                      privileged: true
                      runAsUser: 0
                    volumeMounts:
                    - name: podman-storage
                      mountPath: /var/lib/containers
                  - name: kubectl
                    image: bitnami/kubectl:latest
                    command:
                    - sleep
                    args:
                    - 99d
                    env:
                    - name: KUBECONFIG
                      value: /tmp/kubeconfig
                  - name: helm
                    image: alpine/helm:latest
                    command:
                    - sleep
                    args:
                    - 99d
                    env:
                    - name: KUBECONFIG
                      value: /tmp/kubeconfig
                  volumes:
                  - name: podman-storage
                    emptyDir:
                      sizeLimit: 10Gi
            '''
        }
    }
    
    environment {
        REGISTRY = 'c8n.io'
        REGISTRY_CRED = 'c8n-registry'
        NAMESPACE_DEV = 'dev'
        NAMESPACE_QA = 'qa'
        NAMESPACE_STAGING = 'staging'
        NAMESPACE_PROD = 'prod'
    }
    
    stages {
        stage('Info') {
            steps {
                script {
                    def branchName = env.BRANCH_NAME ?: env.GIT_BRANCH
                    if (branchName?.startsWith('origin/')) {
                        branchName = branchName.replace('origin/', '')
                    }
                    env.CLEAN_BRANCH = branchName
                    echo "Branch: ${branchName}"
                    echo "Build: ${env.BUILD_NUMBER}"
                }
            }
        }
        
        stage('Prepare Namespaces') {
            steps {
                container('kubectl') {
                    sh '''
                        # Créer les namespaces s'ils n'existent pas
                        kubectl create namespace $NAMESPACE_DEV --dry-run=client -o yaml | kubectl apply -f -
                        kubectl create namespace $NAMESPACE_QA --dry-run=client -o yaml | kubectl apply -f -
                        kubectl create namespace $NAMESPACE_STAGING --dry-run=client -o yaml | kubectl apply -f -
                        kubectl create namespace $NAMESPACE_PROD --dry-run=client -o yaml | kubectl apply -f -
                    '''
                }
            }
        }
        
        stage('Build and Push Images') {
            parallel {
                stage('Build Cast Service') {
                    steps {
                        container('podman') {
                            script {
                                dir('cast-service') {
                                    withCredentials([usernamePassword(credentialsId: REGISTRY_CRED, passwordVariable: 'PASS', usernameVariable: 'USER')]) {
                                        sh '''
                                            # Configuration Podman
                                            mkdir -p ~/.config/containers
                                            cat > ~/.config/containers/storage.conf << EOF
[storage]
driver = "vfs"
runroot = "/tmp/podman-run"
graphroot = "/tmp/podman-storage"
EOF
                                            
                                            # Connexion au registry
                                            echo $PASS | podman login --username $USER --password-stdin $REGISTRY
                                            
                                            # Extraction du nom utilisateur propre
                                            CLEAN_USER=$(echo $USER | cut -d'@' -f1)
                                            
                                            # Build et push
                                            podman build --format=docker -t $REGISTRY/$CLEAN_USER/cast-service:$BUILD_NUMBER .
                                            podman push $REGISTRY/$CLEAN_USER/cast-service:$BUILD_NUMBER
                                            
                                            # Tag latest pour les branches principales
                                            if [[ "$GIT_BRANCH" =~ (main|master|develop) ]]; then
                                                podman tag $REGISTRY/$CLEAN_USER/cast-service:$BUILD_NUMBER $REGISTRY/$CLEAN_USER/cast-service:latest
                                                podman push $REGISTRY/$CLEAN_USER/cast-service:latest
                                            fi
                                            
                                            echo " Cast service image pushed: $REGISTRY/$CLEAN_USER/cast-service:$BUILD_NUMBER"
                                        '''
                                    }
                                }
                            }
                        }
                    }
                }
                
                stage('Build Movie Service') {
                    steps {
                        container('podman') {
                            script {
                                dir('movie-service') {
                                    withCredentials([usernamePassword(credentialsId: REGISTRY_CRED, passwordVariable: 'PASS', usernameVariable: 'USER')]) {
                                        sh '''
                                            # Configuration Podman
                                            mkdir -p ~/.config/containers
                                            cat > ~/.config/containers/storage.conf << EOF
[storage]
driver = "vfs"
runroot = "/tmp/podman-run"
graphroot = "/tmp/podman-storage"
EOF
                                            
                                            CLEAN_USER=$(echo $USER | cut -d'@' -f1)
                                            
                                            # Build et push
                                            podman build --format=docker -t $REGISTRY/$CLEAN_USER/movie-service:$BUILD_NUMBER .
                                            podman push $REGISTRY/$CLEAN_USER/movie-service:$BUILD_NUMBER
                                            
                                            # Tag latest pour les branches principales
                                            if [[ "$GIT_BRANCH" =~ (main|master|develop) ]]; then
                                                podman tag $REGISTRY/$CLEAN_USER/movie-service:$BUILD_NUMBER $REGISTRY/$CLEAN_USER/movie-service:latest
                                                podman push $REGISTRY/$CLEAN_USER/movie-service:latest
                                            fi
                                            
                                            echo " Movie service image pushed: $REGISTRY/$CLEAN_USER/movie-service:$BUILD_NUMBER"
                                        '''
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        stage('Deploy to DEV') {
            when {
                anyOf {
                    expression { env.CLEAN_BRANCH == 'develop' }
                    expression { env.CLEAN_BRANCH == 'main' }
                    expression { env.CLEAN_BRANCH == 'master' }
                    expression { env.CLEAN_BRANCH?.startsWith('feature/') }
                    expression { env.CLEAN_BRANCH?.startsWith('hotfix/') }
                }
            }
            steps {
                container('helm') {
                    script {
                        withCredentials([usernamePassword(credentialsId: REGISTRY_CRED, passwordVariable: 'PASS', usernameVariable: 'USER')]) {
                            sh '''
                                CLEAN_USER=$(echo $USER | cut -d'@' -f1)
                                
                                # Vérifier si Helm chart existe
                                if [ -d "charts" ]; then
                                    echo " Déploiement avec Helm..."
                                    helm upgrade --install reimagined-spork-dev ./charts \
                                        --namespace=$NAMESPACE_DEV \
                                        --set image.repository=$REGISTRY/$CLEAN_USER/movie-service \
                                        --set image.tag=$BUILD_NUMBER \
                                        --set castService.image.repository=$REGISTRY/$CLEAN_USER/cast-service \
                                        --set castService.image.tag=$BUILD_NUMBER \
                                        --set environment=dev \
                                        --wait --timeout=300s
                                else
                                    echo " Pas de Helm chart trouvé, utilisation de kubectl..."
                                    # Fallback avec kubectl basique
                                    kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cast-service
  namespace: $NAMESPACE_DEV
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cast-service
  template:
    metadata:
      labels:
        app: cast-service
    spec:
      containers:
      - name: cast-service
        image: $REGISTRY/$CLEAN_USER/cast-service:$BUILD_NUMBER
        ports:
        - containerPort: 8000
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: movie-service
  namespace: $NAMESPACE_DEV
spec:
  replicas: 1
  selector:
    matchLabels:
      app: movie-service
  template:
    metadata:
      labels:
        app: movie-service
    spec:
      containers:
      - name: movie-service
        image: $REGISTRY/$CLEAN_USER/movie-service:$BUILD_NUMBER
        ports:
        - containerPort: 8001
---
apiVersion: v1
kind: Service
metadata:
  name: cast-service
  namespace: $NAMESPACE_DEV
spec:
  selector:
    app: cast-service
  ports:
  - port: 8000
    targetPort: 8000
  type: ClusterIP
---
apiVersion: v1
kind: Service
metadata:
  name: movie-service
  namespace: $NAMESPACE_DEV
spec:
  selector:
    app: movie-service
  ports:
  - port: 8001
    targetPort: 8001
  type: ClusterIP
EOF
                                fi
                                
                                echo "Déploiement DEV terminé"
                                kubectl get pods -n $NAMESPACE_DEV
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Deploy to QA') {
            when { 
                expression { env.CLEAN_BRANCH == 'develop' }
            }
            steps {
                container('kubectl') {
                    script {
                        withCredentials([usernamePassword(credentialsId: REGISTRY_CRED, passwordVariable: 'PASS', usernameVariable: 'USER')]) {
                            sh '''
                                CLEAN_USER=$(echo $USER | cut -d'@' -f1)
                                
                                # Mise à jour des images dans QA
                                kubectl set image deployment/cast-service cast-service=$REGISTRY/$CLEAN_USER/cast-service:$BUILD_NUMBER -n $NAMESPACE_QA || \
                                kubectl create deployment cast-service --image=$REGISTRY/$CLEAN_USER/cast-service:$BUILD_NUMBER -n $NAMESPACE_QA
                                
                                kubectl set image deployment/movie-service movie-service=$REGISTRY/$CLEAN_USER/movie-service:$BUILD_NUMBER -n $NAMESPACE_QA || \
                                kubectl create deployment movie-service --image=$REGISTRY/$CLEAN_USER/movie-service:$BUILD_NUMBER -n $NAMESPACE_QA
                                
                                kubectl get pods -n $NAMESPACE_QA
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Deploy to STAGING') {
            when { 
                expression { env.CLEAN_BRANCH?.startsWith('release/') }
            }
            steps {
                container('kubectl') {
                    script {
                        withCredentials([usernamePassword(credentialsId: REGISTRY_CRED, passwordVariable: 'PASS', usernameVariable: 'USER')]) {
                            sh '''
                                CLEAN_USER=$(echo $USER | cut -d'@' -f1)
                                
                                kubectl set image deployment/cast-service cast-service=$REGISTRY/$CLEAN_USER/cast-service:$BUILD_NUMBER -n $NAMESPACE_STAGING || \
                                kubectl create deployment cast-service --image=$REGISTRY/$CLEAN_USER/cast-service:$BUILD_NUMBER -n $NAMESPACE_STAGING
                                
                                kubectl set image deployment/movie-service movie-service=$REGISTRY/$CLEAN_USER/movie-service:$BUILD_NUMBER -n $NAMESPACE_STAGING || \
                                kubectl create deployment movie-service --image=$REGISTRY/$CLEAN_USER/movie-service:$BUILD_NUMBER -n $NAMESPACE_STAGING
                                
                                # Exposition des services en staging
                                kubectl expose deployment cast-service --port=8000 --target-port=8000 --type=ClusterIP -n $NAMESPACE_STAGING --dry-run=client -o yaml | kubectl apply -f -
                                kubectl expose deployment movie-service --port=8001 --target-port=8001 --type=ClusterIP -n $NAMESPACE_STAGING --dry-run=client -o yaml | kubectl apply -f -
                                
                                kubectl get pods -n $NAMESPACE_STAGING
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Deploy to PROD') {
            when { 
                anyOf {
                    expression { env.CLEAN_BRANCH == 'master' }
                    expression { env.CLEAN_BRANCH == 'main' }
                }
            }
            steps {
                script {
                    timeout(time: 10, unit: 'MINUTES') {
                        input message: 'Deploy to PRODUCTION?', ok: 'DEPLOY TO PROD'
                    }
                }
                container('kubectl') {
                    script {
                        withCredentials([usernamePassword(credentialsId: REGISTRY_CRED, passwordVariable: 'PASS', usernameVariable: 'USER')]) {
                            sh '''
                                CLEAN_USER=$(echo $USER | cut -d'@' -f1)
                                
                                # Déploiement production avec plus de réplicas
                                kubectl set image deployment/cast-service cast-service=$REGISTRY/$CLEAN_USER/cast-service:$BUILD_NUMBER -n $NAMESPACE_PROD || \
                                kubectl create deployment cast-service --image=$REGISTRY/$CLEAN_USER/cast-service:$BUILD_NUMBER -n $NAMESPACE_PROD
                                
                                kubectl set image deployment/movie-service movie-service=$REGISTRY/$CLEAN_USER/movie-service:$BUILD_NUMBER -n $NAMESPACE_PROD || \
                                kubectl create deployment movie-service --image=$REGISTRY/$CLEAN_USER/movie-service:$BUILD_NUMBER -n $NAMESPACE_PROD
                                
                                # Scaler pour la production
                                kubectl scale deployment cast-service --replicas=3 -n $NAMESPACE_PROD
                                kubectl scale deployment movie-service --replicas=3 -n $NAMESPACE_PROD
                                
                                kubectl get pods -n $NAMESPACE_PROD
                                echo "🚀 Production deployment completed!"
                            '''
                        }
                    }
                }
            }
        }
    }
    
    post {
        success {
            echo '🎉 Pipeline completed successfully!'
            script {
                withCredentials([usernamePassword(credentialsId: REGISTRY_CRED, passwordVariable: 'PASS', usernameVariable: 'USER')]) {
                    def cleanUser = env.USER.split('@')[0]
                    echo " Images created:"
                    echo "- ${REGISTRY}/${cleanUser}/cast-service:${BUILD_NUMBER}"
                    echo "- ${REGISTRY}/${cleanUser}/movie-service:${BUILD_NUMBER}"
                    echo "🌍 Deployed to: ${env.CLEAN_BRANCH}"
                }
            }
        }
        failure {
            echo ' Pipeline failed - check logs above'
        }
        always {
            container('podman') {
                sh '''
                    echo "🧹 Cleaning up Podman resources..."
                    podman system prune -f || true
                    podman logout $REGISTRY || true
                '''
            }
        }
    }
}
