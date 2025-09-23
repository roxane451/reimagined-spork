pipeline {
    agent any
    
    environment {
        // Configuration c8n.io Container Registry
        REGISTRY = 'c8n.io'
        REGISTRY_CREDENTIALS = credentials('c8n-registry')
        USERNAME = 'roxane451'
        
        // Configuration des services
        MOVIE_SERVICE_IMAGE = "${REGISTRY}/${USERNAME}/movie-service"
        CAST_SERVICE_IMAGE = "${REGISTRY}/${USERNAME}/cast-service"
        NGINX_IMAGE = "${REGISTRY}/${USERNAME}/nginx"
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 45, unit: 'MINUTES')
        skipDefaultCheckout(true)
        timestamps()
    }
    
    stages {
        stage('🔄 Checkout & Setup') {
            steps {
                script {
                    // Définir les variables dynamiques après checkout
                    env.BUILD_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT?.take(7) ?: 'unknown'}"
                    env.BRANCH_NAME = "${env.GIT_BRANCH?.replace('origin/', '') ?: 'main'}"
                    
                    echo "🚀 Pipeline reimagined-spork - Branche: ${env.BRANCH_NAME}"
                    checkout scm
                    
                    // Redéfinir BUILD_TAG avec le vrai commit après checkout
                    env.BUILD_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT?.take(7) ?: 'unknown'}"
                    echo "🏷️ Build Tag: ${env.BUILD_TAG}"
                    
                    sh '''
                        echo "🔧 Vérification des outils..."
                        
                        # Détecter Docker ou Podman
                        if command -v docker >/dev/null 2>&1; then
                            echo "✅ Docker trouvé"
                            docker --version
                            export CONTAINER_TOOL=docker
                        elif command -v podman >/dev/null 2>&1; then
                            echo "✅ Podman trouvé"
                            podman --version
                            export CONTAINER_TOOL=podman
                        else
                            echo "❌ Ni Docker ni Podman trouvé!"
                            echo "Installez Docker ou Podman sur cet agent Jenkins"
                            exit 1
                        fi
                        
                        echo "CONTAINER_TOOL=$CONTAINER_TOOL" > /tmp/container_tool.env
                        
                        # Vérifier kubectl et helm (optionnels)
                        if command -v kubectl >/dev/null 2>&1; then
                            echo "✅ kubectl trouvé"
                            kubectl version --client --short
                        else
                            echo "⚠️ kubectl non trouvé (déploiements ignorés)"
                        fi
                        
                        if command -v helm >/dev/null 2>&1; then
                            echo "✅ helm trouvé"  
                            helm version --short
                        else
                            echo "⚠️ helm non trouvé (déploiements basiques)"
                        fi
                        
                        echo "📂 Structure du projet:"
                        ls -la
                    '''
                    
                    // Lire l'outil de conteneur
                    def toolEnv = readFile('/tmp/container_tool.env').trim()
                    env.CONTAINER_TOOL = toolEnv.split('=')[1]
                    echo "🐳 Outil sélectionné: ${env.CONTAINER_TOOL}"
                }
            }
        }
        
        stage('🔨 Build Services') {
            parallel {
                stage('Build Movie Service') {
                    steps {
                        script {
                            echo "🔨 Construction du Movie Service avec ${env.CONTAINER_TOOL}..."
                            dir('movie-service') {
                                sh """
                                    ${env.CONTAINER_TOOL} build \
                                        --tag ${MOVIE_SERVICE_IMAGE}:${env.BUILD_TAG} \
                                        --tag ${MOVIE_SERVICE_IMAGE}:latest \
                                        --tag ${MOVIE_SERVICE_IMAGE}:${env.BRANCH_NAME} \
                                        --label "service=movie-service" \
                                        --label "build.number=${BUILD_NUMBER}" \
                                        --label "git.commit=${GIT_COMMIT}" \
                                        .
                                """
                            }
                        }
                    }
                }
                
                stage('Build Cast Service') {
                    steps {
                        script {
                            echo "🔨 Construction du Cast Service avec ${env.CONTAINER_TOOL}..."
                            dir('cast-service') {
                                sh """
                                    ${env.CONTAINER_TOOL} build \
                                        --tag ${CAST_SERVICE_IMAGE}:${env.BUILD_TAG} \
                                        --tag ${CAST_SERVICE_IMAGE}:latest \
                                        --tag ${CAST_SERVICE_IMAGE}:${env.BRANCH_NAME} \
                                        --label "service=cast-service" \
                                        --label "build.number=${BUILD_NUMBER}" \
                                        --label "git.commit=${GIT_COMMIT}" \
                                        .
                                """
                            }
                        }
                    }
                }
                
                stage('Build Nginx Proxy') {
                    steps {
                        script {
                            echo "🔨 Construction du Nginx Proxy avec ${env.CONTAINER_TOOL}..."
                            sh """
                                # Créer un Dockerfile pour nginx
                                if [ ! -f nginx_config.conf ]; then
                                    echo "⚠️ nginx_config.conf non trouvé, création d'un fichier basique"
                                    cat > nginx_config.conf << 'EOF'
upstream movie-service {
    server movie-service:8000;
}

upstream cast-service {
    server cast-service:8000;
}

server {
    listen 80;
    
    location /api/v1/movies {
        proxy_pass http://movie-service;
        proxy_set_header Host \\$host;
        proxy_set_header X-Real-IP \\$remote_addr;
    }
    
    location /api/v1/casts {
        proxy_pass http://cast-service;
        proxy_set_header Host \\$host;
        proxy_set_header X-Real-IP \\$remote_addr;
    }
    
    location / {
        return 200 'Reimagined Spork API Gateway';
        add_header Content-Type text/plain;
    }
}
EOF
                                fi
                                
                                cat > Dockerfile.nginx << 'EOF'
FROM nginx:1.21-alpine
COPY nginx_config.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF
                                
                                ${env.CONTAINER_TOOL} build \
                                    -f Dockerfile.nginx \
                                    --tag ${NGINX_IMAGE}:${env.BUILD_TAG} \
                                    --tag ${NGINX_IMAGE}:latest \
                                    --tag ${NGINX_IMAGE}:${env.BRANCH_NAME} \
                                    --label "service=nginx-proxy" \
                                    --label "build.number=${BUILD_NUMBER}" \
                                    .
                            """
                        }
                    }
                }
            }
        }
        
        stage('🧪 Tests de base') {
            steps {
                script {
                    echo "🧪 Tests basiques des images..."
                    sh """
                        echo "🔍 Vérification des images construites:"
                        ${env.CONTAINER_TOOL} images | grep -E "(movie-service|cast-service|nginx)" || echo "Images non trouvées"
                        
                        echo "📏 Taille des images:"
                        ${env.CONTAINER_TOOL} inspect ${MOVIE_SERVICE_IMAGE}:${env.BUILD_TAG} --format='{{.Size}}' 2>/dev/null || echo "Image movie-service non trouvée"
                        ${env.CONTAINER_TOOL} inspect ${CAST_SERVICE_IMAGE}:${env.BUILD_TAG} --format='{{.Size}}' 2>/dev/null || echo "Image cast-service non trouvée"  
                        ${env.CONTAINER_TOOL} inspect ${NGINX_IMAGE}:${env.BUILD_TAG} --format='{{.Size}}' 2>/dev/null || echo "Image nginx non trouvée"
                    """
                }
            }
        }
        
        stage('📤 Push to c8n.io Registry') {
            steps {
                script {
                    echo "📤 Push vers c8n.io avec ${env.CONTAINER_TOOL}..."
                    sh """
                        # Login vers c8n.io
                        echo \$REGISTRY_CREDENTIALS_PSW | ${env.CONTAINER_TOOL} login ${REGISTRY} -u \$REGISTRY_CREDENTIALS_USR --password-stdin
                        
                        # Push Movie Service
                        ${env.CONTAINER_TOOL} push ${MOVIE_SERVICE_IMAGE}:${env.BUILD_TAG}
                        ${env.CONTAINER_TOOL} push ${MOVIE_SERVICE_IMAGE}:latest
                        ${env.CONTAINER_TOOL} push ${MOVIE_SERVICE_IMAGE}:${env.BRANCH_NAME}
                        
                        # Push Cast Service  
                        ${env.CONTAINER_TOOL} push ${CAST_SERVICE_IMAGE}:${env.BUILD_TAG}
                        ${env.CONTAINER_TOOL} push ${CAST_SERVICE_IMAGE}:latest
                        ${env.CONTAINER_TOOL} push ${CAST_SERVICE_IMAGE}:${env.BRANCH_NAME}
                        
                        # Push Nginx
                        ${env.CONTAINER_TOOL} push ${NGINX_IMAGE}:${env.BUILD_TAG}
                        ${env.CONTAINER_TOOL} push ${NGINX_IMAGE}:latest
                        ${env.CONTAINER_TOOL} push ${NGINX_IMAGE}:${env.BRANCH_NAME}
                        
                        echo "✅ Toutes les images pushées avec succès"
                        echo "📦 Registry: ${REGISTRY}/${USERNAME}/"
                    """
                }
            }
        }
        
        stage('🧹 Cleanup') {
            steps {
                script {
                    echo "🧹 Nettoyage avec ${env.CONTAINER_TOOL}..."
                    sh """
                        # Logout du registry
                        ${env.CONTAINER_TOOL} logout ${REGISTRY} || true
                        
                        # Nettoyage des images locales (garder les récentes)
                        ${env.CONTAINER_TOOL} image prune -f || true
                        
                        # Si c'est Docker, nettoyer aussi les containers
                        if [ "${env.CONTAINER_TOOL}" = "docker" ]; then
                            docker container prune -f || true
                        elif [ "${env.CONTAINER_TOOL}" = "podman" ]; then
                            podman container prune -f || true
                        fi
                        
                        echo "📦 Images restantes:"
                        ${env.CONTAINER_TOOL} images | head -10 || true
                    """
                }
            }
        }
    }
    
    post {
        success {
            script {
                echo """
                ✅ Pipeline reimagined-spork réussi !
                
                📦 Images pushées vers c8n.io:
                • Movie Service: ${REGISTRY}/${USERNAME}/movie-service:${env.BUILD_TAG}
                • Cast Service: ${REGISTRY}/${USERNAME}/cast-service:${env.BUILD_TAG}  
                • Nginx: ${REGISTRY}/${USERNAME}/nginx:${env.BUILD_TAG}
                
                🐳 Outil utilisé: ${env.CONTAINER_TOOL}
                🌐 Registry: ${REGISTRY}/${USERNAME}/
                ⏱️ Durée: ${currentBuild.durationString}
                """
            }
        }
        
        failure {
            echo """
            ❌ Pipeline reimagined-spork échoué !
            
            🔍 Vérifiez les logs ci-dessus
            📞 Services: movie-service, cast-service, nginx
            💡 Vérifiez: Docker/Podman installé, credentials c8n-registry configuré
            """
        }
    }
}
