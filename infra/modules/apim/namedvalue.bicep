param apimServiceName string
param openAILoadBalancingConfigName string
param openAILoadBalancingConfigValue string

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: apimServiceName
}


// advance-load-balancing: added a naned value resource
resource namedValue 'Microsoft.ApiManagement/service/namedValues@2023-05-01-preview' = {
  name: 'deploy-named-value'
  parent: apim
  properties: {
    displayName: openAILoadBalancingConfigName
    secret: false
    value: openAILoadBalancingConfigValue
  }
}
