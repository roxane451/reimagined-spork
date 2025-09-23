# create-namespaces.sh
#!/bin/bash

# Création des namespaces
kubectl create namespace dev
kubectl create namespace qa
kubectl create namespace staging
kubectl create namespace prod

# Vérification
kubectl get namespaces

for ns in "${NAMESPACES[@]}"; do
    echo "Création du namespace: $ns"
    kubectl create namespace $ns --dry-run=client -o yaml | kubectl apply -f -
    kubectl label namespace $ns environment=$ns --overwrite
    
    # Créer le secret pour GitHub Container Registry dans chaque namespace
    kubectl create secret docker-registry github-registry-secret \
        --docker-server=$GITHUB_REGISTRY \
        --docker-username=$GITHUB_USERNAME \
        --docker-password=$GITHUB_TOKEN \
        --namespace=$ns \
        --dry-run=client -o yaml | kubectl apply -f -
done

echo "Namespaces créés avec les secrets de registry"
kubectl get namespaces --show-labels | grep environment