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
        NGINX_IMAGE = "${REGISTRY}/${USERNAME}/nginx"
        
        // Images locales pour Minikube
        LOCAL_MOVIE_IMAGE = "local/movie-service"
        LOCAL_CAST_IMAGE = "local/cast-service"
        LOCAL_NGINX_IMAGE = "local/nginx"
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
                            
                            # Version locale pour Minikube
                            podman tag ${MOVIE_IMAGE}:${BUILD_TAG} ${LOCAL_MOVIE_IMAGE}:${BUILD_TAG}
                            podman tag ${MOVIE_IMAGE}:${BUILD_TAG} ${LOCAL_MOVIE_IMAGE}:latest
                            
                            echo "Movie service built"
                        fi
                        
                        # Build Cast Service  
                        if [ -d "cast-service" ] && [ -f "cast-service/Dockerfile" ]; then
                            podman build -t ${CAST_IMAGE}:${BUILD_TAG} ./cast-service/
                            podman tag ${CAST_IMAGE}:${BUILD_TAG} ${CAST_IMAGE}:latest
                            
                            # Version locale pour Minikube
                            podman tag ${CAST_IMAGE}:${BUILD_TAG} ${LOCAL_CAST_IMAGE}:${BUILD_TAG}
                            podman tag ${CAST_IMAGE}:${BUILD_TAG} ${LOCAL_CAST_IMAGE}:latest
                            
                            echo "Cast service built"
                        fi
                        
                        # Build Nginx
                        if [ -d "nginx" ] && [ -f "nginx/Dockerfile" ]; then
                            podman build -t ${NGINX_IMAGE}:${BUILD_TAG} ./nginx/
                            podman tag ${NGINX_IMAGE}:${BUILD_TAG} ${NGINX_IMAGE}:latest
                            
                            # Version locale pour Minikube
                            podman tag ${NGINX_IMAGE}:${BUILD_TAG} ${LOCAL_NGINX_IMAGE}:${BUILD_TAG}
                            podman tag ${NGINX_IMAGE}:${BUILD_TAG} ${LOCAL_NGINX_IMAGE}:latest
                            
                            echo "Nginx built"
                        elif [ -f "nginx_config.conf" ]; then
                            mkdir -p nginx
                            cp nginx_config.conf nginx/nginx.conf
                            cat > nginx/Dockerfile << EOF
