targetScope = 'subscription'

param subHub string 
param subSpoke string 
param hubVnetName string = 'vnet-hub'
param hubSubnetName string = 'subnet-apim'
param hubRgName string = 'rg-hub'
param spokeVnetName string = 'vnet-spoke'
param spokeSubnetName string = 'subnet-openai'
param spokeRgName string = 'rg-spoke'

@description('List of OpenAI resources to create. Add pairs of name and location.')
param openAIConfig array

@description('Deployment Name')
param openAIDeploymentName string

@description('Azure OpenAI Sku')
@allowed([
  'S0'
])
param openAISku string

@description('Model Name')
param openAIModelName string

@description('Model Version')
param openAIModelVersion string

@description('Model Capacity')
param openAIModelCapacity int

@description('The name of the API Management resource')
param apimResourceName string = 'apim31'

@description('Location for the APIM resource')
param apimResourceLocation string

@description('The pricing tier of this API Management service')
@allowed([
  'Consumption'
  'Developer'
  'Basic'
  'BasicV2'
  'Standard'
  'StandardV2'
  'Premium'
])
param apimSku string = 'StandardV2'

@description('The instance size of this API Management service.')
@allowed([
  0
  1
  2
])
param apimSkuCount int = 1

@description('The email address of the owner of the service')
param apimPublisherEmail string
@description('The name of the owner of the service')
param apimPublisherName string

@description('The name of the APIM API for OpenAI API')
param openAIAPIName string

@description('The relative path of the APIM API for OpenAI API')
param openAIAPIPath string

@description('The display name of the APIM API for OpenAI API')
param openAIAPIDisplayName string

@description('Full URL for the OpenAI API spec')
param openAIAPISpecURL string

@description('The name of the named value for the load balancing configuration')
param openAILoadBalancingConfigName string

// advance-load-balancing: added parameter
@description('The value of the named value for the load balancing configuration')
var openAILoadBalancingConfigValue = '[ {"name": "openai1", "priority": 1, "weight": 100}, {"name": "openai2", "priority": 2, "weight": 300}  ]'

@description('The name of the Log Analytics resource')
param logAnalyticsName string

var apimServiceName = '${apimResourceName}-${uniqueString(subHub, hubRg.id)}'
var workspaceName = '${logAnalyticsName}-${uniqueString(subHub, hubRg.id)}'

@description('The name of the Application Insights resource')
param appInsightName string

resource hubRg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: hubRgName
  scope: subscription(subHub)
}

resource hubVnet 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  name: hubVnetName
  scope: hubRg
}


resource privateDnsZone 'Microsoft.Network/privateDnsZones@2021-05-01' existing = {
   name: 'privatelink.openai.azure.com'
   scope: hubRg
 }

resource apimSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  name: hubSubnetName
  parent: hubVnet
}

resource spokeRg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: spokeRgName
  scope: subscription(subSpoke)
}

resource spokeVnet 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  name: spokeVnetName
  scope: spokeRg
}

resource aoaiSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  name: spokeSubnetName
  parent: spokeVnet
}

module aoai '../modules/aoai/cognitiveservice.bicep' = {
  scope: spokeRg
  name: 'aoai'
  params: {
    openAIConfig: openAIConfig
    openAISku: openAISku
    resourceSuffix: uniqueString(subSpoke, spokeRg.id)
    openAIDeploymentName: openAIDeploymentName
    openAIModelName: openAIModelName
    openAIModelVersion: openAIModelVersion
    openAIModelCapacity: openAIModelCapacity
  }
}

module privateEndpoints '../modules/networking/private-endpoint.bicep' = [
  
  for config in openAIConfig: if (length(openAIConfig) > 0) {
    dependsOn: [aoai]
    scope: spokeRg
    name: '${config.name}-private-endpoint-deployment'
    params: {
      location: apimResourceLocation
      openaiName: '${config.name}-${config.location}-${uniqueString(subSpoke, spokeRg.id)}'
      openaiSubnetResourceId: aoaiSubnet.id
      privateDnsZoneId: privateDnsZone.id
    }
  }
]

module apimPublicIp 'br/public:avm/res/network/public-ip-address:0.6.0' = {
  name: 'apim-pip-deployment'
  scope: hubRg
  params: {
    location: apimResourceLocation
    name: '${apimResourceName}-pip-${uniqueString(subHub, hubRg.id)}'
    zones: [
      1
      2
      3
    ]
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: '${apimResourceName}-pip-${uniqueString(subHub, hubRg.id)}'
      domainNameLabelScope: 'TenantReuse'
      fqdn: '${apimResourceName}.${apimResourceLocation}.cloudapp.azure.com'
    }
  }
}

