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
        
        stage('Build Cast Service') {
            steps {
                container('podman') {
                    script {
                        dir('cast-service') {
                            withCredentials([usernamePassword(credentialsId: REGISTRY_CRED, passwordVariable: 'PASS', usernameVariable: 'USER')]) {
                                sh '''
                                    podman --version
                                    
                                    mkdir -p ~/.config/containers
                                    echo '[storage]' > ~/.config/containers/storage.conf
                                    echo 'driver = "vfs"' >> ~/.config/containers/storage.conf
                                    
                                    echo $PASS | podman login --username $USER --password-stdin $REGISTRY
                                    
                                    CLEAN_USER=$(echo $USER | cut -d'@' -f1)
                                    
                                    podman build -t $REGISTRY/$CLEAN_USER/cast-service:$BUILD_NUMBER .
                                    podman push $REGISTRY/$CLEAN_USER/cast-service:$BUILD_NUMBER
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
                                    CLEAN_USER=$(echo $USER | cut -d'@' -f1)
                                    podman build -t $REGISTRY/$CLEAN_USER/movie-service:$BUILD_NUMBER .
                                    podman push $REGISTRY/$CLEAN_USER/movie-service:$BUILD_NUMBER
                                '''
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
                container('kubectl') {
                    script {
                        withCredentials([usernamePassword(credentialsId: REGISTRY_CRED, passwordVariable: 'PASS', usernameVariable: 'USER')]) {
                            sh '''
                                CLEAN_USER=$(echo $USER | cut -d'@' -f1)
                                
                                kubectl create deployment cast-service \
                                  --image=$REGISTRY/$CLEAN_USER/cast-service:$BUILD_NUMBER \
                                  --namespace=$NAMESPACE_DEV \
                                  --dry-run=client -o yaml | kubectl apply -f -
                                
                                kubectl create deployment movie-service \
                                  --image=$REGISTRY/$CLEAN_USER/movie-service:$BUILD_NUMBER \
                                  --namespace=$NAMESPACE_DEV \
                                  --dry-run=client -o yaml | kubectl apply -f -
                                
                                kubectl expose deployment cast-service \
                                  --port=8000 --target-port=8000 --type=ClusterIP \
                                  --namespace=$NAMESPACE_DEV \
                                  --dry-run=client -o yaml | kubectl apply -f -
                                  
                                kubectl expose deployment movie-service \
                                  --port=8001 --target-port=8001 --type=ClusterIP \
                                  --namespace=$NAMESPACE_DEV \
                                  --dry-run=client -o yaml | kubectl apply -f -
                                
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
                                
                                kubectl create deployment cast-service \
                                  --image=$REGISTRY/$CLEAN_USER/cast-service:$BUILD_NUMBER \
                                  --namespace=$NAMESPACE_QA \
                                  --dry-run=client -o yaml | kubectl apply -f -
                                
                                kubectl create deployment movie-service \
                                  --image=$REGISTRY/$CLEAN_USER/movie-service:$BUILD_NUMBER \
                                  --namespace=$NAMESPACE_QA \
                                  --dry-run=client -o yaml | kubectl apply -f -
                                
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
                                
                                kubectl create deployment cast-service \
                                  --image=$REGISTRY/$CLEAN_USER/cast-service:$BUILD_NUMBER \
                                  --namespace=$NAMESPACE_STAGING \
                                  --dry-run=client -o yaml | kubectl apply -f -
                                
                                kubectl create deployment movie-service \
                                  --image=$REGISTRY/$CLEAN_USER/movie-service:$BUILD_NUMBER \
                                  --namespace=$NAMESPACE_STAGING \
                                  --dry-run=client -o yaml | kubectl apply -f -
                                
                                kubectl expose deployment cast-service \
                                  --port=8000 --target-port=8000 --type=ClusterIP \
                                  --namespace=$NAMESPACE_STAGING \
                                  --dry-run=client -o yaml | kubectl apply -f -
                                  
                                kubectl expose deployment movie-service \
                                  --port=8001 --target-port=8001 --type=ClusterIP \
                                  --namespace=$NAMESPACE_STAGING \
                                  --dry-run=client -o yaml | kubectl apply -f -
                                
                                kubectl get pods -n $NAMESPACE_STAGING
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Deploy to PROD') {
            when { 
                expression { env.CLEAN_BRANCH == 'master' }
            }
            steps {
                input message: 'Deploy to PRODUCTION?', ok: 'DEPLOY'
                container('kubectl') {
                    script {
                        withCredentials([usernamePassword(credentialsId: REGISTRY_CRED, passwordVariable: 'PASS', usernameVariable: 'USER')]) {
                            sh '''
                                CLEAN_USER=$(echo $USER | cut -d'@' -f1)
                                
                                kubectl create deployment cast-service \
                                  --image=$REGISTRY/$CLEAN_USER/cast-service:$BUILD_NUMBER \
                                  --namespace=$NAMESPACE_PROD \
                                  --dry-run=client -o yaml | kubectl apply -f -
                                
                                kubectl create deployment movie-service \
                                  --image=$REGISTRY/$CLEAN_USER/movie-service:$BUILD_NUMBER \
                                  --namespace=$NAMESPACE_PROD \
                                  --dry-run=client -o yaml | kubectl apply -f -
                                
                                kubectl get pods -n $NAMESPACE_PROD
                            '''
                        }
                    }
                }
            }
        }
    }
    
    post {
        success {
            echo 'Pipeline completed successfully'
            script {
                withCredentials([usernamePassword(credentialsId: REGISTRY_CRED, passwordVariable: 'PASS', usernameVariable: 'USER')]) {
                    def cleanUser = env.USER.split('@')[0]
                    echo "Images created:"
                    echo "- c8n.io/${cleanUser}/cast-service:${BUILD_NUMBER}"
                    echo "- c8n.io/${cleanUser}/movie-service:${BUILD_NUMBER}"
                }
            }
        }
        failure {
            echo 'Pipeline failed'
        }
        always {
            container('podman') {
                sh '''
                    mkdir -p ~/.config/containers
                    echo '[storage]' > ~/.config/containers/storage.conf
                    echo 'driver = "vfs"' >> ~/.config/containers/storage.conf
                    podman system prune -f || true
                '''
            }
        }
    }
}
