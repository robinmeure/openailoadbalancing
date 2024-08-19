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
var openAILoadBalancingConfigValue = '[ {"name": "openai1", "priority": 1, "weight": 100}, {"name": "openai2", "priority": 2, "weight": 300}  ]'

@description('The name of the Log Analytics resource')
param logAnalyticsName string

@description('The name of the Application Insights resource')
param appInsightName string

param apimDiagnosticsName string = 'apimDiagnostics'


var resourceSuffix = uniqueString(subscription().id, resourceGroup().id)

resource cognitiveServices 'Microsoft.CognitiveServices/accounts@2021-10-01' = [for config in openAIConfig: if(length(openAIConfig) > 0) {
  name: '${config.name}-${resourceSuffix}'
  location: config.location
  sku: {
    name: openAISku
  }
  kind: 'OpenAI'  
  properties: {
    apiProperties: {
      statisticsEnabled: false
    }
    customSubDomainName: toLower('${config.name}-${resourceSuffix}')
  }
}]

resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01'  =  [for (config, i) in openAIConfig: if(length(openAIConfig) > 0) {
    name: openAIDeploymentName
    parent: cognitiveServices[i]
    properties: {
      model: {
        format: 'OpenAI'
        name: openAIModelName
        version: openAIModelVersion
      }
    }
    sku: {
        name: 'Standard'
        capacity: openAIModelCapacity
    }
}]

resource apimService 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: '${apimResourceName}-${resourceSuffix}'
  location: apimResourceLocation
  sku: {
    name: apimSku
    capacity: (apimSku == 'Consumption') ? 0 : ((apimSku == 'Developer') ? 1 : apimSkuCount)
  }
  properties: {
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
  }
  identity: {
    type: 'SystemAssigned'
  } 
}

var roleDefinitionID = resourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (config, i) in openAIConfig: if(length(openAIConfig) > 0) {
    scope: cognitiveServices[i]
    name: guid(subscription().id, resourceGroup().id, config.name, roleDefinitionID)
    properties: {
        roleDefinitionId: roleDefinitionID
        principalId: apimService.identity.principalId
        principalType: 'ServicePrincipal'
    }
}]

resource api 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
    name: openAIAPIName
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

resource backendOpenAI 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = [for (config, i) in openAIConfig: if(length(openAIConfig) > 0) {
  name: config.name
  parent: apimService
  properties: {
    description: 'backend description'
    url: '${cognitiveServices[i].properties.endpoint}/openai'
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
}]

// resource backendMock 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = [for (mock, i) in mockWebApps: if(length(openAIConfig) == 0 && length(mockWebApps) > 0) {
//   name: mock.name
//   parent: apimService
//   properties: {
//     description: 'backend description'
//     url: '${mock.endpoint}/openai'
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
//           name: 'mockBreakerRule'
//           tripDuration: 'PT1M'
//         }
//       ]
//     }    
//   }
// }]

resource backendPoolOpenAI 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = if(length(openAIConfig) > 1) {
  name: openAIBackendPoolName
  parent: apimService
  properties: {
    description: openAIBackendPoolDescription
    type: 'Pool'
//    protocol: 'http'  // the protocol is not needed in the Pool type
//    url: '${cognitiveServices[0].properties.endpoint}/openai'   // the url is not needed in the Pool type
    pool: {
      services: [for (config, i) in openAIConfig: {
          id: '/backends/${backendOpenAI[i].name}'
        }
      ]
    }
  }
}

// resource backendPoolMock 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = if(length(openAIConfig) == 0 && length(mockWebApps) > 1) {
//   name: mockBackendPoolName
//   parent: apimService
//   properties: {
//     description: mockBackendPoolDescription
//     type: 'Pool'
// //    protocol: 'http'  // the protocol is not needed in the Pool type
// //    url: '${mockWebApps[0].endpoint}/openai'   // the url is not needed in the Pool type
//     pool: {
//       services: [for (webApp, i) in mockWebApps: {
//           id: '/backends/${backendMock[i].name}'
//         }
//       ]
//     }
//   }
// }

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
resource namedValue 'Microsoft.ApiManagement/service/namedValues@2023-05-01-preview' = {
  name: openAILoadBalancingConfigName
  parent: apimService
  properties: {
    displayName: openAILoadBalancingConfigName
    secret: false
    value: openAILoadBalancingConfigValue
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
  name: logAnalyticsName
  location: apimResourceLocation
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
    publicNetworkAccessForIngestion: 'Disabled'
    publicNetworkAccessForQuery: 'Enabled'
  })
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightName
  location: apimResourceLocation
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    publicNetworkAccessForIngestion: 'Disabled'
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
]

resource symbolicname 'Microsoft.ApiManagement/service/apis/diagnostics@2023-09-01-preview'  = {
  name: 'applicationinsights'  
  parent: api
  properties: {
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

