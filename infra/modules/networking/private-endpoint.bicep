param openaiName string
param openaiSubnetResourceId string
param location string
param privateDnsZoneId string

resource openai 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' existing = {
  name: openaiName
}

#disable-next-line BCP081
// resource privateDnsZone 'Microsoft.Network/privateDnsZones@2021-05-01' existing = {
//   name: 'privatelink.openai.azure.com'
// }

module openaiPrivateEndPoint 'br/public:avm/res/network/private-endpoint:0.7.1' = {
  name: '${openaiName}-private-endpoint-deployment'
  params: {
    name: '${openaiName}-pe'
    location: location
    subnetResourceId: openaiSubnetResourceId
    privateLinkServiceConnections: [
      {
        name: '${openaiName}-pe-connection'
        properties: {
          privateLinkServiceId: openai.id
          groupIds: ['account']
        }
      }
    ]
    privateDnsZoneGroup: {
      privateDnsZoneGroupConfigs: [
        {
          privateDnsZoneResourceId: privateDnsZoneId
        }
      ]
    }
  }
}
