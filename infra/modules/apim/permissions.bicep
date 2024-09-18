param apimPrincipalId string
param cognitiveServiceName string

resource cognitiveServices 'Microsoft.CognitiveServices/accounts@2021-10-01' existing = {
  name: cognitiveServiceName
}

var cognitiveServicesOpenAIUserResourceId = resourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
resource cognitiveServicesOpenAIUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
    scope: cognitiveServices
    name: guid(subscription().id, resourceGroup().id, cognitiveServices.name, cognitiveServicesOpenAIUserResourceId)
    properties: {
      roleDefinitionId: cognitiveServicesOpenAIUserResourceId
      principalId: apimPrincipalId
      principalType: 'ServicePrincipal'
    } 
}
