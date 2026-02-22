# Lyoko OnlyOffice Document Server

This project deploys OnlyOffice Document Server to Azure Container Apps using Azure Developer CLI (azd).

## Prerequisites

- Azure Developer CLI ([Install azd](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd))
- Azure subscription
- Azure CLI (for authentication)

## Quick Start

### 1. Login to Azure

```powershell
azd auth login
```

### 2. Initialize Environment

```powershell
# Copy environment template
cp .env.example .env

# Edit .env and set:
# - AZURE_ENV_NAME (e.g., lyoko-onlyoffice-dev)
# - AZURE_LOCATION (e.g., eastus)
# - AZURE_SUBSCRIPTION_ID (optional)
```

### 3. Deploy to Azure

```powershell
azd up
```

This command will:
- Provision all Azure resources (Container App, Storage, etc.)
- Deploy OnlyOffice Document Server
- Output the OnlyOffice URL and JWT secret

### 4. Get Configuration

After deployment, get the OnlyOffice URL:

```powershell
azd env get-values
```

Look for:
- `ONLYOFFICE_URL` - The public URL of your OnlyOffice server
- `ONLYOFFICE_JWT_ENABLED` - Should be "true"

The JWT secret is stored securely in Azure. To retrieve it:

```powershell
az containerapp show --name <container-app-name> --resource-group <resource-group> --query "properties.template.containers[0].env[?name=='JWT_SECRET'].secretRef" -o tsv
```

## What Gets Deployed

- **Container App Environment** - Hosting environment for containers
- **OnlyOffice Container App** - Document Server with 2 CPU / 4GB RAM
  - Auto-scales from 1 to 5 replicas based on load
  - JWT authentication enabled for security
- **Storage Account** - Persistent storage for:
  - Document data
  - Cache files
  - Logs
- **Log Analytics** - For monitoring and diagnostics

## Configuration

### Environment Variables

OnlyOffice is configured with:
- `JWT_ENABLED=true` - JWT authentication enabled
- `JWT_SECRET` - Auto-generated secret (stored in Azure secrets)
- `JWT_HEADER=Authorization` - JWT in Authorization header
- `JWT_IN_BODY=true` - JWT also in request body

### Resource Specifications

- **CPU**: 2 cores
- **Memory**: 4 GB
- **Storage**: 
  - 100 GB for data
  - 50 GB for cache
  - 10 GB for logs

### Scaling

Auto-scales based on:
- Concurrent requests (max 10 per instance)
- Min replicas: 1
- Max replicas: 5

## Using with Lyoko Web

### Local Development

In your `lyoko-web/server/.env`:

```env
ONLYOFFICE_SERVER_URL=https://<your-onlyoffice-url>
ONLYOFFICE_JWT_SECRET=<your-jwt-secret>
ONLYOFFICE_JWT_ENABLED=true
```

### Testing

1. Start your local web server
2. Upload an Excel file
3. Open it - should load OnlyOffice editor from Azure
4. Make edits - should save back to your local server

## Monitoring

### View Logs

```powershell
# Stream live logs
az containerapp logs tail --name <container-app-name> --resource-group <resource-group> --follow

# View in Azure Portal
azd show --output json | jq -r '.resourceGroupName' | xargs -I {} az monitor log-analytics workspace list --resource-group {} --query "[0].id" -o tsv
```

### Health Check

```powershell
curl https://<your-onlyoffice-url>/healthcheck
```

## Costs

Estimated monthly cost (assuming low usage):
- Container App: ~$30-50/month (with auto-scaling)
- Storage Account: ~$5-10/month
- Log Analytics: ~$5/month

**Total**: ~$40-65/month

## Cleanup

To delete all resources:

```powershell
azd down
```

## Troubleshooting

### Container won't start

Check logs:
```powershell
az containerapp logs tail --name <name> --resource-group <rg> --follow
```

### Storage mount issues

Verify storage account and file shares exist:
```powershell
az storage share list --account-name <storage-account>
```

### JWT errors

Ensure JWT secret matches between OnlyOffice and your web server.

## Next Steps

1. Deploy OnlyOffice: `azd up`
2. Configure `lyoko-web` to use it
3. Test opening/editing Excel files
4. Proceed with migration plan (Phase 3: Backend Integration)
