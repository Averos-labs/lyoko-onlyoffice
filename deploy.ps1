# Quick deployment script for OnlyOffice to Azure
# Alternative to using azd if you prefer manual control

param(
    [string]$ResourceGroup = "rg-lyoko-onlyoffice",
    [string]$Location = "eastus",
    [string]$EnvironmentName = "lyoko-onlyoffice-env",
    [string]$AppName = "lyoko-onlyoffice",
    [string]$StorageAccountName = "stlyokoonlyoffice$(Get-Random -Minimum 1000 -Maximum 9999)"
)

Write-Host "🚀 Deploying OnlyOffice Document Server to Azure..." -ForegroundColor Cyan

# Create resource group
Write-Host "`n📦 Creating resource group..." -ForegroundColor Yellow
az group create --name $ResourceGroup --location $Location

# Create storage account
Write-Host "`n💾 Creating storage account..." -ForegroundColor Yellow
az storage account create `
    --name $StorageAccountName `
    --resource-group $ResourceGroup `
    --location $Location `
    --sku Standard_LRS

# Get storage key
$StorageKey = (az storage account keys list --resource-group $ResourceGroup --account-name $StorageAccountName --query "[0].value" -o tsv)

# Create file shares
Write-Host "`n📁 Creating file shares..." -ForegroundColor Yellow
az storage share create --name onlyoffice-data --account-name $StorageAccountName --account-key $StorageKey --quota 100
az storage share create --name onlyoffice-cache --account-name $StorageAccountName --account-key $StorageKey --quota 50
az storage share create --name onlyoffice-logs --account-name $StorageAccountName --account-key $StorageKey --quota 10

# Create Container Apps environment
Write-Host "`n🏗️  Creating Container Apps environment..." -ForegroundColor Yellow
az containerapp env create `
    --name $EnvironmentName `
    --resource-group $ResourceGroup `
    --location $Location

# Add storage mounts to environment
Write-Host "`n🔗 Configuring storage mounts..." -ForegroundColor Yellow
az containerapp env storage set `
    --name $EnvironmentName `
    --resource-group $ResourceGroup `
    --storage-name onlyoffice-data `
    --azure-file-account-name $StorageAccountName `
    --azure-file-account-key $StorageKey `
    --azure-file-share-name onlyoffice-data `
    --access-mode ReadWrite

az containerapp env storage set `
    --name $EnvironmentName `
    --resource-group $ResourceGroup `
    --storage-name onlyoffice-cache `
    --azure-file-account-name $StorageAccountName `
    --azure-file-account-key $StorageKey `
    --azure-file-share-name onlyoffice-cache `
    --access-mode ReadWrite

az containerapp env storage set `
    --name $EnvironmentName `
    --resource-group $ResourceGroup `
    --storage-name onlyoffice-logs `
    --azure-file-account-name $StorageAccountName `
    --azure-file-account-key $StorageKey `
    --azure-file-share-name onlyoffice-logs `
    --access-mode ReadWrite

# Generate JWT secret
$JwtSecret = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((New-Guid).Guid))

# Create Container App with OnlyOffice
Write-Host "`n🐳 Creating OnlyOffice Container App..." -ForegroundColor Yellow
az containerapp create `
    --name $AppName `
    --resource-group $ResourceGroup `
    --environment $EnvironmentName `
    --image onlyoffice/documentserver:latest `
    --target-port 80 `
    --ingress external `
    --cpu 2.0 `
    --memory 4.0Gi `
    --min-replicas 1 `
    --max-replicas 5 `
    --secrets jwt-secret=$JwtSecret `
    --env-vars `
        JWT_ENABLED=true `
        JWT_SECRET=secretref:jwt-secret `
        JWT_HEADER=Authorization `
        JWT_IN_BODY=true `
        WOPI_ENABLED=false

# Add volume mounts (requires updating the app)
Write-Host "`n📌 Configuring volume mounts..." -ForegroundColor Yellow
az containerapp update `
    --name $AppName `
    --resource-group $ResourceGroup `
    --set-env-vars `
        JWT_ENABLED=true `
        JWT_SECRET=secretref:jwt-secret `
        JWT_HEADER=Authorization `
        JWT_IN_BODY=true `
    --volume-mount onlyoffice-data:/var/www/onlyoffice/Data `
    --volume-mount onlyoffice-cache:/var/lib/onlyoffice `
    --volume-mount onlyoffice-logs:/var/log/onlyoffice

# Get the app URL
$AppUrl = (az containerapp show --name $AppName --resource-group $ResourceGroup --query "properties.configuration.ingress.fqdn" -o tsv)

Write-Host "`n✅ Deployment complete!" -ForegroundColor Green
Write-Host "`n📋 Configuration:" -ForegroundColor Cyan
Write-Host "   ONLYOFFICE_SERVER_URL: https://$AppUrl" -ForegroundColor White
Write-Host "   ONLYOFFICE_JWT_SECRET: $JwtSecret" -ForegroundColor White
Write-Host "   ONLYOFFICE_JWT_ENABLED: true" -ForegroundColor White
Write-Host "`n💡 Add these to your lyoko-web/server/.env file" -ForegroundColor Yellow
Write-Host "`n🔍 Test health: https://$AppUrl/healthcheck" -ForegroundColor Yellow

# Save configuration to file
$ConfigFile = "onlyoffice-config.txt"
@"
ONLYOFFICE_SERVER_URL=https://$AppUrl
ONLYOFFICE_JWT_SECRET=$JwtSecret
ONLYOFFICE_JWT_ENABLED=true
"@ | Out-File -FilePath $ConfigFile

Write-Host "`n💾 Configuration saved to: $ConfigFile" -ForegroundColor Green
