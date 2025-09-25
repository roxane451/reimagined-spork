cat <<EOF | kind create cluster --name jenkins-cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30000
        hostPort: 30000
EOF
kind --loglevel debug get clusters
KUBECONFIG="$(kind get kubeconfig-path --name="jenkins-cluster")" kubectl get nodes

kind get clusters
kubectl cluster-info --context kind-jenkins-cluster
kubectl get nodes --context kind-jenkins-cluster
