pipeline {
    agent any
    
    environment {
        REGISTRY = 'c8n.io'
        USERNAME = 'roxane451'
        REPO_NAME = 'reimagined-spork'
        BUILD_TAG = "${BUILD_NUMBER}"
        
        // Images
        MOVIE_IMAGE = "${REGISTRY}/${USERNAME}/movie-service"
        CAST_IMAGE = "${REGISTRY}/${USERNAME}/cast-service"  
        NGINX_IMAGE = "${REGISTRY}/${USERNAME}/nginx"
    }
    
    stages {
        stage('📥 Checkout') {
            steps {
                echo "📥 Récupération du code..."
                checkout scm
            }
        }
        
        stage('🔨 Build Images') {
            steps {
                echo "🔨 Construction des images..."
                script {
                    sh '''
                        # Build Movie Service
                        if [ -d "movie-service" ] && [ -f "movie-service/Dockerfile" ]; then
                            podman build -t ${MOVIE_IMAGE}:${BUILD_TAG} ./movie-service/
                            podman tag ${MOVIE_IMAGE}:${BUILD_TAG} ${MOVIE_IMAGE}:latest
                        fi
                        
                        # Build Cast Service  
                        if [ -d "cast-service" ] && [ -f "cast-service/Dockerfile" ]; then
                            podman build -t ${CAST_IMAGE}:${BUILD_TAG} ./cast-service/
                            podman tag ${CAST_IMAGE}:${BUILD_TAG} ${CAST_IMAGE}:latest
                        fi
                        
                        # Build Nginx
                        cat > Dockerfile.nginx << EOF
FROM nginx:alpine
COPY nginx_config.conf /etc/nginx/conf.d/default.conf 2>/dev/null || echo "server { listen 80; location / { return 200 'OK'; } }" > /etc/nginx/conf.d/default.conf
EXPOSE 80
EOF
                        podman build -f Dockerfile.nginx -t ${NGINX_IMAGE}:${BUILD_TAG} .
                        podman tag ${NGINX_IMAGE}:${BUILD_TAG} ${NGINX_IMAGE}:latest
                        
                        echo "✅ Images construites"
                        podman images | grep ${USERNAME}
                    '''
                }
            }
        }
        
        stage('📤 Push to Registry') {
            steps {
                echo "📤 Publication vers c8n.io..."
                withCredentials([usernamePassword(credentialsId: 'c8n-registry', usernameVariable: 'USER', passwordVariable: 'PASS')]) {
                    sh '''
                        echo $PASS | podman login ${REGISTRY} -u $USER --password-stdin
                        
                        podman push ${MOVIE_IMAGE}:${BUILD_TAG}
                        podman push ${MOVIE_IMAGE}:latest
                        
                        podman push ${CAST_IMAGE}:${BUILD_TAG} 
                        podman push ${CAST_IMAGE}:latest
                        
                        podman push ${NGINX_IMAGE}:${BUILD_TAG}
                        podman push ${NGINX_IMAGE}:latest
                        
                        podman logout ${REGISTRY}
                        echo "✅ Images publiées sur ${REGISTRY}/${USERNAME}/"
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
                echo "🚀 Déploiement automatique en DEV..."
                script {
                    sh '''
                        kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
                        
                        cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: reimagined-spork
  namespace: dev
spec:
  replicas: 1
  selector:
                    matchLabels:
                      app: reimagined-spork
                  template:
                    metadata:
                      labels:
                        app: reimagined-spork
                    spec:
                      containers:
                      - name: movie-service
                        image: ${MOVIE_IMAGE}:${BUILD_TAG}
                        ports:
                        - containerPort: 8000
                      - name: cast-service
                        image: ${CAST_IMAGE}:${BUILD_TAG}
                        ports:
                        - containerPort: 8000
                      - name: nginx
                        image: ${NGINX_IMAGE}:${BUILD_TAG}
                        ports:
                        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: reimagined-spork-svc
  namespace: dev
spec:
  selector:
    app: reimagined-spork
  ports:
  - port: 80
    targetPort: 80
EOF
                        
                        kubectl rollout status deployment/reimagined-spork -n dev --timeout=300s
                        echo "✅ Déploiement DEV terminé"
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
                script {
                    timeout(time: 5, unit: 'MINUTES') {
                        input message: '🚀 Déployer en PRODUCTION ?', 
                              ok: 'DÉPLOYER',
                              parameters: [
                                  choice(name: 'DEPLOY_PROD', choices: ['Non', 'Oui'], description: 'Confirmer ?')
                              ]
                    }
                }
            }
        }
        
        stage('🏭 Deploy PROD') {
            when { 
                allOf {
                    anyOf { branch 'main'; branch 'master' }
                    expression { params.DEPLOY_PROD == 'Oui' }
                }
            }
            steps {
                echo "🏭 Déploiement PRODUCTION..."
                script {
                    sh '''
                        kubectl create namespace prod --dry-run=client -o yaml | kubectl apply -f -
                        
                        cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: reimagined-spork
  namespace: prod
spec:
  replicas: 3
  selector:
                    matchLabels:
                      app: reimagined-spork
                  template:
                    metadata:
                      labels:
                        app: reimagined-spork
                    spec:
                      containers:
                      - name: movie-service
                        image: ${MOVIE_IMAGE}:${BUILD_TAG}
                        ports:
                        - containerPort: 8000
                        resources:
                          limits:
                            memory: "512Mi"
                            cpu: "500m"
                      - name: cast-service
                        image: ${CAST_IMAGE}:${BUILD_TAG}
                        ports:
                        - containerPort: 8000
                        resources:
                          limits:
                            memory: "512Mi"
                            cpu: "500m"
                      - name: nginx
                        image: ${NGINX_IMAGE}:${BUILD_TAG}
                        ports:
                        - containerPort: 80
                        resources:
                          limits:
                            memory: "256Mi"
                            cpu: "250m"
---
apiVersion: v1
kind: Service
metadata:
  name: reimagined-spork-svc
  namespace: prod
spec:
  selector:
    app: reimagined-spork
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
EOF
                        
                        kubectl rollout status deployment/reimagined-spork -n prod --timeout=600s
                        echo "🎉 Déploiement PROD terminé !"
                    '''
                }
            }
        }
    }
    
    post {
        always {
            sh 'podman image prune -f || true'
        }
        
        success {
            echo """
            ✅ Pipeline réussi !
            📦 Images: ${REGISTRY}/${USERNAME}/
            🏷️ Tag: ${BUILD_TAG}
            """
        }
        
        failure {
            echo "❌ Pipeline échoué ! Vérifiez les logs."
        }
    }
}
