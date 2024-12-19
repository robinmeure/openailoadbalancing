param apimServiceName string
param apiName string
param apimLoggerId string 

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: apimServiceName
}

resource api 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' existing = {
  parent: apim
  name: apiName
}


var headers = [
  'x-ratelimit-remaining-requests'
  'x-ratelimit-remaining-tokens'
  'consumed-tokens'
  'remaining-tokens'
  'prompt-tokens'
  'completion-tokens'
]

#disable-next-line BCP081
resource appInsightsDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2023-09-01-preview' = {
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
        headers:['x-client-id']
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
    loggerId: apimLoggerId
    metrics: true
    operationNameFormat: 'Name'
    sampling: {
      percentage: 100
      samplingType: 'fixed'
    }
    verbosity: 'information'
  }
}
