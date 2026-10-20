using './connection-monitor.bicep'
param targetEnv = 'tst'
var subscriptionId = 'f3e2a318-c7da-4fa4-934b-e0ff5bb8f8cf'
var resourceGroupName = 'NetWatcherRG'
var vmResourceGroupName = 'rg-PiotrMajkowski'
param vmWorkspaceName = 'law-inno-prod-krwgvnybe4eok'

param monitorName = 'cm-NetWatcherMon-tst'


param networkWatcherName = 'NetworkWatcher_germanywestcentral'
param location = 'germanywestcentral'

param sourceVmResourceId = '/subscriptions/${subscriptionId}/resourceGroups/${vmResourceGroupName}/providers/Microsoft.Compute/virtualMachines/NetWatcherMon-${targetEnv}'

param workspaceResourceId = '/subscriptions/${subscriptionId}/resourceGroups/${vmResourceGroupName}/providers/Microsoft.OperationalInsights/workspaces/${vmWorkspaceName}'

param actionGroupResourceId = '/subscriptions/${subscriptionId}/resourceGroups/${vmResourceGroupName}/providers/microsoft.insights/actionGroups/VMI-ActionGroup-vm-backend-prod-01'

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
  TargetEnv: targetEnv
}
