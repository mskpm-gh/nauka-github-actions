using '../templates/connection-monitor.bicep'

var subscriptionId = '7d33192c-4909-49bf-8fd0-0339f051608e'

param networkWatcherName = 'NetworkWatcher_westeurope'
param location = 'westeurope'
param monitorName = 'cm-netwatchermon-ver'
param sourceVmResourceId = '/subscriptions/${subscriptionId}/resourceGroups/fver-net-rg/providers/Microsoft.Compute/virtualMachines/NetWatcherMon-ver'
param workspaceResourceId = '/subscriptions/${subscriptionId}/resourceGroups/fver-prm-rg/providers/Microsoft.OperationalInsights/workspaces/ftst-law'
param actionGroupResourceId = '/subscriptions/${subscriptionId}/resourceGroups/fver-prm-rg/providers/microsoft.insights/actionGroups/fver-ag'
param testFrequencySec = 300
param kafkaAddress = 'kafka.falaver.sc.ads'
param gatewayAddress = 'api-dev.falaver.sc.ads'
param partnerAddress = 'apipay-ver.systemfala.pl'
param postgresRdbAddress = 'fver-rdb-db.postgres.database.azure.com'
param postgresOdbAddress = 'fver-odb-db.postgres.database.azure.com'
param sqlMiAddress = 'fver-tsm-sqlmi.be2c73250738.database.windows.net'
param tpeVmAddress = 'fver-tsm-vm-02.falaver.sc.ads'
param elkAddress = 'elk.falaver.sc.ads'
param internalAvlLbAddress = 'api-avl.falaver.sc.ads'
param publicApipayAddress = 'apipay.systemfala.pl'
param sftpAdsAddress = '20.4.242.89'
param tags = {
  Project: 'NetWatcherMon'
  TargetEnv: 'VER'
}
