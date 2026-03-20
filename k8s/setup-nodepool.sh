#!/bin/bash
#===============================================================================
# LYOKO ONLYOFFICE - AKS NODE POOL SETUP
#===============================================================================
# Creates a dedicated node pool for OnlyOffice with autoscaling
# Run once to set up infrastructure
#===============================================================================

set -e

# Configuration
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-lyoko}"
CLUSTER_NAME="${CLUSTER_NAME:-lyoko-aks}"
NODE_POOL_NAME="onlyoffice"
VM_SIZE="${VM_SIZE:-Standard_D4s_v3}"  # 4 vCPU, 16GB RAM
MIN_NODES="${MIN_NODES:-1}"
MAX_NODES="${MAX_NODES:-5}"

echo "=============================================================="
echo "OnlyOffice Node Pool Setup"
echo "=============================================================="
echo "Resource Group: $RESOURCE_GROUP"
echo "Cluster: $CLUSTER_NAME"
echo "Node Pool: $NODE_POOL_NAME"
echo "VM Size: $VM_SIZE"
echo "Nodes: $MIN_NODES - $MAX_NODES (autoscaler)"
echo "=============================================================="

# Check if node pool already exists
if az aks nodepool show \
    --resource-group "$RESOURCE_GROUP" \
    --cluster-name "$CLUSTER_NAME" \
    --name "$NODE_POOL_NAME" \
    &>/dev/null; then
    echo "Node pool '$NODE_POOL_NAME' already exists. Updating..."
    
    az aks nodepool update \
        --resource-group "$RESOURCE_GROUP" \
        --cluster-name "$CLUSTER_NAME" \
        --name "$NODE_POOL_NAME" \
        --min-count "$MIN_NODES" \
        --max-count "$MAX_NODES" \
        --enable-cluster-autoscaler
else
    echo "Creating node pool '$NODE_POOL_NAME'..."
    
    az aks nodepool add \
        --resource-group "$RESOURCE_GROUP" \
        --cluster-name "$CLUSTER_NAME" \
        --name "$NODE_POOL_NAME" \
        --node-count "$MIN_NODES" \
        --min-count "$MIN_NODES" \
        --max-count "$MAX_NODES" \
        --enable-cluster-autoscaler \
        --node-vm-size "$VM_SIZE" \
        --labels workload=onlyoffice \
        --node-taints workload=onlyoffice:NoSchedule \
        --mode User \
        --os-type Linux \
        --os-sku AzureLinux
fi

echo ""
echo "✓ Node pool '$NODE_POOL_NAME' is ready"
echo ""

# Show node pool status
echo "Node Pool Status:"
az aks nodepool show \
    --resource-group "$RESOURCE_GROUP" \
    --cluster-name "$CLUSTER_NAME" \
    --name "$NODE_POOL_NAME" \
    --output table

echo ""
echo "=============================================================="
echo "Next steps:"
echo "1. Run: ./k8s/deploy.sh"
echo "=============================================================="
