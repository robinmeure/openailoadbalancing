@description('List of OpenAI resources to create. Add pairs of name and location.')
param openAIConfig array

@description('The name of the API Management resource')
param apimResourceName string = 'apim31'

@description('Location for the APIM resource')
param apimResourceLocation string = resourceGroup().location

@description('The pricing tier of this API Management service')
@allowed([
  'Consumption'
  'Developer'
  'Basic'
  'Basicv2'
  'Standard'
  'Standardv2'
  'Premium'
])
param apimSku string = 'Standardv2'

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

@description('The description of the APIM API for OpenAI API')
param openAIAPIDescription string

@description('Full URL for the OpenAI API spec')
param openAIAPISpecURL string

@description('The name of the APIM Subscription for OpenAI API')
param openAISubscriptionName string

@description('The description of the APIM Subscription for OpenAI API')
param openAISubscriptionDescription string

@description('The name of the OpenAI backend pool')
param openAIBackendPoolName string

@description('The description of the OpenAI backend pool')
param openAIBackendPoolDescription string
// advance-load-balancing: added parameter
@description('The name of the named value for the load balancing configuration')
param openAILoadBalancingConfigName string

// advance-load-balancing: added parameter
@description('The value of the named value for the load balancing configuration')
param openAILoadBalancingConfigValue array

@description('The name of the named value for the fair use configuration')
param openAIFairUseConfigName string

@description('The value of the named value for the fair use configuration')
param openAIFairUseConfigValue array

@description('The name of the Log Analytics resource')
param logAnalyticsName string

@description('The name of the Application Insights resource')
param appInsightName string

@description('The prefix of the APIM subnet')
param apimSubnetPrefix string

@description('The prefix of the OpenAI subnet')
param openaiSubnetPrefix string

@description('The prefix of the ACA subnet')
param acaSubnetPrefix string 

@description('The prefix of the VNET')
param vnetAddressPrefix string

@description('The name of the VNET')
param vnetName string


var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)

module network '../infra/modules/networking/network.bicep' = {
  name: 'network-deployment'
  params: {
    apimSku: apimSku
    location: apimResourceLocation
    apimSubnetPrefix: apimSubnetPrefix
    openaiSubnetPrefix: openaiSubnetPrefix
    acaSubnetPrefix: acaSubnetPrefix
    vnetAddressPrefix: vnetAddressPrefix
    vnetName: vnetName
  }
}

resource cognitiveServices 'Microsoft.CognitiveServices/accounts@2021-10-01' = [
  for config in openAIConfig: if (length(openAIConfig) > 0) {
    name: '${config.name}-${resourceSuffix}'
    location: config.location
    sku: {
      name: config.sku
    }
    kind: 'OpenAI'
    properties: {
      disableLocalAuth: true
      publicNetworkAccess: 'Disabled'
      networkAcls: {defaultAction: 'Deny'}
      apiProperties: {
        statisticsEnabled: false
      }
      customSubDomainName: toLower('${config.name}-${resourceSuffix}')
    }
  }
]

module privateEndpoints '../infra/modules/networking/private-endpoint.bicep' = [
  for config in openAIConfig: if (length(openAIConfig) > 0) {
    name: '${config.name}-private-endpoint-deployment'
    params: {
      location: apimResourceLocation
      openaiName: '${config.name}-${resourceSuffix}'
      openaiSubnetResourceId: network.outputs.openaiSubnetId
      privateDnsZoneId: network.outputs.privateDnsZoneId
    }
  }
]


resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = [
  for (config, i) in openAIConfig: if (length(openAIConfig) > 0) {
    name: config.deploymentName
    parent: cognitiveServices[i]
    properties: {
      model: {
        format: 'OpenAI'
        name: config.modelName
        version: config.modelVersion
      }
    }
    sku: {
      name: 'Standard'
      capacity: config.modelCapacity
    }
  }
]

//setting explicit public IP for APIM will force stV2 instance of APIM
resource apimPublicIp 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: '${apimResourceName}-pip-${resourceSuffix}'
  location: apimResourceLocation
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  zones: ['1','2','3']
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: '${apimResourceName}-pip-${resourceSuffix}'
      fqdn: '${apimResourceName}.${apimResourceLocation}.cloudapp.azure.com'
    }
    

  }

}

resource apimService 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: '${apimResourceName}-${resourceSuffix}'
  location: apimResourceLocation
  sku: {
    name: apimSku
    capacity: (apimSku == 'Consumption') ? 0 : ((apimSku == 'Developer') ? 1 : apimSkuCount)
  }
  properties: {
    virtualNetworkType: 'External'
    publicIpAddressId: apimPublicIp.id 
    virtualNetworkConfiguration: {
      subnetResourceId: network.outputs.apimSubnetId
    }
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
    customProperties: apimSku == 'Consumption' ? {} : {
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
  }
  identity: {
    type: 'SystemAssigned'
  }
}

var cognitiveServicesOpenAIUserResourceId = resourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
resource cognitiveServicesOpenAIUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for (config, i) in openAIConfig: if (length(openAIConfig) > 0) {
    scope: cognitiveServices[i]
    name: guid(subscription().id, resourceGroup().id, config.name, cognitiveServicesOpenAIUserResourceId)
    properties: {
      roleDefinitionId: cognitiveServicesOpenAIUserResourceId
      principalId: apimService.identity.principalId
      principalType: 'ServicePrincipal'
    }
  }
]



