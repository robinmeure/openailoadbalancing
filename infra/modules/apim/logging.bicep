param apimServiceName string
param applicationInsightsId string
param applicationInsightsKey string

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: apimServiceName
}

resource apimLogger 'Microsoft.ApiManagement/service/loggers@2021-12-01-preview' = {
  name: 'appinsights-logger'
  parent: apim
  properties: {
    credentials: {
      instrumentationKey: applicationInsightsKey
    }
    description: 'Logger to Azure Application Insights'
    isBuffered: false
    loggerType: 'applicationInsights'
    resourceId: applicationInsightsId
  }
}

output apimLoggerId string = apimLogger.id
