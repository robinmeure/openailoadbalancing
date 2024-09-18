param apimServiceName string

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: apimServiceName
}

resource apiFinanceSubscription 'Microsoft.ApiManagement/service/subscriptions@2023-03-01-preview' = {
  parent: apim
  name: 'finance-dept-subscription'
  properties: {
    scope: '/apis'
    displayName: 'Finance'
    state: 'active'
    allowTracing: true
  }
}

resource apiMarketingSubscription 'Microsoft.ApiManagement/service/subscriptions@2023-03-01-preview' = {
  parent: apim
  name: 'marketing-dept-subscription'
  properties: {
    scope: '/apis'
    displayName: 'Marketing'
    state: 'active'
    allowTracing: true
  }
}