resource api 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  name:openAIAPIName
  parent: apimService
  properties: {
    apiType: 'http'
    description: openAIAPIDescription
    displayName: openAIAPIDisplayName
    format: 'openapi-link'
    path: openAIAPIPath
    protocols: [
      'https'
    ]
    subscriptionKeyParameterNames: {
      header: 'api-key'
      query: 'api-key'
    }
    subscriptionRequired: true
    type: 'http'
    value: openAIAPISpecURL
  }
}

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2021-12-01-preview' = {
  name: 'policy'
  parent: api
  properties: {
    format: 'rawxml'
    value: loadTextContent('policy.xml')
  }
}

resource backendOpenAI 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = [
  for (config, i) in openAIConfig: if (length(openAIConfig) > 0) {
    name: config.name
    parent: apimService
    properties: {
      description: 'backend description'
      url: '${cognitiveServices[i].properties.endpoint}openai'
      protocol: 'http'
      circuitBreaker: {
        rules: [
          {
            failureCondition: {
              count: 3
              errorReasons: [
                'Server errors'
              ]
              interval: 'PT5M'
              statusCodeRanges: [
                {
                  min: 429
                  max: 429
                }
              ]
            }
            name: 'openAIBreakerRule'
            tripDuration: 'PT1M'
          }
        ]
      }
    }
  }
]

resource backendPoolOpenAI 'Microsoft.ApiManagement/service/backends@2023-09-01-preview' = if (length(openAIConfig) > 1) {
  name: openAIBackendPoolName
  parent: apimService
#disable-next-line BCP035
  properties: {
    description: openAIBackendPoolDescription
    type: 'Pool'
    //     protocol: 'http'  // the protocol is not needed in the Pool type
    //     url: '${cognitiveServices[0].properties.endpoint}/openai'   // the url is not needed in the Pool type
    pool: {
      services: [
        for (config, i) in openAIConfig: {
          id: '/backends/${backendOpenAI[i].name}'
        }
      ]
    }
  }
}

resource apimSubscription 'Microsoft.ApiManagement/service/subscriptions@2023-05-01-preview' = {
  name: openAISubscriptionName
  parent: apimService
  properties: {
    allowTracing: true
    displayName: openAISubscriptionDescription
    scope: '/apis/${api.id}'
    state: 'active'
  }
}


// advance-load-balancing: added a naned value resource
resource openAILoadBalancingConfigNameNamedValue 'Microsoft.ApiManagement/service/namedValues@2023-05-01-preview' = {
  name: openAILoadBalancingConfigName
  parent: apimService
  properties: {
    displayName: openAILoadBalancingConfigName
    secret: false
    value: string(openAILoadBalancingConfigValue)
  }
}

resource openAIFairUseConfigNameNamedValue 'Microsoft.ApiManagement/service/namedValues@2023-05-01-preview' = {
  name: openAIFairUseConfigName
  parent: apimService
  properties: {
    displayName: openAIFairUseConfigName
    secret: false
    value: string(openAIFairUseConfigValue)
  }
}

resource apiFinanceSubscription 'Microsoft.ApiManagement/service/subscriptions@2023-03-01-preview' = {
  parent: apimService
  name: 'finance-dept-subscription'
  properties: {
    scope: '/apis'
    displayName: 'Finance'
    state: 'active'
    allowTracing: true
  }
}

resource apiMarketingSubscription 'Microsoft.ApiManagement/service/subscriptions@2023-03-01-preview' = {
  parent: apimService
  name: 'marketing-dept-subscription'
  properties: {
    scope: '/apis'
    displayName: 'Marketing'
    state: 'active'
    allowTracing: true
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: '${logAnalyticsName}-${resourceSuffix}'
  location: apimResourceLocation
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  })
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${appInsightName}-${resourceSuffix}'
  location: apimResourceLocation
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource apimLogger 'Microsoft.ApiManagement/service/loggers@2021-12-01-preview' = {
  name: 'appinsights-logger'
  parent: apimService
  properties: {
    credentials: {
      instrumentationKey: applicationInsights.properties.InstrumentationKey
    }
    description: 'Logger to Azure Application Insights'
    isBuffered: false
    loggerType: 'applicationInsights'
    resourceId: applicationInsights.id
  }
}

var headers = [
  'x-ratelimit-remaining-requests'
  'x-ratelimit-remaining-tokens'
  'consumed-tokens'
  'remaining-tokens'
  'prompt-tokens'
  'completion-tokens'
]

resource symbolicname 'Microsoft.ApiManagement/service/apis/diagnostics@2023-09-01-preview' = {
  name: 'applicationinsights'
  parent: api
  properties: {
    alwaysLog: 'allErrors'
    backend: {
      request: {
        body: {
          bytes: 0
        }
        headers:['x-client-id']
      }
      response: {
        body: {
          bytes: 0
        }
        headers: headers
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
        headers: headers
      }
    }
    httpCorrelationProtocol: 'Legacy'
    logClientIp: true
    loggerId: apimLogger.id
    metrics: true
    operationNameFormat: 'Name'
    sampling: {
      percentage: 100
      samplingType: 'fixed'
    }
    verbosity: 'information'
  }
}

output apimServiceId string = apimService.id
output apimResourceGatewayURL string = apimService.properties.gatewayUrl

#disable-next-line outputs-should-not-contain-secrets
output apimSubscriptionKey string = apimSubscription.listSecrets().primaryKey
