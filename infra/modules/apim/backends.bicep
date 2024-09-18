param apimServiceName string 
param openAIConfig array 
param cognitiveServices array 
param openAIBackendPoolName string = 'openai-backend-pool'
param openAIBackendPoolDescription string = 'openai-backend-pool'

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: apimServiceName
}

#disable-next-line BCP081
resource backendOpenAI 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = [
  for (config, i) in openAIConfig: if (length(openAIConfig) > 0) {
    name: config.name
    parent: apim
    properties: {
      description: 'backend description'
      url: '${cognitiveServices[i].endpoint}openai'
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

#disable-next-line BCP081
resource backendPoolOpenAI 'Microsoft.ApiManagement/service/backends@2023-09-01-preview' = if (length(openAIConfig) > 1) {
  dependsOn: [
    for (config, i) in openAIConfig: backendOpenAI[i]
  ]
  name: openAIBackendPoolName
  parent: apim
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
