// Virtual Network and Subnet configuration
param location string = resourceGroup().location

// Resource tags for the backend VM and related resources
param resourceTags object

param targetSubscriptionId string // ID of the target subscription
param targetEnv string // Environment: 'uat', 'dev', or 'prd'
param vmName string

// Virtual Network and Subnet details for the backend VM
param vnetResourceGroup string
param vnetName string
param subnetName string

@minLength(3)
@maxLength(20)
@description('Nazwa użytkownika administratora maszyny backendowej.')
param adminUsername string

@secure()
@minLength(12)
@maxLength(123)
@description('Bezpieczne hasło administratora.')
param adminPassword string

// Deployment of the backend VM module
module backendVmModule './backend-vm.bicep' = {
  name: 'backendVmModuleDeployment'
  params: {
    location: location
    targetEnv: targetEnv
    vmName: vmName
    adminUsername: adminUsername
    adminPassword: adminPassword
    resourceTags: resourceTags
    targetSubscriptionId: targetSubscriptionId
    vnetResourceGroup: vnetResourceGroup
    vnetName: vnetName
    subnetName: subnetName
  }
}
