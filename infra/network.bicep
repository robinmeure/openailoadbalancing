param vnetName string
param vnetAddressPrefix string
param apimSubnetPrefix string
param openaiSubnetPrefix string
param apimSku string

var webServerFarmDelegation = [
  {
    name: 'Microsoft.Web/serverFarms'
    properties: {
      serviceName: 'Microsoft.Web/serverFarms'
    }
  }
]

module nsgApim 'br/public:avm/res/network/network-security-group:0.4.0' = {
  name: 'nsg-apim-deployment'
  params: {
    name: 'nsg-apim'
    securityRules: [
      {
        name: 'AllowClientToGateway'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 2721
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowAPIMPortal'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3443'
          sourceAddressPrefix: 'ApiManagement'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 2731
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowAPIMLoadBalancer'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '6390'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 2741
          direction: 'Inbound'
        }
      }
    ]
  }
}

module nsgOpenAI 'br/public:avm/res/network/network-security-group:0.4.0' = {
  name: 'nsg-openai-deployment'
  params: {
    name: 'nsg-openai'
    securityRules: [
      {
        name: 'AllowAPIM'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: apimSubnetPrefix
          destinationAddressPrefix: openaiSubnetPrefix
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

module virtualNetwork 'br/public:avm/res/network/virtual-network:0.2.0' = {
  name: 'virtualNetworkDeployment'
  params: {
    name: vnetName
    addressPrefixes: [
      vnetAddressPrefix
    ]
    subnets: [
      {
        name: 'sn-apim'
        addressPrefix: apimSubnetPrefix
        delegations: toLower(apimSku) == 'standardv2' ? webServerFarmDelegation : []
        networkSecurityGroupResourceId: nsgApim.outputs.resourceId
      }
      {
        name: 'sn-openai'
        addressPrefix: openaiSubnetPrefix
        networkSecurityGroupResourceId: nsgOpenAI.outputs.resourceId
      }
    ]
  }
}
