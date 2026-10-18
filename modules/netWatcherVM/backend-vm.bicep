metadata name = 'Backend Virtual Machine Deployment via AVM'
metadata description = 'Ten moduł wdraża maszynę wirtualną w podsieci prywatnej jako backend dla NetWatcherMon.'

param location string = resourceGroup().location
param targetEnv string

param resourceTags object = {}

@description('Nazwa maszyny wirtualnej')
param vmName string

@description('Rozmiar maszyny wirtualnej (SKU)')
param vmSize string = 'Standard_B2als_v2'

@description('Nazwa użytkownika administratora')
param adminUsername string

@secure()
@description('Hasło administratora maszyny')
param adminPassword string

param targetSubscriptionId string
param vnetResourceGroup string
param vnetName string
param subnetName string

// Dynamiczne budowanie pełnego identyfikatora Subnet ID
@description('Pełny identyfikator Resource ID podsieci, w której ma stanąć karta sieciowa maszyny')
var subnetId = resourceId(
  targetSubscriptionId,
  vnetResourceGroup,
  'Microsoft.Network/virtualNetworks/subnets',
  vnetName,
  subnetName
)

// Sufiks nazwy karty sieciowej – jedno źródło prawdy dla modułu i outputu vmNICid
var nicSuffix = '-nic-01'

// Wywołanie oficjalnego modułu AVM dla maszyn wirtualnych
module virtualMachineAzVerified 'br/public:avm/res/compute/virtual-machine:0.5.1' = {
  name: 'backendVmDeployment-${vmName}'
  params: {
    name: vmName
    location: location
    tags: resourceTags
    osType: 'Linux'
    vmSize: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    zone: 0

    // Wersja 0.5.1 modułu AVM dla maszyn wirtualnych nie obsługuje jeszcze parametru encryptionAtHost, więc ustawiamy go ręcznie poniżej
    encryptionAtHost: false

    // Konfiguracja obrazu systemu (Ubuntu 24.04 LTS)
    imageReference: {
      publisher: 'Canonical'
      offer: 'ubuntu-24_04-lts'
      sku: 'server'
      version: 'latest'
    }

    // Konfiguracja dysku systemowego
    osDisk: {
      diskSizeGB: 30
      managedDisk: {
        storageAccountType: 'Standard_LRS' // Najtańszy dysk na środowisko deweloperskie
      }
      caching: 'ReadWrite'
    }

    // INTERFEJSY SIECIOWE (Karta sieciowa podpięta pod istniejący Subnet)
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'ipconfig1'
            subnetResourceId: subnetId
            privateIPAllocationMethod: 'Dynamic'
          }
        ]
        nicSuffix: nicSuffix
      }
    ]

    // Blokada telemetrii Microsoftu dla czystości logów
    enableTelemetry: false
  }
}

// Rozszerzenie agenta Network Watcher dla maszyny wirtualnej
resource networkWatcherAgent 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
  name: '${vmName}/AzureNetworkWatcherExtension'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.NetworkWatcher'
    type: 'NetworkWatcherAgentLinux'
    typeHandlerVersion: '1.4'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
  dependsOn: [
    virtualMachineAzVerified
  ]
}

// 👇 WYJŚCIA Z MODUŁU
@description('Resource ID utworzonej maszyny wirtualnej')
output vmId string = virtualMachineAzVerified.outputs.resourceId

@description('Resource ID karty sieciowej; nazwa wynika z vmName i nicSuffix użytego w module AVM (moduł nie zwraca ID NIC)')
output vmNICid string = resourceId('Microsoft.Network/networkInterfaces', '${vmName}${nicSuffix}')
