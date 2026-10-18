using './main.bicep'

param targetSubscriptionId = 'f3e2a318-c7da-4fa4-934b-e0ff5bb8f8cf'
param targetEnv = 'tst'
param vmName = 'NetWatcherMon-${targetEnv}'

param resourceTags = {
  Project: 'NetWatcherMon'
  TargetEnv: toUpper(targetEnv)
  DisableAlerts: 'true'
  MonitorDisable: 'true'
  EnableTelemetry: 'false'
}

param vnetResourceGroup = 'rg-PiotrMajkowski'
param vnetName = 'vnet-prod-01'
param subnetName = 'Subnet-Backend'

param adminUsername = 'prodInnoAdmin'
param adminPassword = az.getSecret('f3e2a318-c7da-4fa4-934b-e0ff5bb8f8cf', 'rg-PiotrMajkowski', 'kv2-prod-uc64gpqfquene', 'vm-admin-password')
