#!/bin/bash
#===============================================================================
# LYOKO ONLYOFFICE - DEPLOYMENT SCRIPT
#===============================================================================
# Deploys OnlyOffice to AKS cluster
#===============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="lyoko-onlyoffice"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=============================================================="
echo "LYOKO ONLYOFFICE - DEPLOYMENT"
echo -e "==============================================================${NC}"

# Check prerequisites
echo -e "\n${YELLOW}Checking prerequisites...${NC}"

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl not found${NC}"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi

echo -e "${GREEN}✓ kubectl connected to cluster${NC}"

# Check for JWT secret
if [ -z "$ONLYOFFICE_JWT_SECRET" ]; then
    echo -e "${YELLOW}ONLYOFFICE_JWT_SECRET not set. Generating...${NC}"
    export ONLYOFFICE_JWT_SECRET=$(openssl rand -hex 32)
    echo -e "${GREEN}✓ Generated JWT secret${NC}"
fi

# Apply manifests
echo -e "\n${YELLOW}Applying Kubernetes manifests...${NC}"

# 1. Namespace and quotas
echo "Creating namespace..."
kubectl apply -f "$SCRIPT_DIR/00-namespace.yaml"

# 2. Secrets (substitute environment variable)
echo "Creating secrets..."
cat "$SCRIPT_DIR/01-secrets.yaml" | envsubst | kubectl apply -f -

# 3. ConfigMap
echo "Creating configmap..."
kubectl apply -f "$SCRIPT_DIR/02-configmap.yaml"

# 4. PVCs
echo "Creating persistent volume claims..."
kubectl apply -f "$SCRIPT_DIR/03-pvc.yaml"

# 5. Deployment
echo "Creating deployment..."
kubectl apply -f "$SCRIPT_DIR/04-deployment.yaml"

# 6. Service
echo "Creating services..."
kubectl apply -f "$SCRIPT_DIR/05-service.yaml"

# 7. HPA
echo "Creating HPA..."
kubectl apply -f "$SCRIPT_DIR/06-hpa.yaml"

# 8. Ingress (optional)
if [ "$ENABLE_INGRESS" = "true" ]; then
    echo "Creating ingress..."
    kubectl apply -f "$SCRIPT_DIR/07-ingress.yaml"
fi

echo -e "\n${GREEN}✓ All manifests applied${NC}"

# Wait for deployment
echo -e "\n${YELLOW}Waiting for deployment to be ready...${NC}"
kubectl rollout status deployment/onlyoffice-documentserver -n "$NAMESPACE" --timeout=600s

echo -e "\n${GREEN}✓ Deployment ready${NC}"

# Get service info
echo -e "\n${YELLOW}Service Information:${NC}"
echo "=============================================================="

# Get LoadBalancer IP
echo -e "\n${YELLOW}Waiting for LoadBalancer IP...${NC}"
for i in {1..60}; do
    EXTERNAL_IP=$(kubectl get svc onlyoffice-external -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ -n "$EXTERNAL_IP" ]; then
        break
    fi
    echo -n "."
    sleep 5
done
echo ""

if [ -n "$EXTERNAL_IP" ]; then
    echo -e "${GREEN}OnlyOffice URL: http://$EXTERNAL_IP${NC}"
    echo -e "${GREEN}Health Check: http://$EXTERNAL_IP/healthcheck${NC}"
else
    echo -e "${YELLOW}LoadBalancer IP not yet assigned. Check with:${NC}"
    echo "kubectl get svc onlyoffice-external -n $NAMESPACE"
fi

# Show pod status
echo -e "\n${YELLOW}Pod Status:${NC}"
kubectl get pods -n "$NAMESPACE" -o wide

# Show HPA status
echo -e "\n${YELLOW}HPA Status:${NC}"
kubectl get hpa -n "$NAMESPACE"

# Output JWT secret for configuration
echo -e "\n${YELLOW}=============================================================="
echo "IMPORTANT: Save these values for lyoko-web configuration"
echo "==============================================================${NC}"
echo "ONLYOFFICE_JWT_SECRET=$ONLYOFFICE_JWT_SECRET"
if [ -n "$EXTERNAL_IP" ]; then
    echo "ONLYOFFICE_URL=http://$EXTERNAL_IP"
fi

echo -e "\n${GREEN}=============================================================="
echo "Deployment complete!"
echo -e "==============================================================${NC}"
