param name string
param virtualNetworkName string
param remoteVirtualNetworkResourceId string
param allowForwardedTraffic bool = false
param allowGatewayTransit bool = false
param allowVirtualNetworkAccess bool = true
param doNotVerifyRemoteGateways bool = false
param useRemoteGateways bool = false

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2020-11-01' existing = {
  name: virtualNetworkName
}   

resource virtualNetworkPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-01-01' = {
  name: name
  parent: virtualNetwork
  properties: {
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: allowGatewayTransit
    allowVirtualNetworkAccess: allowVirtualNetworkAccess
    doNotVerifyRemoteGateways: doNotVerifyRemoteGateways
    useRemoteGateways: useRemoteGateways
    remoteVirtualNetwork: {
      id: remoteVirtualNetworkResourceId
    }
  }
}
