// Wdrażany w RG istniejącego Network Watchera (NetworkWatcherRG)
//
// Mapowanie na numerowaną listę celów z INNBLTC-22189 (nr = "#" z ticketu):
//   #  | Cel                                  | Protokół / port        | Prio | Endpoint / test / grupa w tym pliku
//   1  | Kafka                                | TCP 9092, 9094         | P1   | kafka / tcp-9092, tcp-9094 / P1-kafka
//   2  | PostgreSQL rdb, odb                  | TCP 5432               | P1   | postgres-rdb, postgres-odb / tcp-5432 / P1-postgres-*  (cdb, ddb, tdb: BRAK)
//   3  | SQL MI                               | TCP 1433               | P1   | sqlmi / tcp-1433 / P1-sqlmi  (redirect 11000-11999: BRAK)
//   4  | TSM TPE_API / GTFS                   | HTTP 80 (kod 200-499)  | P1   | tpe-vm / tcp-80, http-80 / P1-tsm-api
//   5  | ELK                                  | HTTPS 9200             | P2   | elk / tcp-9200, https-9200 / P2-elk  (port Logstash: BRAK)
//   6  | Internal LB gtw-avl-lb               | TCP 80                 | P2   | internal-avl-lb / tcp-80 / P2-internal-avl-lb
//   7  | Bramka api-dev                       | HTTPS 7443             | P1   | gateway / tcp-7443, https-7443 / P1-gateway
//   8  | API KSeF (MF)                        | HTTPS 443              | P1   | BRAK (nie podano FQDN)
//   9  | Przelewy24 (publiczny apipay)        | HTTPS 443              | P1   | apipay-public / tcp-443, https-443 / P1-apipay-public  (Monet+, PeP/PayLane: BRAK)
//   10 | iPKO SOAP (bim-dmn)                  | HTTPS 443, cert klienta| P2   | BRAK (nie podano FQDN; wymaga certyfikatu klienta, a Connection Monitor go nie wysyła, więc HTTPS nie przejdzie - wystarczy TCP 443)
//   11 | Apple/Google/Facebook/Microsoft IdP  | HTTPS 443              | P2   | BRAK
//   12 | SMTP relay, ITS/SKM, TransData       | wg konfiguracji        | P2   | BRAK
//   13 | SFTP ADS                             | TCP 22                 | P3   | sftp-ads / tcp-22 / P3-sftp-ads
//   14 | apipay-{ver,uat}.systemfala.pl       | 443 i 8443             | P1   | partner-apipay / tcp-443, tcp-8443, https-8443 / P2-partner, P1-apipay-env-8443  (4 ścieżki P24: BRAK)
//   15 | Portal klienta, POK, konsola, Keycloak | -                    | P1   | BRAK
// Cele oznaczone BRAK czekają na FQDN/port/ścieżkę od właścicieli (szczegóły: docs, rozdz. 16).
param targetEnv string = 'tst'
param networkWatcherName string
param location string = resourceGroup().location
param monitorName string
param sourceVmResourceId string
param tags object = {}
param testFrequencySec int = 300
param workspaceResourceId string
param actionGroupResourceId string
param rttAlertThresholdMs int = 300
param kafkaAddress string = 'kafka.falauat.sc.ads'
param gatewayAddress string = 'api-dev.falauat.sc.ads'
param partnerAddress string = 'apipay-uat.systemfala.pl'
param postgresRdbAddress string = 'fuat-rdb-db.postgres.database.azure.com'
param postgresOdbAddress string = 'fuat-odb-db.postgres.database.azure.com'
param sqlMiAddress string
param tpeVmAddress string = 'fuat-tsm-vm-01.falauat.sc.ads'
param elkAddress string = 'elk.falauat.sc.ads'
param internalAvlLbAddress string = 'api-avl.falauat.sc.ads'
param publicApipayAddress string = 'apipay.systemfala.pl'
param sftpAdsAddress string = '20.4.242.89'

// PRD ma CDB/DDB/TDB zamiast ODB; domyślna lista zachowuje konfigurację UAT/VER.
param postgresAdditionalTargets { name: string, address: string }[] = [
  { name: 'odb', address: postgresOdbAddress }
]
param enablePartnerTests bool = true
param tsmValidStatusCodeRanges array = ['200-499']

