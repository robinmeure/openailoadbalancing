# APIM ❤️ Secured OpenAI

This repo is based upon the example [Advanced Load Balancing lab](https://github.com/Azure-Samples/AI-Gateway/blob/main/labs/advanced-load-balancing) and is enriched with a virtual network and managed identities to secure the endpoints.

## Key Features
- **Secure Access Management**: Best practices and configurations for managing secure access to Azure OpenAI Services.
- **Usage Monitoring & Cost Control**: Solutions for tracking the usage of Azure OpenAI Services to facilitate 
- **Load Balance**: Utilize & loadbalance the capacity of Azure OpenAI across regions or provisioned throughput (PTU)
- **Streaming requests**: Support for streaming requests to Azure OpenAI, for all features (e.g. additional logging and charge-back) accurate cost allocation and team charge-back.

## What does it provision?
- API Management instance acts as a load balancer with OpenAI endpoints being the backends.
- Creates a virtual network (VNet) to isolate the load balancer and backend resources.
- Deploys a public IP address for the load balancer.
- Configures a load balancer with backend pools and health probes.
- Sets up inbound and outbound rules for network traffic.
- Deploys an Application Insights and Log Analytics workspace to store the usage of the load balancer

## Usage

To deploy the load balancing infrastructure, follow these steps:

1. Install the Azure CLI and Bicep extension.
2. Open a terminal and navigate to the infra directory.
3. Run the command `az deployment group create -g <your resource group name> --template-file main.bicep --parameters main.parameters.json`.

## Dependencies

The `main.bicep` file may have dependencies on other Bicep or ARM templates. Make sure to resolve any dependencies before deploying.

## Customization

Feel free to modify the `main.bicep` file to suit your specific requirements. You can add or remove resources, adjust configurations, or integrate with other Azure services.

For more information, refer to the official Azure documentation on load balancing and Bicep.


# Option 2 - existing environment
When you have an existing environment that uses a hub and spoke model we've got you covered as well. In the infra folder, there is a hubspoke folder. The main.bicep will deploy the solution across subscriptions and resourcegroups. The assumption is that you have existing:
- resourcegroups
- virtual networks with subnets for API Management (in Hub vnet) and Azure OpenAI (in Spoke vnet)
- vnet's should be peered already and NSG's should allow the traffic flow.

You'll find all parameters in the main.param.json for hubspoke that you can edit to use with your specific values.

The <strong>prereq.bicep</strong> in the hubspoke version can be used to set up an environment if you do not have one. This will deploy the resources for hubspoke that are not in the main.bicep file.

Run the command `az deployment sub create --template-file main.bicep --parameters main.parameters.json` to deploy "hubspoke" from the hubspoke directory.
