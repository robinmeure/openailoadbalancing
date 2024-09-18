param openAIConfig array
param openAISku string
param resourceSuffix string
param openAIDeploymentName string
param openAIModelName string
param openAIModelVersion string
param openAIModelCapacity int

resource cognitiveServices 'Microsoft.CognitiveServices/accounts@2021-10-01' = [
  for config in openAIConfig: if (length(openAIConfig) > 0) {
    name: '${config.name}-${config.location}-${resourceSuffix}'
    location: config.location
    sku: {
      name: openAISku
    }
    kind: 'OpenAI'
    properties: {
      disableLocalAuth: true
      publicNetworkAccess: 'Disabled'
      networkAcls: {defaultAction: 'Deny'}
      apiProperties: {
        statisticsEnabled: false
      }
      customSubDomainName: toLower('${config.name}-${config.location}-${resourceSuffix}')
    }
  }
]

resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = [
  for (config, i) in openAIConfig: if (length(openAIConfig) > 0) {
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
  }
]

// Output the endpoints of the deployed cognitive services
output endpoints array = [
  for (config, i) in openAIConfig: {
    endpoint: cognitiveServices[i].properties.endpoint
    name: cognitiveServices[i].name
  }
]