var postgresAdditionalEndpoints = [
  for target in postgresAdditionalTargets: {
    name: 'postgres-${target.name}'
    type: 'ExternalAddress'
    address: target.address
  }
]
var postgresAdditionalGroups = [
  for target in postgresAdditionalTargets: {
    name: 'P1-postgres-${target.name}'
    disable: false
    sources: ['probe-vm']
    destinations: ['postgres-${target.name}']
    testConfigurations: ['tcp-5432']
  }
]

// Existing Network Watcher resource reference
resource nw 'Microsoft.Network/networkWatchers@2023-11-01' existing = {
  name: networkWatcherName
  scope: resourceGroup('NetworkWatcherRG')
}

// // 2. Dynamicznie zbuduj identyfikator do grupy NetworkWatcherRG
// var networkWatcherResourceId = resourceId(
//   subscription().subscriptionId, 
//   'NetworkWatcherRG', 
//   'Microsoft.Network/networkWatchers', 
//   networkWatcherName
// )

// Deployment of the connection monitor module
resource cm 'Microsoft.Network/networkWatchers/connectionMonitors@2023-11-01' = {
  //parent: nw
  #disable-next-line use-parent-property
  name: '${nw.name}/${monitorName}'
  location: location
  tags: tags
  properties: {
    outputs: [
      {
        type: 'Workspace'
        workspaceSettings: {
          workspaceResourceId: workspaceResourceId
        }
      }
    ]
    endpoints: [
      {
        name: 'probe-vm'
        type: 'AzureVM'
        resourceId: sourceVmResourceId
      }
      {
        // #1 Kafka
        name: 'kafka'
        type: 'ExternalAddress'
        address: kafkaAddress
      }
      {
        // #7 Bramka api-dev
        name: 'gateway'
        type: 'ExternalAddress'
        address: gatewayAddress
      }
      {
        // #14 apipay-{env}.systemfala.pl (443 i 8443)
        name: 'partner-apipay'
        type: 'ExternalAddress'
        address: partnerAddress
      }
      {
        // #2 PostgreSQL rdb (cdb, ddb, tdb: brak hostów)
        name: 'postgres-rdb'
        type: 'ExternalAddress'
        address: postgresRdbAddress
      }
      ...postgresAdditionalEndpoints
      {
        // #3 SQL MI
        name: 'sqlmi'
        type: 'ExternalAddress'
        address: sqlMiAddress
      }
      {
        // #4 TSM TPE_API / GTFS
        name: 'tpe-vm'
        type: 'ExternalAddress'
        address: tpeVmAddress
      }
      {
        // #5 ELK
        name: 'elk'
        type: 'ExternalAddress'
        address: elkAddress
      }
      {
        // #6 Internal LB gtw-avl-lb
        name: 'internal-avl-lb'
        type: 'ExternalAddress'
        address: internalAvlLbAddress
      }
      {
        // #9 Przelewy24 - publiczny apipay.systemfala.pl
        name: 'apipay-public'
        type: 'ExternalAddress'
        address: publicApipayAddress
      }
      {
        // #13 SFTP ADS
        name: 'sftp-ads'
        type: 'ExternalAddress'
        address: sftpAdsAddress
      }
    ]
    testConfigurations: [
      {
        // #1 Kafka
        name: 'tcp-9092'
        testFrequencySec: testFrequencySec
        protocol: 'Tcp'
        tcpConfiguration: {
          port: 9092
          disableTraceRoute: false
        }
        successThreshold: {
          checksFailedPercent: 5
          roundTripTimeMs: 300
        }
      }
      {
        // #1 Kafka
        name: 'tcp-9094'
        testFrequencySec: testFrequencySec
        protocol: 'Tcp'
        tcpConfiguration: {
          port: 9094
          disableTraceRoute: false
        }
        successThreshold: {
          checksFailedPercent: 5
          roundTripTimeMs: 300
        }
      }
      {
        // #2 PostgreSQL
        name: 'tcp-5432'
        testFrequencySec: testFrequencySec
        protocol: 'Tcp'
        tcpConfiguration: {
          port: 5432
          disableTraceRoute: false
        }
        successThreshold: {
          checksFailedPercent: 5
          roundTripTimeMs: 300
        }
      }
      {
        // #3 SQL MI (bez trybu redirect 11000-11999)
        name: 'tcp-1433'
        testFrequencySec: testFrequencySec
        protocol: 'Tcp'
        tcpConfiguration: {
          port: 1433
          disableTraceRoute: false
        }
        successThreshold: {
          checksFailedPercent: 5
          roundTripTimeMs: 300
        }
      }
      {
        // #4 TSM (TCP) i #6 Internal LB gtw-avl-lb
        name: 'tcp-80'
        testFrequencySec: testFrequencySec
        protocol: 'Tcp'
        tcpConfiguration: {
          port: 80
          disableTraceRoute: false
        }
        successThreshold: {
          checksFailedPercent: 5
          roundTripTimeMs: 1000
        }
      }
      {
        // #4 TSM TPE_API / GTFS - test HTTP
        name: 'http-80'
        testFrequencySec: testFrequencySec
        protocol: 'Http'
        httpConfiguration: {
          port: 80
          method: 'GET'
          path: '/'
          preferHTTPS: false
          // UAT/VER tymczasowo dopuszczają 470; nie potwierdza to sprawności aplikacji.
          validStatusCodeRanges: tsmValidStatusCodeRanges
        }
        successThreshold: {
          checksFailedPercent: 5
          roundTripTimeMs: 1000
        }
      }
      {
        // #5 ELK
        name: 'tcp-9200'
        testFrequencySec: testFrequencySec
        protocol: 'Tcp'
        tcpConfiguration: {
          port: 9200
          disableTraceRoute: false
        }
        successThreshold: {
          checksFailedPercent: 5
          roundTripTimeMs: 1000
        }
      }
      {
        // #5 ELK
        name: 'https-9200'
        testFrequencySec: testFrequencySec
        protocol: 'Http'
        httpConfiguration: {
          port: 9200
          method: 'GET'
          path: '/'
          preferHTTPS: true
          validStatusCodeRanges: ['200-399']
        }
        successThreshold: {
          checksFailedPercent: 5
          roundTripTimeMs: 1000
        }
      }
      {
        // #7 Bramka api-dev
        name: 'https-7443'
        testFrequencySec: testFrequencySec
        protocol: 'Http'
        httpConfiguration: {
          port: 7443
          method: 'GET'
          path: '/'
          preferHTTPS: true
          validStatusCodeRanges: ['200-399']
        }
        successThreshold: {
          checksFailedPercent: 5
          roundTripTimeMs: 1000
        }
      }
      {
        // #7 Bramka api-dev
        name: 'tcp-7443'
        testFrequencySec: testFrequencySec
        protocol: 'Tcp'
        tcpConfiguration: {
          port: 7443
          disableTraceRoute: false
        }
        successThreshold: {
          checksFailedPercent: 5
          roundTripTimeMs: 1000
        }
      }
      {
        // #9 Przelewy24 (apipay publiczny), #14 apipay-{env}; docelowo też #8, #9 (Monet+, PeP), #10 (iPKO, tylko TCP), #11
        name: 'tcp-443'
        testFrequencySec: testFrequencySec
        protocol: 'Tcp'
        tcpConfiguration: {
          port: 443
          disableTraceRoute: false
        }
        successThreshold: {
          checksFailedPercent: 5
          roundTripTimeMs: 1000
        }
      }
      {
        // #14 apipay-{env}.systemfala.pl:8443
        name: 'tcp-8443'
        testFrequencySec: testFrequencySec
        protocol: 'Tcp'
        tcpConfiguration: {
          port: 8443
          disableTraceRoute: false
        }
        successThreshold: {
          checksFailedPercent: 5
          roundTripTimeMs: 1000
        }
      }
      {
        // #14 apipay-{env}.systemfala.pl:8443
        name: 'https-8443'
        testFrequencySec: testFrequencySec
        protocol: 'Http'
        httpConfiguration: {
          port: 8443
          method: 'GET'
          path: '/'
          preferHTTPS: true
          validStatusCodeRanges: ['200-399']
        }
        successThreshold: {
          checksFailedPercent: 5
          roundTripTimeMs: 1000
        }
      }
      {
        // #9 Przelewy24 (apipay publiczny); ścieżka '/' zamiast 4 ścieżek notyfikacji (#14)
        name: 'https-443'
        testFrequencySec: testFrequencySec
        protocol: 'Http'
        httpConfiguration: {
          port: 443
          method: 'GET'
          path: '/'
          preferHTTPS: true
          validStatusCodeRanges: ['200-399']
        }
        successThreshold: {
          checksFailedPercent: 5
          roundTripTimeMs: 1000
        }
      }
      {
        // #13 SFTP ADS
        name: 'tcp-22'
        testFrequencySec: testFrequencySec
        protocol: 'Tcp'
        tcpConfiguration: {
          port: 22
          disableTraceRoute: false
        }
        successThreshold: {
          checksFailedPercent: 5
          roundTripTimeMs: 1000
        }
      }
    ]
    testGroups: [
      // Miejsce na kolejne grupy: #8 KSeF, #9 Monet+/PeP/PayLane, #10 iPKO SOAP (bim-dmn; HTTPS 443, P2),
      // #11 IdP, #12 SMTP/ITS/SKM/TransData, #15 portale/Keycloak - dodać po otrzymaniu FQDN/portów
      {
        // #1 Kafka
        name: 'P1-kafka'
        disable: false
        sources: ['probe-vm']
        destinations: ['kafka']
        testConfigurations: ['tcp-9092', 'tcp-9094']
      }
      {
        // #2 PostgreSQL rdb
        name: 'P1-postgres-rdb'
        disable: false
        sources: ['probe-vm']
        destinations: ['postgres-rdb']
        testConfigurations: ['tcp-5432']
      }
      ...postgresAdditionalGroups
      {
        // #3 SQL MI
        name: 'P1-sqlmi'
        disable: false
        sources: ['probe-vm']
        destinations: ['sqlmi']
        testConfigurations: ['tcp-1433']
      }
      {
        // #4 TSM TPE_API / GTFS
        name: 'P1-tsm-api'
        disable: false
        sources: ['probe-vm']
        destinations: ['tpe-vm']
        testConfigurations: ['tcp-80', 'http-80']
      }
      {
        // #5 ELK
        name: 'P2-elk'
        disable: false
        sources: ['probe-vm']
        destinations: ['elk']
        testConfigurations: ['tcp-9200', 'https-9200']
      }
      {
        // #6 Internal LB gtw-avl-lb
        name: 'P2-internal-avl-lb'
        disable: false
        sources: ['probe-vm']
        destinations: ['internal-avl-lb']
        testConfigurations: ['tcp-80']
      }
      {
        // #7 Bramka api-dev
        name: 'P1-gateway'
        disable: false
        sources: ['probe-vm']
        destinations: ['gateway']
        testConfigurations: ['tcp-7443', 'https-7443']
      }
      {
        // #14 apipay-{env}.systemfala.pl:443 (pierwotny test partnera; nazwa grupy zachowana dla ciągłości wyników)
        name: 'P2-partner'
        disable: !enablePartnerTests
        sources: ['probe-vm']
        destinations: ['partner-apipay']
        testConfigurations: ['tcp-443']
      }
      {
        // #9 Przelewy24 - publiczny apipay.systemfala.pl
        name: 'P1-apipay-public'
        disable: false
        sources: ['probe-vm']
        destinations: ['apipay-public']
        testConfigurations: ['tcp-443', 'https-443']
      }
      {
        // #14 apipay-{env}.systemfala.pl:8443
        name: 'P1-apipay-env-8443'
        disable: !enablePartnerTests
        sources: ['probe-vm']
        destinations: ['partner-apipay']
        testConfigurations: ['tcp-8443', 'https-8443']
      }
      {
        // #13 SFTP ADS
        name: 'P3-sftp-ads'
        disable: false
        sources: ['probe-vm']
        destinations: ['sftp-ads']
        testConfigurations: ['tcp-22']
      }
    ]
  }
}

// Metric alerts for the connection monitor
resource alertFailed 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${monitorName}-checks-failed'
  location: 'global'
  tags: tags
  properties: {
    description: 'Connection Monitor: odsetek nieudanych testów > 5% w oknie 5 min'
    severity: 1
    enabled: true
    scopes: [cm.id]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'ChecksFailedPercent'
          metricName: 'ChecksFailedPercent'
          metricNamespace: 'Microsoft.Network/networkWatchers/connectionMonitors'
          operator: 'GreaterThan'
          threshold: 5
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [{ actionGroupId: actionGroupResourceId }]
  }
}

// Metric alert for high round-trip time (RTT)
resource alertRtt 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${monitorName}-rtt-high'
  location: 'global'
  tags: tags
  properties: {
    description: 'Connection Monitor: RTT powyżej progu'
    severity: 2
    enabled: true
    scopes: [cm.id]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'RoundTripTimeMs'
          metricName: 'RoundTripTimeMs'
          metricNamespace: 'Microsoft.Network/networkWatchers/connectionMonitors'
          operator: 'GreaterThan'
          threshold: rttAlertThresholdMs
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [{ actionGroupId: actionGroupResourceId }]
  }
}
