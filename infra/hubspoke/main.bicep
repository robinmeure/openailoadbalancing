targetScope = 'subscription'

@description('Subscription ID of the subscription where hub network lives')
param hubSubscriptionId string
@description('Subscription ID of the subscription where spoke network lives')
param spokeSubscriptionId string
param hubVnetName string
param hubSubnetName string
param hubResourcegroupName string
param spokeVnetName string
param spokeSubnetName string
param spokeResourcegroupName string

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
param openAIAPIDescription string

@description('Full URL for the OpenAI API spec')
param openAIAPISpecURL string

@description('The name of the named value for the load balancing configuration')
param openAILoadBalancingConfigName string

// advance-load-balancing: added parameter
@description('The value of the named value for the load balancing configuration')
var openAILoadBalancingConfigValue = '[ {"name": "openai1", "priority": 1, "weight": 100}, {"name": "openai2", "priority": 2, "weight": 300}  ]'

@description('The name of the Log Analytics resource')
param logAnalyticsName string

var apimServiceName = '${apimResourceName}-${uniqueString(hubSubscriptionId, hubRg.id)}'
var workspaceName = '${logAnalyticsName}-${uniqueString(spokeSubscriptionId, hubRg.id)}'

@description('The name of the Application Insights resource')
param appInsightName string

resource hubRg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: hubResourcegroupName
  scope: subscription(hubSubscriptionId)
}

resource hubVnet 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  name: hubVnetName
  scope: hubRg
}

#disable-next-line BCP081
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2021-05-01' existing = {
  name: 'privatelink.openai.azure.com'
  scope: hubRg
}

resource apimSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  name: hubSubnetName
  parent: hubVnet
}

resource spokeRg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: spokeResourcegroupName
  scope: subscription(spokeSubscriptionId)
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
    resourceSuffix: uniqueString(spokeSubscriptionId, spokeRg.id)
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
      openaiName: '${config.name}-${config.location}-${uniqueString(spokeSubscriptionId, spokeRg.id)}'
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
    name: '${apimResourceName}-pip-${uniqueString(hubSubscriptionId, hubRg.id)}'
    zones: [
      1
      2
      3
    ]
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: '${apimResourceName}-pip-${uniqueString(hubSubscriptionId, hubRg.id)}'
      domainNameLabelScope: 'TenantReuse'
      fqdn: '${apimResourceName}.${apimResourceLocation}.cloudapp.azure.com'
    }
  }
}

module service 'br/public:avm/res/api-management/service:0.5.0' = {
  dependsOn: [
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
  }
}

module namedValue '../modules/apim/namedvalue.bicep' = {
  name: 'deploy-named-value-forlb'
  scope: resourceGroup(hubResourcegroupName)
  params: {
    apimServiceName: service.outputs.name
    openAILoadBalancingConfigName: openAILoadBalancingConfigName
    openAILoadBalancingConfigValue: openAILoadBalancingConfigValue
  }
}

module api '../modules/apim/api.bicep' = {
  dependsOn: [
    namedValue
  ]
  name: 'deploy-azureai-api'
  scope: resourceGroup(hubResourcegroupName)
  params: {
    apimServiceName: service.outputs.name
    openAIAPIDescription: openAIAPIDescription
    openAIAPIDisplayName: openAIAPIDisplayName
    openAIAPIName: openAIAPIName
    openAIAPIPath: openAIAPIPath
    openAIAPISpecURL: openAIAPISpecURL
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

module appInsights 'br/public:avm/res/insights/component:0.4.1' = {
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

module logging '../modules/apim/logging.bicep' = {
  dependsOn: [
    appInsights
    api
  ]
  name: 'deploy-logging'
  scope: hubRg
  params: {
    apimServiceName: service.outputs.name
    applicationInsightsId: appInsights.outputs.resourceId
    applicationInsightsKey: appInsights.outputs.instrumentationKey
  }
}

module aiHeaders '../modules/apim/aiheaders.bicep' = {
  dependsOn: [
    logging
  ]
  name: 'deploy-ai-headers'
  scope: hubRg
  params: {
    apimServiceName: service.outputs.name
    apiName: 'openai-api'
    apimLoggerId: logging.outputs.apimLoggerId
  }
}

module backends '../modules/apim/backends.bicep' = {
  name: 'deploy-azureai-backend'
  scope: hubRg
  params: {
    openAIBackendPoolName: 'openai-backend-pool'
    openAIBackendPoolDescription: 'OpenAI Backend Pool'
    cognitiveServices: aoai.outputs.endpoints
    apimServiceName: service.outputs.name
    openAIConfig: openAIConfig
  }
}

module subscriptions '../modules/apim/subscriptions.bicep' = {
  dependsOn: [
    backends
  ]
  name: 'deploy-azureai-subscriptions'
  scope: hubRg
  params: {
    apimServiceName: service.outputs.name
  }
}

module permissions '../modules/apim/permissions.bicep' = [
  for (config, i) in openAIConfig: if (length(openAIConfig) > 0) {
    scope: spokeRg
    name: '${config.name}-roleDefinitions'
    params: {
      apimPrincipalId: service.outputs.systemAssignedMIPrincipalId
      cognitiveServiceName: aoai.outputs.endpoints[i].name
    }
  }
]
