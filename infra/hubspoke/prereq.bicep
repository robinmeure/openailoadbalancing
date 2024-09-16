targetScope = 'subscription'

param location string = 'westeurope'
param subHub string = '0865ebb3-1889-4871-8119-562cc313d111'
param subSpoke string='0865ebb3-1889-4871-8119-562cc313d111'
param hubVnetName string = 'vnet-hub'
param hubVnetAddressPrefix string = '10.0.0.0/16'
param hubSubnetName string = 'subnet-apim'
param apimSubnetPrefix string = '10.0.1.0/24'
param hubRgName string = 'rg-hub1'
param spokeVnetName string = 'vnet-spoke'
param spokeVnetAddressPrefix string = '10.1.0.0/16'
param spokeSubnetName string = 'subnet-openai'
param openaiSubnetPrefix string = '10.1.1.0/24'
param spokeRgName string = 'rg-spoke1'
@description('The pricing tier of this API Management service')
@allowed([
  'Consumption'
  'Developer'
  'Basic'
  'BasicV2'
  'Standard'
  'StandardV2'
  'Premium'
])
param apimSku string = 'StandardV2'

var webServerFarmDelegation = [
  {
    name: 'Microsoft.Web/serverFarms'
    properties: {
      serviceName: 'Microsoft.Web/serverFarms'
    }
  }
]

module rgHub 'br/public:avm/res/resources/resource-group:0.4.0' = {
  name: 'hubRgDeployment'
  scope: subscription(subHub)
  params: {
    name: hubRgName
    location: location
  }
}

module rgSpoke 'br/public:avm/res/resources/resource-group:0.4.0' = {
  name: 'spokeRgDeployment'
  scope: subscription(subSpoke)
  params: {
    name: spokeRgName
    location: location
  }
}


module nsgApim 'br/public:avm/res/network/network-security-group:0.4.0' = {
  dependsOn: [rgHub]
  name: 'nsg-apim-deployment'
  scope: resourceGroup(hubRgName)
  params: {
    name: 'nsg-apim'
    location: location
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
  dependsOn: [rgSpoke]
  name: 'nsg-openai-deployment'
  scope: resourceGroup(spokeRgName)
  params: {
    name: 'nsg-openai'
    location: location
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

module hubVirtualNetwork 'br/public:avm/res/network/virtual-network:0.2.0' = {
  name: 'hubVirtualNetworkDeployment'
  scope: resourceGroup(hubRgName)
  params: {
    name: hubVnetName
    location: location
    addressPrefixes: [
      hubVnetAddressPrefix
    ]
    subnets: [
      {
        name: hubSubnetName
        addressPrefix: apimSubnetPrefix
        delegations: toLower(apimSku) == 'standardv2' ? webServerFarmDelegation : []
        networkSecurityGroupResourceId: nsgApim.outputs.resourceId
      }
    ]
  }
}

module spokeVirtualNetwork 'br/public:avm/res/network/virtual-network:0.2.0' = {
  name: 'spokeVirtualNetworkDeployment'
  scope: resourceGroup(spokeRgName)
  params: {
    name: spokeVnetName
    location: location
    addressPrefixes: [
      spokeVnetAddressPrefix
    ]
    subnets: [
      {
        name: spokeSubnetName
        addressPrefix: openaiSubnetPrefix
        networkSecurityGroupResourceId: nsgOpenAI.outputs.resourceId
      }
    ]
  }
}

module dns 'br/public:avm/res/network/private-dns-zone:0.5.0' = {
  name: 'dns-deployment'
  scope: resourceGroup(hubRgName)
  params: {
    name: 'privatelink.openai.azure.com'
    virtualNetworkLinks: [
      {
        name: 'hub-link'
        virtualNetworkResourceId: hubVirtualNetwork.outputs.resourceId
      }
      {
        name: 'spoke-link'
        virtualNetworkResourceId: spokeVirtualNetwork.outputs.resourceId
      }
    ]

  }
}


module peerSpokeToHub '../modules/networking/vnetpeering.bicep' = {
  name: 'peerSpokeToHub'
  scope: resourceGroup(spokeRgName)
  params: {
    name: 'spokeToHub'
    virtualNetworkName: spokeVnetName
    remoteVirtualNetworkResourceId: hubVirtualNetwork.outputs.resourceId
  }
}

module peerHubToSpoke '../modules/networking/vnetpeering.bicep' = {
  name: 'peerSpokeToHub'
  scope: resourceGroup(hubRgName)
  params: {
    name: 'hubToSpoke'
    virtualNetworkName: hubVnetName
    remoteVirtualNetworkResourceId: spokeVirtualNetwork.outputs.resourceId
  }
}


