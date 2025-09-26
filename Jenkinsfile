pipeline {
    agent {
        kubernetes {
            yaml '''
                apiVersion: v1
                kind: Pod
                metadata:
                  name: podman-agent
                spec:
                  containers:
                  - name: podman
                    image: quay.io/podman/stable:latest
                    command:
                    - cat
                    tty: true
                    securityContext:
                      privileged: true
                      runAsUser: 0
                    env:
                    - name: STORAGE_DRIVER
                      value: "vfs"
                    volumeMounts:
                    - name: podman-storage
                      mountPath: /var/lib/containers
                  - name: kubectl
                    image: bitnami/kubectl:latest
                    command:
                    - cat
                    tty: true
                  volumes:
                  - name: podman-storage
                    emptyDir:
                      sizeLimit: 5Gi
            '''
        }
    }
    
    environment {
        REGISTRY = 'c8n.io'
        REGISTRY_CREDENTIAL = 'c8n-io-cred'
        KUBECONFIG_CREDENTIAL = 'kubeconfig-cred'
    }
    
    stages {
        stage('🔍 Test Infrastructure') {
            steps {
                container('podman') {
                    sh '''
                        echo "=== Test Podman ==="
                        podman --version
                        podman info --format "{{.Host.Hostname}}"
                        
                        echo "=== Test c8n.io ==="
                        podman login --get-login c8n.io || echo "Pas encore connecté"
                    '''
                }
                container('kubectl') {
                    sh '''
                        echo "=== Test Kubernetes ==="
                        kubectl get nodes
                    '''
                }
            }
        }
        
        stage('📦 Build avec Podman') {
            steps {
                container('podman') {
                    script {
                        def testImage = "${REGISTRY}/votre-username/test:${BUILD_NUMBER}"
                        sh """
                            # Build avec Podman
                            echo 'FROM alpine:latest' > Dockerfile.test
                            echo 'RUN echo "Built with Podman in Kubernetes!"' >> Dockerfile.test
                            
                            podman build -f Dockerfile.test -t ${testImage} .
                            
                            # Tag latest
                            podman tag ${testImage} ${REGISTRY}/votre-username/test:latest
                            
                            echo "Image créée: ${testImage}"
                        """
                    }
                }
            }
        }
        
        stage('🚀 Push vers c8n.io') {
            steps {
                container('podman') {
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
        }
        
        stage('🏙️ Deploy vers Dev') {
            steps {
                container('kubectl') {
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
    }
    
    post {
        always {
            container('podman') {
                sh '''
                    podman system prune -f || true
                    rm -f Dockerfile.test || true
                '''
            }
        }
        success {
            echo '🎉 Pipeline Podman réussi !'
        }
        failure {
            echo '❌ Pipeline échoué, vérifiez les logs'
        }
    }
}
