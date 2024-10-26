param openAIConfig array
param resourceSuffix string

resource cognitiveServices 'Microsoft.CognitiveServices/accounts@2021-10-01' = [
  for config in openAIConfig: if (length(openAIConfig) > 0) {
    #disable-next-line BCP334
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

// Output the endpoints of the deployed cognitive services
output endpoints array = [
  for (config, i) in openAIConfig: {
    endpoint: cognitiveServices[i].properties.endpoint
    name: cognitiveServices[i].name
  }
]

