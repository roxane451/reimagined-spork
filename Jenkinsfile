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
                  - name: helm
                    image: alpine/helm:latest
                    command:
                    - sleep
                    args:
                    - 99d
                  volumes:
                  - name: podman-storage
                    emptyDir:
                      sizeLimit: 5Gi
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
        stage('🔍 Info') {
            steps {
                script {
                    echo "Branch: ${env.BRANCH_NAME ?: env.GIT_BRANCH}"
                    echo "Build: ${env.BUILD_NUMBER}"
                    echo "Workspace: ${env.WORKSPACE}"
                }
            }
        }
        
        stage('🏗️ Build Cast Service') {
            steps {
                container('podman') {
                    script {
                        dir('cast-service') {
                            withCredentials([usernamePassword(credentialsId: REGISTRY_CRED, passwordVariable: 'PASS', usernameVariable: 'USER')]) {
                                sh '''
                                    echo "=== Podman Version ==="
                                    podman --version
                                    
                                    echo "=== Configure Podman Storage ==="
                                    mkdir -p ~/.config/containers
                                    echo '[storage]' > ~/.config/containers/storage.conf
                                    echo 'driver = "vfs"' >> ~/.config/containers/storage.conf
                                    
                                    echo "=== Login to Registry ==="
                                    echo $PASS | podman login --username $USER --password-stdin $REGISTRY
                                    
                                    echo "=== Build Cast Service ==="
                                    # Nettoyer le username (enlever @gmail.com si présent)
                                    CLEAN_USER=$(echo $USER | cut -d'@' -f1)
                                    podman build -t $REGISTRY/$CLEAN_USER/cast-service:$BUILD_NUMBER .
                                    
                                    echo "=== Push Image ==="
                                    podman push $REGISTRY/$CLEAN_USER/cast-service:$BUILD_NUMBER
                                    
                                    echo "✅ Cast Service built and pushed"
                                '''
                            }
                        }
                    }
                }
            }
        }
        
        stage('🏗️ Build Movie Service') {
            steps {
                container('podman') {
                    script {
                        dir('movie-service') {
                            withCredentials([usernamePassword(credentialsId: REGISTRY_CRED, passwordVariable: 'PASS', usernameVariable: 'USER')]) {
                                sh '''
                                    echo "=== Build Movie Service ==="
                                    # Nettoyer le username
                                    CLEAN_USER=$(echo $USER | cut -d'@' -f1)
                                    podman build -t $REGISTRY/$CLEAN_USER/movie-service:$BUILD_NUMBER .
                                    
                                    echo "=== Push Image ==="
                                    podman push $REGISTRY/$CLEAN_USER/movie-service:$BUILD_NUMBER
                                    
                                    echo "✅ Movie Service built and pushed"
                                '''
                            }
                        }
                    }
                }
            }
        }
        
        stage('🚀 Deploy to DEV') {
            when {
                anyOf {
                    branch 'develop'
                    branch 'main'
                }
            }
            steps {
                container('kubectl') {
                    script {
                        withCredentials([usernamePassword(credentialsId: REGISTRY_CRED, passwordVariable: 'PASS', usernameVariable: 'USER')]) {
                            sh '''
                                echo "=== Deploy to DEV namespace ==="
                                
                                # Simple deployment pour test
                                kubectl create deployment cast-service \
                                  --image=$REGISTRY/$USER/cast-service:$BUILD_NUMBER \
                                  --namespace=$NAMESPACE_DEV \
                                  --dry-run=client -o yaml | kubectl apply -f -
                                
                                kubectl create deployment movie-service \
                                  --image=$REGISTRY/$USER/movie-service:$BUILD_NUMBER \
                                  --namespace=$NAMESPACE_DEV \
                                  --dry-run=client -o yaml | kubectl apply -f -
                                
                                echo "✅ Deployed to DEV"
                            '''
                        }
                    }
                }
            }
        }
        
        stage('🧪 Deploy to QA') {
            when { branch 'develop' }
            steps {
                container('kubectl') {
                    script {
                        withCredentials([usernamePassword(credentialsId: REGISTRY_CRED, passwordVariable: 'PASS', usernameVariable: 'USER')]) {
                            sh '''
                                echo "=== Deploy to QA namespace ==="
                                
                                kubectl create deployment cast-service \
                                  --image=$REGISTRY/$USER/cast-service:$BUILD_NUMBER \
                                  --namespace=$NAMESPACE_QA \
                                  --dry-run=client -o yaml | kubectl apply -f -
                                
                                kubectl create deployment movie-service \
                                  --image=$REGISTRY/$USER/movie-service:$BUILD_NUMBER \
                                  --namespace=$NAMESPACE_QA \
                                  --dry-run=client -o yaml | kubectl apply -f -
                                
                                echo "✅ Deployed to QA"
                            '''
                        }
                    }
                }
            }
        }
        
        stage('🏭 Deploy to PROD') {
            when { branch 'main' }
            steps {
                input message: '🚨 Deploy to PRODUCTION? 🚨', ok: 'DEPLOY'
                container('kubectl') {
                    script {
                        withCredentials([usernamePassword(credentialsId: REGISTRY_CRED, passwordVariable: 'PASS', usernameVariable: 'USER')]) {
                            sh '''
                                echo "=== Deploy to PROD namespace ==="
                                
                                kubectl create deployment cast-service \
                                  --image=$REGISTRY/$USER/cast-service:$BUILD_NUMBER \
                                  --namespace=$NAMESPACE_PROD \
                                  --dry-run=client -o yaml | kubectl apply -f -
                                
                                kubectl create deployment movie-service \
                                  --image=$REGISTRY/$USER/movie-service:$BUILD_NUMBER \
                                  --namespace=$NAMESPACE_PROD \
                                  --dry-run=client -o yaml | kubectl apply -f -
                                
                                echo "✅ Deployed to PRODUCTION"
                            '''
                        }
                    }
                }
            }
        }
    }
    
    post {
        success {
            echo '✅ Pipeline réussi!'
        }
        failure {
            echo '❌ Pipeline échoué!'
        }
        always {
            container('podman') {
                sh '''
                    # Configure storage avant le nettoyage
                    mkdir -p ~/.config/containers
                    echo '[storage]' > ~/.config/containers/storage.conf
                    echo 'driver = "vfs"' >> ~/.config/containers/storage.conf
                    
                    podman system prune -f || true
                '''
            }
        }
    }
}