FROM docker.io/library/nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF
                            podman build -t ${NGINX_IMAGE}:${BUILD_TAG} ./nginx/
                            podman tag ${NGINX_IMAGE}:${BUILD_TAG} ${NGINX_IMAGE}:latest
                            
                            # Version locale pour Minikube
                            podman tag ${NGINX_IMAGE}:${BUILD_TAG} ${LOCAL_NGINX_IMAGE}:${BUILD_TAG}
                            podman tag ${NGINX_IMAGE}:${BUILD_TAG} ${LOCAL_NGINX_IMAGE}:latest
                            
                            echo "Nginx built (using existing config)"
                        fi
                        
                        echo "Images construites:"
                        podman images | grep -E "(${USERNAME}|local/)"
                    '''
                }
            }
        }
        
        stage('Load Images to Minikube') {
            steps {
                echo "Chargement des images dans Minikube..."
                script {
                    sh '''
                        # Charger les images locales dans Minikube
                        if podman images | grep -q "${LOCAL_MOVIE_IMAGE}"; then
                            podman save ${LOCAL_MOVIE_IMAGE}:${BUILD_TAG} | minikube image load -
                            echo "Movie service image loaded to Minikube"
                        fi
                        
                        if podman images | grep -q "${LOCAL_CAST_IMAGE}"; then
                            podman save ${LOCAL_CAST_IMAGE}:${BUILD_TAG} | minikube image load -
                            echo "Cast service image loaded to Minikube"
                        fi
                        
                        if podman images | grep -q "${LOCAL_NGINX_IMAGE}"; then
                            podman save ${LOCAL_NGINX_IMAGE}:${BUILD_TAG} | minikube image load -
                            echo "Nginx image loaded to Minikube"
                        fi
                        
                        # Vérifier les images dans Minikube
                        echo "Images dans Minikube:"
                        minikube image ls | grep local/ || echo "Aucune image locale trouvée"
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
                        
                        podman logout ${REGISTRY} 2>/dev/null || true
                        
                        echo "Connexion avec adresse email..."
                        if printf '%s' "${REGISTRY_PASS}" | podman login "${REGISTRY}" -u "${REGISTRY_USER}" --password-stdin; then
                            echo "Connexion réussie"
                        else
                            echo "Échec de connexion au registry externe"
                            echo "Continuons avec les images locales seulement"
                            exit 0
                        fi
                        
                        # Push vers registry externe
                        if podman images | grep -q "${MOVIE_IMAGE}"; then
                            echo "Push movie service..."
                            podman push ${MOVIE_IMAGE}:${BUILD_TAG}
                            podman push ${MOVIE_IMAGE}:latest
                            echo "Movie service pushed"
                        fi
                        
                        if podman images | grep -q "${CAST_IMAGE}"; then
                            echo "Push cast service..."
                            podman push ${CAST_IMAGE}:${BUILD_TAG}
                            podman push ${CAST_IMAGE}:latest
                            echo "Cast service pushed"
                        fi
                        
                        if podman images | grep -q "${NGINX_IMAGE}"; then
                            echo "Push nginx..."
                            podman push ${NGINX_IMAGE}:${BUILD_TAG}
                            podman push ${NGINX_IMAGE}:latest
                            echo "Nginx pushed"
                        fi
                        
                        echo "Images publiées sur registry externe"
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
                echo "Déploiement automatique en DEV..."
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
        image: ${LOCAL_MOVIE_IMAGE}:${BUILD_TAG}
        imagePullPolicy: Never
        ports:
        - containerPort: 8000
      - name: cast-service
        image: ${LOCAL_CAST_IMAGE}:${BUILD_TAG}
        imagePullPolicy: Never
        ports:
        - containerPort: 8000
      - name: nginx
        image: ${LOCAL_NGINX_IMAGE}:${BUILD_TAG}
        imagePullPolicy: Never
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
  type: NodePort
EOF
                        
                        kubectl rollout status deployment/reimagined-spork -n dev --timeout=300s
                        echo "Déploiement DEV terminé"
                        
                        # Afficher l'URL d'accès
                        echo "Accès à l'application:"
                        minikube service reimagined-spork-svc -n dev --url || echo "Service non disponible"
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
                    timeout(time: 5, unit: 'MINUTES') {
                        input message: 'Déployer en PRODUCTION ?', 
                              ok: 'DÉPLOYER',
                              parameters: [
                                  choice(name: 'DEPLOY_PROD', choices: ['Non', 'Oui'], description: 'Confirmer ?')
                              ]
                    }
                }
            }
        }
        
        stage('Deploy PROD') {
            when { 
                allOf {
                    anyOf { branch 'main'; branch 'master' }
                    expression { params.DEPLOY_PROD == 'Oui' }
                }
            }
            steps {
                echo "Déploiement PRODUCTION..."
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
        image: ${LOCAL_MOVIE_IMAGE}:${BUILD_TAG}
        imagePullPolicy: Never
        ports:
        - containerPort: 8000
        resources:
          limits:
            memory: "512Mi"
            cpu: "500m"
      - name: cast-service
        image: ${LOCAL_CAST_IMAGE}:${BUILD_TAG}
        imagePullPolicy: Never
        ports:
        - containerPort: 8000
        resources:
          limits:
            memory: "512Mi"
            cpu: "500m"
      - name: nginx
        image: ${LOCAL_NGINX_IMAGE}:${BUILD_TAG}
        imagePullPolicy: Never
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
  type: NodePort
EOF
                        
                        kubectl rollout status deployment/reimagined-spork -n prod --timeout=600s
                        echo "Déploiement PROD terminé !"
                        
                        # Afficher l'URL d'accès
                        echo "Accès à l'application PROD:"
                        minikube service reimagined-spork-svc -n prod --url || echo "Service non disponible"
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
            Pipeline réussi !
            Images locales: local/*:${BUILD_TAG}
            Registry externe: ${REGISTRY}/${USERNAME}/
            """
        }
        
        failure {
            echo "Pipeline échoué ! Vérifiez les logs."
        }
    }
}