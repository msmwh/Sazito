#!/bin/bash

# Variables
SERVICE_ACCOUNT_NAME="sajjad"
NAMESPACE="default"
NEW_CONTEXT="spinnaker"
KUBECONFIG_FILE="kubeconfig-sa"

# Create the service account (if it doesn't exist)
kubectl get serviceaccount ${SERVICE_ACCOUNT_NAME} --namespace ${NAMESPACE} &>/dev/null
if [ $? -ne 0 ]; then
  echo "Creating service account '${SERVICE_ACCOUNT_NAME}' in namespace '${NAMESPACE}'..."
  kubectl create serviceaccount ${SERVICE_ACCOUNT_NAME} --namespace ${NAMESPACE}
else
  echo "Service account '${SERVICE_ACCOUNT_NAME}' already exists in namespace '${NAMESPACE}'."
fi

# Create a secret for the service account (if it doesn't exist)
SECRET_NAME="${SERVICE_ACCOUNT_NAME}-token"
kubectl get secret ${SECRET_NAME} --namespace ${NAMESPACE} &>/dev/null
if [ $? -ne 0 ]; then
  echo "Creating secret '${SECRET_NAME}' for service account '${SERVICE_ACCOUNT_NAME}'..."
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: ${NAMESPACE}
  annotations:
    kubernetes.io/service-account.name: ${SERVICE_ACCOUNT_NAME}
type: kubernetes.io/service-account-token
EOF
  # Wait for the secret to be populated
  sleep 10
else
  echo "Secret '${SECRET_NAME}' already exists in namespace '${NAMESPACE}'."
fi

# Retrieve the token from the secret
TOKEN=$(kubectl get secret ${SECRET_NAME} --namespace ${NAMESPACE} -o jsonpath='{.data.token}' | base64 --decode)
if [ -z "$TOKEN" ]; then
  echo "Failed to retrieve token from secret '${SECRET_NAME}'."
  exit 1
fi

# Retrieve the current cluster information
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
CLUSTER_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CLUSTER_CA=$(kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')  # << fixed here

# Create the kubeconfig file
cat <<EOF > ${KUBECONFIG_FILE}
apiVersion: v1
kind: Config
clusters:
- name: ${CLUSTER_NAME}
  cluster:
    server: ${CLUSTER_SERVER}
    certificate-authority-data: ${CLUSTER_CA}
contexts:
- name: ${NEW_CONTEXT}
  context:
    cluster: ${CLUSTER_NAME}
    namespace: ${NAMESPACE}
    user: ${SERVICE_ACCOUNT_NAME}
current-context: ${NEW_CONTEXT}
users:
- name: ${SERVICE_ACCOUNT_NAME}
  user:
    token: ${TOKEN}
EOF

echo "Kubeconfig file '${KUBECONFIG_FILE}' created successfully."

