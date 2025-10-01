# Azure AI Landing Zone Networking Architecture

## Overview

The Azure AI Landing Zone implements a comprehensive networking architecture designed to provide secure, private connectivity between applications and Azure AI services. This architecture ensures that data flows through private networks, reducing exposure to the public internet while maintaining performance and scalability.

## Core Networking Principles

### 1. **Zero Trust Network Architecture**
- All network traffic is considered untrusted by default
- Explicit verification is required for every transaction
- Principle of least privilege access

### 2. **Private Connectivity**
- Azure services are accessed through private endpoints
- No public IP addresses for backend services
- All traffic flows through private networks

### 3. **Network Segmentation**
- Logical separation of different application tiers
- Network Security Groups (NSGs) control traffic flow
- Subnets isolate different workload components

### 4. **DNS Resolution Control**
- Private DNS zones manage name resolution
- Custom DNS settings for private endpoints
- Consistent naming across environments

## High-Level Architecture Components

```
┌─────────────────────────────────────────────────────────────────┐
│                        Internet/External Users                  │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│                 Application Gateway / Front Door                │
│                    (Public Endpoint)                           │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│                   Virtual Network (VNet)                       │
│  ┌─────────────────┐    ┌─────────────────┐                   │
│  │  Web App Subnet │    │  AI Services    │                   │
│  │                 │    │    Subnet       │                   │
│  │  ┌───────────┐  │    │                 │                   │
│  │  │ Web App   │──┼────┼──┐              │                   │
│  │  │Container  │  │    │  │              │                   │
│  │  └───────────┘  │    │  │              │                   │
│  └─────────────────┘    └──┼──────────────┘                   │
│                            │                                   │
│  ┌─────────────────────────▼───────────────────────────────┐   │
│  │              Private Endpoints Subnet                  │   │
│  │  ┌──────────┐  ┌──────────┐  ┌─────────────────────┐   │   │
│  │  │   AI     │  │ Storage  │  │    Other Azure      │   │   │
│  │  │ Foundry  │  │ Account  │  │     Services        │   │   │
│  │  │ Endpoint │  │ Endpoint │  │    Endpoints        │   │   │
│  │  └──────────┘  └──────────┘  └─────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Key Benefits

### **Security**
- Traffic never traverses the public internet for backend communications
- Network-level isolation and access controls
- Centralized logging and monitoring of network traffic

### **Performance**
- Reduced latency through Azure backbone network
- Optimized routing between Azure services
- Bandwidth efficiency through private connectivity

### **Compliance**
- Meets requirements for data residency and privacy
- Audit trails for all network communications
- Supports various compliance frameworks (SOC, ISO, HIPAA, etc.)

### **Scalability**
- Elastic scaling of network resources
- Load balancing and traffic distribution
- Multi-region deployment capabilities

## Network Flow Patterns

### **North-South Traffic**
- External users → Application Gateway → Web Application
- Managed through public endpoints with WAF protection

### **East-West Traffic**
- Web Application → Azure AI Services
- All traffic flows through private endpoints within the VNet

### **Management Traffic**
- Administrative access through Azure Bastion or VPN Gateway
- Separate management plane connectivity

## Integration with Azure Services

The networking architecture integrates seamlessly with:

- **Azure AI Foundry**: Private endpoint connectivity
- **Azure OpenAI**: Secure API access through private networks
- **Azure Storage**: Private blob and file storage access
- **Azure Key Vault**: Secure secrets management
- **Azure Monitor**: Centralized logging and monitoring
- **Azure Container Apps**: Secure container hosting

## AI Foundry Projects: Key Differences from Standard Hub-Spoke Configurations

### **Azure AI Foundry Project Architecture (vs Hub-Based Projects)**

**Fundamental Differences:**
- **Standalone Project Model**: Azure AI Foundry projects are managed under an Azure AI Foundry resource, not requiring a separate hub
- **No Managed Virtual Network Support**: Unlike hub-based projects, AI Foundry projects do **not** support managed virtual networks
- **Customer-Managed Network Architecture**: Projects require you to bring your own VNet infrastructure and manage private endpoints manually
- **Agent Service Isolation**: Standard Agents require dedicated network-secured environments with specific resource connectivity patterns

**Reference**: [What is Azure AI Foundry?](https://learn.microsoft.com/en-us/azure/ai-foundry/what-is-azure-ai-foundry#types-of-projects)

### **AI Foundry Project Networking Requirements**

**End-to-End Network Security Architecture:**
- **Individual Private Endpoints Required**: Each Azure resource needs its own private endpoint:
  - Azure AI Foundry resource
  - Azure Storage Account (for agent file storage)
  - Azure AI Search resource (for vector search)
  - Cosmos DB resource (for conversation/thread storage)
  - Azure OpenAI/AI Services (for model access)
- **Public Network Access Disabled**: All resources must have PNA flag set to `Disabled`
- **No Automatic Configuration**: Unlike hub-based projects, you must manually configure all networking components

**Reference**: [How to configure a private link for Azure AI Foundry (Foundry projects)](https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/configure-private-link#end-to-end-secured-networking-for-agent-service)

### **Private IP Address Requirements**

**Unique Considerations for AI Workloads:**
- **High IP Address Consumption**: AI workloads require one private IP per compute instance, compute cluster node, and private endpoint
- **Hub-Spoke IP Shortage**: Your existing hub-spoke network may not have sufficient IP address space for large-scale AI deployments
- **Recommended Architecture**: Consider isolated, non-peered VNets for AI Foundry resources with dedicated large address spaces (e.g., /16 or /20 ranges)
- **Double Private Endpoints**: Isolated network architecture requires private endpoints in both your main VNet and AI-dedicated VNet

**Reference**: [Plan for network isolation in Azure Machine Learning](https://learn.microsoft.com/en-us/azure/machine-learning/how-to-network-isolation-planning?view=azureml-api-2#key-considerations)

### **AI Foundry Project Connection Management**

**Project-Scoped vs Resource-Scoped Connections:**
- **Project-Level Isolation**: AI Foundry projects support project-scoped connections for sensitive integrations
- **Identity Management**: Connections act as identity brokers using managed identities or service principals
- **Network Isolation Requirements**: When using private endpoints, ensure:
  - DNS resolution configured for all project subnets
  - Managed identity has network access to target resources
  - Firewall rules include necessary IP ranges or managed identity access

**Authentication Flexibility:**
- **Shared Access Tokens**: Managed identities or API keys for simplified management
- **User Token Passthrough**: Entra ID passthrough for granular control over sensitive data access
- **Connection Scoping**: Choose between resource-level (shared) or project-level (isolated) connections

**Reference**: [Add a new connection to your project (Foundry projects)](https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/connections-add#network-isolation)

### **Azure AI Search Advanced Networking**

**Shared Private Links (Premium Feature):**
- **S2 Tier Requirement**: Shared private links only available with S2 pricing tier
- **Outbound Private Connectivity**: Allows AI Search to securely connect to resources in customer VNets
- **Resource-Specific Group IDs**: Different Azure resources require specific group IDs (e.g., `openai_account` for OpenAI, `Sql` for Cosmos DB)
- **Trusted Service Bypass**: Can bypass trusted service requirements when using shared private links

**Reference**: [Make outbound connections through a shared private link](https://learn.microsoft.com/en-us/azure/search/search-indexer-howto-access-private)

### **Azure OpenAI Data Architecture**

**Three-Subnet Pattern for "On Your Data" Scenarios:**
1. **VPN Gateway Subnet**: For connectivity to on-premises or other networks
2. **Private Endpoints Subnet**: Dedicated subnet for private endpoints to Azure services
3. **Web App Integration Subnet**: Empty subnet reserved for application outbound VNet integration

**Trusted Service Configuration:**
- **Network ACLs Bypass**: Set `networkAcls.bypass` to `AzureServices` for AI Search to access OpenAI
- **Managed Identity Authentication**: Required for trusted service access between AI services
- **Custom Subdomain Requirement**: Essential for Microsoft Entra ID authentication and private DNS zones

**Reference**: [Network and access configuration for Azure OpenAI On Your Data](https://learn.microsoft.com/en-us/azure/ai-foundry/openai/how-to/on-your-data-configuration)

### **AI Agent Service Networking (Standard Agents)**

**Network-Secured Agent Deployment:**
- **Bicep Template Deployment Only**: Network-secured agents must be deployed via Bicep templates
- **Standard Agent Requirement**: Only Standard Agents support network security (not Light Agents)
- **VNet Injection Required**: Agents require bring-your-own virtual network with proper subnet delegation
- **No Managed VNet Support**: Agent Service does not support managed virtual networks

**Agent-Specific Limitations:**
- **Evaluation Services**: AI Foundry evaluations currently not supported with VNet injection
- **Trusted Service Access**: Only Azure AI Search has trusted service access to Azure OpenAI for agent scenarios
- **Resource Provider Integration**: Agent networking requires `Microsoft.Search` resource provider access

**Reference**: [How to configure a private link for Azure AI Foundry (Foundry projects)](https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/configure-private-link#limitations)

### **Key Architectural Recommendations for AI Foundry Projects**

1. **Customer-Managed VNet Strategy**: Unlike hub-spoke automation, plan for manual VNet and private endpoint management
2. **Resource-Per-Endpoint Architecture**: Each AI service requires individual private endpoint configuration
3. **Agent Subnet Planning**: Dedicated subnets required for Standard Agent deployments with proper delegation
4. **Connection Scoping Strategy**: Choose appropriate connection scoping (project vs resource level) based on security requirements
5. **DNS and Identity Management**: Implement comprehensive DNS resolution and managed identity access patterns
6. **Hub-Spoke Integration**: AI Foundry projects can integrate with existing hub-spoke through private endpoints but require additional planning

## Next Steps

- [Detailed Networking Components](./networking-components.md)
- [Networking Configuration Guide](./networking-configuration.md)
- [Traffic Flow Analysis](./networking-traffic-flow.md)
- [Troubleshooting Network Issues](../troubleshooting/networking-troubleshooting.md)

## Related Documentation

### Internal Guides
- [Detailed Networking Components](./networking-components.md)
- [Networking Configuration Guide](./networking-configuration.md)
- [Traffic Flow Analysis](./networking-traffic-flow.md)
- [Troubleshooting Network Issues](../troubleshooting/networking-troubleshooting.md)

### Microsoft Documentation References

#### Core Networking
- [Azure Virtual Network Documentation](https://docs.microsoft.com/en-us/azure/virtual-network/)
- [Virtual Network Planning and Design](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-vnet-plan-design-arm)
- [Azure Network Security Overview](https://docs.microsoft.com/en-us/azure/security/fundamentals/network-overview)
- [Azure Networking Best Practices](https://docs.microsoft.com/en-us/azure/security/fundamentals/network-best-practices)

#### Private Connectivity
- [Azure Private Link Documentation](https://docs.microsoft.com/en-us/azure/private-link/)
- [Private Endpoints Overview](https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-overview)
- [Private Link Service](https://docs.microsoft.com/en-us/azure/private-link/private-link-service-overview)
- [Private Link FAQ](https://docs.microsoft.com/en-us/azure/private-link/private-link-faq)

#### Security and Access Control
- [Azure Network Security Groups](https://docs.microsoft.com/en-us/azure/virtual-network/network-security-groups-overview)
- [Azure Web Application Firewall](https://docs.microsoft.com/en-us/azure/web-application-firewall/)
- [Zero Trust Network Architecture](https://docs.microsoft.com/en-us/security/zero-trust/deploy/networks)
- [Application Security Groups](https://docs.microsoft.com/en-us/azure/virtual-network/application-security-groups)

#### DNS and Name Resolution
- [Azure Private DNS](https://docs.microsoft.com/en-us/azure/dns/private-dns-overview)
- [Name Resolution for VMs and Cloud Services](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-name-resolution-for-vms-and-role-instances)
- [Private DNS Zone Scenarios](https://docs.microsoft.com/en-us/azure/dns/private-dns-scenarios)

#### Load Balancing and Traffic Management
- [Azure Application Gateway](https://docs.microsoft.com/en-us/azure/application-gateway/)
- [Azure Load Balancer](https://docs.microsoft.com/en-us/azure/load-balancer/)
- [Azure Front Door](https://docs.microsoft.com/en-us/azure/frontdoor/)

#### AI Services Networking

**Core AI Services Private Connectivity**
- [Configure Azure AI services virtual networks](https://learn.microsoft.com/en-us/azure/ai-services/cognitive-services-virtual-networks) - Essential differences between private endpoints and service endpoints for AI services
- [Azure OpenAI Service Virtual Networks](https://docs.microsoft.com/en-us/azure/cognitive-services/openai/how-to/use-your-data-securely)
- [Network and access configuration for Azure OpenAI On Your Data](https://learn.microsoft.com/en-us/azure/ai-foundry/openai/how-to/on-your-data-configuration) - Specific VNet architecture for AI data ingestion
- [Configure Azure OpenAI networking](https://learn.microsoft.com/en-us/azure/ai-foundry/openai/how-to/network) - Hub-spoke architecture considerations for OpenAI

**Azure AI Foundry Project Networking (Customer-Managed Networks)**
- [How to configure a private link for Azure AI Foundry (Foundry projects)](https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/configure-private-link) - **Primary**: Project-focused private endpoint configuration and Agent Service architecture
- [Add a new connection to your project (Foundry projects)](https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/connections-add) - Project connection networking requirements and private endpoint setup
- [Configure secure networking for Azure AI platform services](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/platform/networking) - Enterprise AI networking patterns and private endpoint strategy

**Azure AI Foundry Hub-Based Projects (Managed Networks)**
- [How to set up a managed network for Azure AI Foundry hubs](https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/configure-managed-network) - **Critical**: Managed VNet isolation modes and limitations
- [How to configure a private link for Azure AI Foundry](https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/hub-configure-private-link) - Hub-focused private endpoint configuration
- [How to create a secure Azure AI Foundry hub and project with a managed virtual network](https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/create-secure-ai-hub) - Complete secure deployment guide

**AI Compute and Training Environment Networking**
- [Secure an Azure Machine Learning training environment with virtual networks](https://learn.microsoft.com/en-us/azure/machine-learning/how-to-secure-training-vnet?view=azureml-api-2) - **Important**: No public IP requirements and subnet restrictions
- [Plan for network isolation in Azure Machine Learning](https://learn.microsoft.com/en-us/azure/machine-learning/how-to-network-isolation-planning?view=azureml-api-2) - Private IP shortage considerations for hub-spoke
- [Create an Azure Machine Learning compute instance](https://learn.microsoft.com/en-us/azure/machine-learning/how-to-create-compute-instance?view=azureml-api-2) - Compute-specific networking requirements

**Azure AI Search Networking (Advanced Configurations)**
- [Create a private endpoint for a secure connection to Azure AI Search](https://learn.microsoft.com/en-us/azure/search/service-create-private-endpoint)
- [Make outbound connections through a shared private link](https://learn.microsoft.com/en-us/azure/search/search-indexer-howto-access-private) - **Premium feature**: Shared private links for AI Search
- [Troubleshoot issues with shared private links in Azure AI Search](https://learn.microsoft.com/en-us/azure/search/troubleshoot-shared-private-link-resources)

**Enterprise AI Networking Patterns**
- [Access on-premises resources from your Azure AI Foundry's managed network](https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/access-on-premises-resources) - Application Gateway integration
- [Create a new network-secured environment with user-managed identity](https://learn.microsoft.com/en-us/azure/ai-foundry/agents/how-to/virtual-networks) - Agent-specific subnet requirements