pipeline {
    agent any
    
    environment {
        REGISTRY = 'c8n.io'
        REGISTRY_CREDENTIAL = 'c8n-io-cred'
        KUBECONFIG_CREDENTIAL = 'kubeconfig-cred'
        DOCKER_HOST = 'unix:///tmp/podman.sock'
    }
    
    stages {
        stage('🔍 Test Infrastructure') {
            steps {
                sh '''
                    echo "=== Test Podman ==="
                    podman --version
                    podman info --format "{{.Host.Hostname}}"
                    
                    echo "=== Test Kubernetes ==="
                    kubectl get nodes
                    
                    echo "=== Test c8n.io ==="
                    podman login --get-login c8n.io || echo "Pas encore connecté"
                '''
            }
        }
        
        stage('📦 Build avec Podman') {
            steps {
                script {
                    def testImage = "${REGISTRY}/votre-username/test:${BUILD_NUMBER}"
                    sh """
                        # Build avec Podman
                        echo 'FROM alpine:latest' > Dockerfile.test
                        echo 'RUN echo "Built with Podman!"' >> Dockerfile.test
                        
                        podman build -f Dockerfile.test -t ${testImage} .
                        
                        # Tag latest
                        podman tag ${testImage} ${REGISTRY}/votre-username/test:latest
                        
                        echo "Image créée: ${testImage}"
                    """
                }
            }
        }
        
        stage('🚀 Push vers c8n.io') {
            steps {
                withCredentials([usernamePassword(credentialsId: REGISTRY_CREDENTIAL,
                                                passwordVariable: 'PASSWORD',
                                                usernameVariable: 'USERNAME')]) {
                    sh '''
                        echo $PASSWORD | podman login --username $USERNAME --password-stdin c8n.io
                        podman push c8n.io/votre-username/test:${BUILD_NUMBER}
                        podman push c8n.io/votre-username/test:latest
                        echo "✅ Images poussées vers c8n.io"
                    '''
                }
            }
        }
        
        stage('🏙️ Deploy vers Dev') {
            steps {
                withKubeConfig([credentialsId: KUBECONFIG_CREDENTIAL]) {
                    sh '''
                        # Test deployment simple
                        kubectl create deployment test-podman \
                            --image=c8n.io/votre-username/test:${BUILD_NUMBER} \
                            --namespace=dev --dry-run=client -o yaml | \
                        kubectl apply -f -
                        
                        echo "✅ Deployment créé dans namespace dev"
                    '''
                }
            }
        }
    }
    
    post {
        always {
            sh '''
                # Nettoyage Podman
                podman system prune -f
                rm -f Dockerfile.test
            '''
        }
        success {
            echo '🎉 Pipeline Podman réussi !'
        }
        failure {
            echo '❌ Pipeline échoué, vérifiez les logs'
        }
    }
}