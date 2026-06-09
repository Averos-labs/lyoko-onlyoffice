# Lyoko OnlyOffice Document Server

Production-ready OnlyOffice Document Server deployment for AKS with autoscaling.

## Architecture

```
AKS Cluster (lyoko-aks)
├── System Pool (D2s_v3) - orchestrator, redis
├── Sandbox Pool (D4s_v3, 1-10) - sandbox workers
└── OnlyOffice Pool (D4s_v3) - document server ← NEW
    └── Single replica (scaled vertically; see "Scaling" below)
```

> **Scaling note:** The `onlyoffice/documentserver` image is a single-instance
> product (it bundles its own PostgreSQL/RabbitMQ/Redis and keeps co-editing
> state in-pod). It runs as a **single replica** and is scaled **vertically**.
> Horizontal autoscaling is intentionally disabled — running multiple replicas
> of this image corrupts co-editing sessions and deadlocks the ReadWriteOnce
> PVCs. To serve many concurrent editors via horizontal scaling you must deploy
> the OnlyOffice **HA topology** (external shared PostgreSQL + RabbitMQ + Redis,
> multiple stateless DS pods, and a load balancer with session affinity).

## Deployment Options

### Option 1: AKS (Production) - Recommended

Uses the existing AKS cluster with a dedicated node pool.

#### Prerequisites

- Azure CLI with `az aks` access
- kubectl configured for `lyoko-aks`
- GitHub Actions secrets configured

#### Quick Deploy

```bash
# 1. Set up dedicated node pool (one-time)
chmod +x k8s/setup-nodepool.sh
./k8s/setup-nodepool.sh

# 2. Generate JWT secret
export ONLYOFFICE_JWT_SECRET=$(openssl rand -hex 32)

# 3. Deploy
chmod +x k8s/deploy.sh
./k8s/deploy.sh
```

#### CI/CD Deployment

Push to `main` branch triggers automatic deployment via GitHub Actions.

Required GitHub Secrets:
- `AZURE_CREDENTIALS` - Service principal JSON
- `ONLYOFFICE_JWT_SECRET` - JWT authentication secret

### Option 2: Azure Container Apps (Legacy)

Using Azure Developer CLI:

```bash
azd auth login
cp .env.example .env
azd up
```

### Option 3: Local Development

```bash
docker-compose up -d
```

Access at: http://localhost:8080

## Kubernetes Manifests

| File | Purpose |
|------|---------|
| `00-namespace.yaml` | Namespace, ResourceQuota, LimitRange |
| `01-secrets.yaml` | JWT secret (template) |
| `02-configmap.yaml` | Configuration |
| `03-pvc.yaml` | Persistent storage (50GB data, 20GB cache) |
| `04-deployment.yaml` | OnlyOffice deployment + PDB |
| `05-service.yaml` | ClusterIP + LoadBalancer services |
| `06-hpa.yaml` | (Disabled) Notes on why autoscaling is not used |
| `07-ingress.yaml` | Ingress (optional) |

## Autoscaling Configuration

### Pod Scaling (Vertical only)
- **Replicas**: fixed at 1 (this image is single-instance — see Scaling note above)
- **HPA**: intentionally disabled (`06-hpa.yaml` is documentation-only)
- **Scale up**: increase the CPU/memory limits in `04-deployment.yaml`
- **Rollouts**: `Recreate` strategy (required because the PVCs are ReadWriteOnce)

### Node Pool (Cluster Autoscaling)
- **Min nodes**: 1
- **Max nodes**: 5
- **VM Size**: Standard_D4s_v3 (4 vCPU, 16GB RAM)
- **Taints**: `workload=onlyoffice:NoSchedule` (dedicated)

## Resource Allocation

Per pod:
- **CPU**: 1 core request, 4 cores limit
- **Memory**: 2GB request, 8GB limit

Per PVC:
- **Data**: 50GB (documents)
- **Cache**: 20GB (conversion cache)
- **Logs**: 10GB

## Testing Autoscaling

### Manual Test

```bash
# Watch HPA and pods
watch -n5 'kubectl get hpa,pods -n lyoko-onlyoffice'

# Generate load (in another terminal)
hey -z 300s -c 20 "http://<LOADBALANCER_IP>/info/info.json"
```

### GitHub Actions Test

Run the `Test OnlyOffice Autoscaling` workflow:
1. Go to Actions → Test OnlyOffice Autoscaling
2. Set concurrent requests (default: 20)
3. Set duration (default: 300s)
4. Run workflow

## Configuration for lyoko-web

Add to `lyoko-web/server/.env`:

```env
# Get IP: kubectl get svc onlyoffice-external -n lyoko-onlyoffice
ONLYOFFICE_SERVER_URL=http://<LOADBALANCER_IP>
ONLYOFFICE_JWT_SECRET=<your-jwt-secret>
ONLYOFFICE_JWT_ENABLED=true
```

## Monitoring

### Check Status

```bash
# All resources
kubectl get all -n lyoko-onlyoffice

# HPA details
kubectl describe hpa onlyoffice-hpa -n lyoko-onlyoffice

# Pod logs
kubectl logs -f deployment/onlyoffice-documentserver -n lyoko-onlyoffice
```

### Health Check

```bash
curl http://<LOADBALANCER_IP>/healthcheck
```

## Troubleshooting

### Pod not scheduling

Check node pool and tolerations:
```bash
kubectl get nodes -l workload=onlyoffice
kubectl describe pod -n lyoko-onlyoffice
```

### PVC pending

Check storage class:
```bash
kubectl get pvc -n lyoko-onlyoffice
kubectl get sc
```

### JWT errors

Verify secret matches:
```bash
kubectl get secret onlyoffice-secrets -n lyoko-onlyoffice -o jsonpath='{.data.jwt-secret}' | base64 -d
```

## Costs

**Node Pool**: ~$140/month per node (D4s_v3)
- Min 1 node = ~$140/month
- With autoscaling max 5 = up to ~$700/month under heavy load

**Storage**: ~$10/month (80GB managed disks)

**Total baseline**: ~$150/month

## Cleanup

```bash
# Delete K8s resources
kubectl delete namespace lyoko-onlyoffice

# Delete node pool (optional)
az aks nodepool delete \
  --resource-group rg-lyoko \
  --cluster-name lyoko-aks \
  --name onlyoffice
```