module service 'br/public:avm/res/api-management/service:0.5.0' = {
  dependsOn:[
    apimPublicIp
    aoai
  ]
  name: 'apim-deployment'
  scope: hubRg
  params: {
    name: apimServiceName
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
    sku: apimSku
    skuCapacity: (apimSku == 'Consumption') ? 0 : ((apimSku == 'Developer') ? 1 : apimSkuCount)
    virtualNetworkType: 'External'
    subnetResourceId: apimSubnet.id
    publicIpAddressResourceId: apimPublicIp.outputs.resourceId
    customProperties: apimSku == 'Consumption'
      ? {}
      : {
          'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA': 'false'
          'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA': 'false'
          'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_GCM_SHA256': 'false'
          'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_256_CBC_SHA256': 'false'
          'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_CBC_SHA256': 'false'
          'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_256_CBC_SHA': 'false'
          'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_CBC_SHA': 'false'
          'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TripleDes168': 'false'
          'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'false'
          'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'false'
          'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30': 'false'
          'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'false'
          'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'false'
          'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'false'
        }
    managedIdentities: {
      systemAssigned: true
    }
    apis: [
      {
        name: openAIAPIName
        displayName: openAIAPIDisplayName
        path: openAIAPIPath
        value: openAIAPISpecURL
        subscriptionKeyParameterNames: {
          header: 'api-key'
          query: 'api-key'
        }
        policies: [
          {
            format: 'rawxml'
            value: loadTextContent('../policy.xml')
          }
        ]
      }
    ]
    //this needs to get fixed
    // backends: [ 
    //   for (config, i) in openAIConfig: {
    //     description: 'backend description'
    //     url: '${aoai.outputs.endpoints[i]}openai'
    //     protocol: 'http'
    //     circuitBreaker: {
    //       rules: [
    //         {
    //           failureCondition: {
    //             count: 3
    //             errorReasons: [
    //               'Server errors'
    //             ]
    //             interval: 'PT5M'
    //             statusCodeRanges: [
    //               {
    //                 min: 429
    //                 max: 429
    //               }
    //             ]
    //           }
    //           name: 'openAIBreakerRule'
    //           tripDuration: 'PT1M'
    //         }
    //       ]
    //     }
    //     type: 'Pool'
    //     pool: {
    //       services: {
    //           id: '/backends/${config[i].name}'
    //         }          
    //     }
    //   }
    // ]
    subscriptions: [
      { scope: '/apis', displayName: 'Finance', state: 'active', allowTracing: true }
      { scope: '/apis'
        displayName: 'Marketing'
        state: 'active'
        allowTracing: true
      }
    ]
    namedValues: [
      {
        displayName: openAILoadBalancingConfigName
        secret: false
        value: openAILoadBalancingConfigValue
      }
    ]
    loggers:[
      {
        credentials: {
          instrumentationKey: appInsights.outputs.instrumentationKey
        }
        description: 'Logger to Azure Application Insights'
        isBuffered: false
        loggerType: 'applicationInsights'
        resourceId: appInsights.outputs.resourceId
      }
    ]
    apiDiagnostics:[
      {
        name: 'applicationinsights'
        alwaysLog: 'allErrors'
        backend: {
          request: {
            body: {
              bytes: 0
            }
          }
          response: {
            body: {
              bytes: 0
            }
            headers: [
              'x-ratelimit-remaining-requests'
              'x-ratelimit-remaining-tokens'
              'consumed-tokens'
              'remaining-tokens'
              'prompt-tokens'
              'completions-tokens'
            ]
          }
        }
        frontend: {
          request: {
            body: {
              bytes: 0
            }
          }
          response: {
            body: {
              bytes: 0
            }
            headers: [
              'x-ratelimit-remaining-requests'
              'x-ratelimit-remaining-tokens'
              'consumed-tokens'
              'remaining-tokens'
              'prompt-tokens'
              'completions-tokens'
            ]
          }
        }
        httpCorrelationProtocol: 'Legacy'
        logClientIp: true
        loggerId: appInsights.outputs.resourceId
        metrics: true
        operationNameFormat: 'Name'
        sampling: {
          percentage: 100
          samplingType: 'fixed'
        }
        verbosity: 'information'
      }
    ]
  }
}

module workspace 'br/public:avm/res/operational-insights/workspace:0.7.0' = {
  name: 'workspaceDeployment'
  scope: hubRg
  params: {
    name: workspaceName
    dataRetention: 90
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

module appInsights 'br/public:avm/res/insights/component:0.4.1'= {
  name: 'appInsightsDeployment'
  scope: hubRg
  params: {
    name: appInsightName
    workspaceResourceId: workspace.outputs.resourceId
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    applicationType: 'web'
  }
}
