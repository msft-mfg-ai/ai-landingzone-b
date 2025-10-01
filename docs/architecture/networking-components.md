# Azure Networking Components for AI Landing Zones

## Overview

This guide provides detailed definitions and explanations of the key networking components used in Azure AI Landing Zones. Understanding these components is essential for implementing secure, scalable, and performant AI workloads.

## Core Networking Components

### 1. Virtual Network (VNet)

**Definition**: A virtual network is the fundamental building block for private networks in Azure. It enables Azure resources to securely communicate with each other, the internet, and on-premises networks.

**Purpose in AI Landing Zones**:
- Provides network isolation for AI workloads
- Enables private communication between services
- Supports network segmentation through subnets
- Allows integration with on-premises networks

**Key Properties**:
- **Address Space**: CIDR block defining the IP range (e.g., 10.0.0.0/16)
- **Location**: Azure region where the VNet is deployed
- **Subscription**: Azure subscription containing the VNet
- **Resource Group**: Logical container for the VNet

### 2. Subnets

**Definition**: Subnets enable you to segment the virtual network into one or more sub-networks and allocate a portion of the virtual network's address space to each subnet.

**AI Landing Zone Subnet Types**:

#### **Application Subnet**
- **Purpose**: Hosts web applications and frontend services
- **Typical CIDR**: 10.0.1.0/24
- **Resources**: Container Apps, App Services, Virtual Machines

#### **Private Endpoints Subnet**
- **Purpose**: Hosts private endpoints for Azure services
- **Typical CIDR**: 10.0.2.0/24
- **Resources**: Private endpoints for AI services, storage, databases

#### **Management Subnet**
- **Purpose**: Administrative and monitoring resources
- **Typical CIDR**: 10.0.3.0/24
- **Resources**: Azure Bastion, monitoring agents, management VMs

#### **Gateway Subnet**
- **Purpose**: VPN and ExpressRoute gateways
- **Required Name**: "GatewaySubnet"
- **Typical CIDR**: 10.0.0.0/27

## Private Connectivity Components

### 3. Private Link

**Definition**: Azure Private Link enables you to access Azure PaaS Services and Azure hosted customer/partner services over a private endpoint in your virtual network.

**Key Concepts**:
- **Private Endpoint**: Network interface that connects privately and securely to a service
- **Private Link Service**: Service powered by Azure Private Link
- **Private Connection**: Secure connection between private endpoint and service

**Benefits**:
- Traffic travels over Microsoft backbone network
- No public IP addresses required
- Protection against data exfiltration
- Simplified network architecture

### 4. Private Endpoints

**Definition**: A private endpoint is a network interface that uses a private IP address from your virtual network, connecting you privately and securely to Azure services.

**AI Services Supported**:
- Azure OpenAI Service
- Azure AI Search (Cognitive Search)
- Azure Machine Learning
- Azure Storage (Blob, File, Queue, Table)
- Azure Key Vault
- Azure Container Registry
- Azure Cosmos DB

**Components**:
- **Network Interface**: Virtual NIC with private IP
- **Private IP Address**: IP from your VNet address space
- **FQDN**: Fully qualified domain name for the service

### 5. Private DNS Zones

**Definition**: Azure Private DNS provides a reliable and secure DNS service to manage and resolve domain names in a virtual network without the need to add a custom DNS solution.

**Purpose**:
- Resolve private endpoint FQDNs to private IP addresses
- Maintain DNS consistency across environments
- Support custom domain name resolution

**Common Private DNS Zones for AI Workloads**:

```
privatelink.openai.azure.com              # Azure OpenAI
privatelink.search.windows.net            # Azure AI Search
privatelink.api.azureml.ms                # Azure Machine Learning
privatelink.blob.core.windows.net         # Azure Storage Blob
privatelink.file.core.windows.net         # Azure Storage File
privatelink.vault.azure.net               # Azure Key Vault
privatelink.azurecr.io                    # Azure Container Registry
privatelink.documents.azure.com           # Azure Cosmos DB
```

## Security and Access Control

### 6. Network Security Groups (NSGs)

**Definition**: Network security groups filter network traffic to and from Azure resources in an Azure virtual network using security rules.

**Components**:
- **Security Rules**: Allow or deny traffic based on multiple criteria
- **Default Rules**: System-defined rules that cannot be removed
- **Custom Rules**: User-defined rules with higher priority

**Rule Properties**:
- **Priority**: 100-4096 (lower numbers have higher priority)
- **Source/Destination**: IP addresses, service tags, or application security groups
- **Protocol**: TCP, UDP, ICMP, ESP, AH, or Any
- **Port Range**: Specific ports or ranges
- **Action**: Allow or Deny

**AI Landing Zone NSG Patterns**:

#### **Web Application Subnet NSG**
```
Priority 100: Allow HTTPS (443) from Internet
Priority 110: Allow HTTP (80) from Internet
Priority 200: Allow AI Service APIs to Private Endpoints
Priority 300: Allow Azure Monitor communication
Priority 400: Deny all other inbound traffic
```

#### **Private Endpoints Subnet NSG**
```
Priority 100: Allow HTTPS (443) from Application Subnet
Priority 110: Allow specific AI service ports
Priority 200: Allow management traffic from Management Subnet
Priority 300: Deny all other traffic
```

### 7. Application Security Groups (ASGs)

**Definition**: Application security groups enable you to configure network security as a natural extension of an application's structure, allowing you to group virtual machines and define network security policies based on those groups.

**Benefits**:
- Simplify security rule management
- Reduce rule complexity and maintenance
- Enable application-centric security policies
- Support micro-segmentation patterns

**AI Landing Zone ASG Examples**:
- **WebTier-ASG**: Web application containers
- **AIServices-ASG**: AI and ML service endpoints
- **Data-ASG**: Storage and database endpoints
- **Management-ASG**: Administrative and monitoring resources

## DNS and Name Resolution

### 8. DNS Resolution Flow

**Private Endpoint DNS Resolution**:
1. Client queries for service FQDN (e.g., `myaiservice.openai.azure.com`)
2. Azure DNS forwards query to private DNS zone
3. Private DNS zone returns private IP address
4. Client connects to private endpoint using private IP

**Configuration Requirements**:
- Private DNS zone linked to VNet
- A records pointing to private endpoint IPs
- Conditional forwarding for hybrid scenarios

### 9. Custom DNS Settings

**Options**:
- **Azure-provided DNS**: Default 168.63.129.16
- **Custom DNS Servers**: On-premises or Azure-hosted
- **Hybrid DNS**: Combination of Azure and custom DNS

**Considerations**:
- Conditional forwarding for private zones
- DNS caching and TTL settings
- Failover and redundancy planning

## Load Balancing and Traffic Distribution

### 10. Azure Load Balancer

**Definition**: Azure Load Balancer operates at layer 4 (TCP, UDP) and distributes inbound flows to healthy service instances.

**Types**:
- **Public Load Balancer**: Internet-facing traffic distribution
- **Internal Load Balancer**: Private network traffic distribution

### 11. Application Gateway

**Definition**: Application Gateway is a web traffic load balancer that operates at layer 7 (HTTP/HTTPS) and provides advanced routing capabilities.

**Features for AI Workloads**:
- **Web Application Firewall (WAF)**: Protection against common attacks
- **SSL Termination**: Centralized certificate management
- **URL-based Routing**: Route to different backend pools
- **Multi-site Hosting**: Support multiple domains

## Monitoring and Diagnostics

### 12. Network Watcher

**Definition**: Azure Network Watcher provides tools to monitor, diagnose, and gain insights into network performance and health.

**Key Features**:
- **Connection Monitor**: End-to-end connectivity monitoring
- **Flow Logs**: NSG traffic analysis
- **Packet Capture**: Network troubleshooting
- **Topology**: Network relationship visualization

### 13. VNet Flow Logs

**Definition**: Virtual network flow logs capture information about IP traffic flowing through a virtual network.

**Use Cases**:
- Security analysis and threat detection
- Network performance optimization
- Compliance and audit requirements
- Troubleshooting connectivity issues

## Best Practices

### Design Principles
1. **Plan IP Address Space**: Use non-overlapping CIDR blocks
2. **Implement Defense in Depth**: Multiple security layers
3. **Use Private Endpoints**: Eliminate public access where possible
4. **Segment Networks**: Separate different application tiers
5. **Monitor Everything**: Comprehensive logging and monitoring

### Security Recommendations
1. **Least Privilege Access**: Minimal required permissions
2. **Regular Security Reviews**: Periodic assessment of rules
3. **Automated Deployment**: Infrastructure as Code for consistency
4. **Encryption in Transit**: All communications encrypted
5. **Network Micro-segmentation**: Granular access controls

## Related Resources

### Internal Guides
- [Networking Configuration Guide](./networking-configuration.md)
- [Traffic Flow Analysis](./networking-traffic-flow.md)
- [Security Best Practices](../security/network-security.md)
- [Troubleshooting Guide](../troubleshooting/networking-troubleshooting.md)

### Microsoft Documentation References

#### Virtual Networks and Subnets
- [Azure Virtual Network Documentation](https://docs.microsoft.com/en-us/azure/virtual-network/)
- [Create, change, or delete a virtual network](https://docs.microsoft.com/en-us/azure/virtual-network/manage-virtual-network)
- [Add, change, or delete a virtual network subnet](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-manage-subnet)
- [Virtual Network Service Endpoints](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-service-endpoints-overview)

#### Private Link and Private Endpoints
- [Azure Private Link Documentation](https://docs.microsoft.com/en-us/azure/private-link/)
- [Create a private endpoint](https://docs.microsoft.com/en-us/azure/private-link/create-private-endpoint-portal)
- [Private endpoint DNS configuration](https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-dns)
- [Troubleshoot private endpoint connectivity problems](https://docs.microsoft.com/en-us/azure/private-link/troubleshoot-private-endpoint-connectivity)
- [Private Link service overview](https://docs.microsoft.com/en-us/azure/private-link/private-link-service-overview)

#### Network Security
- [Network Security Groups](https://docs.microsoft.com/en-us/azure/virtual-network/network-security-groups-overview)
- [How network security groups filter network traffic](https://docs.microsoft.com/en-us/azure/virtual-network/network-security-group-how-it-works)
- [Application Security Groups](https://docs.microsoft.com/en-us/azure/virtual-network/application-security-groups)
- [Create, change, or delete a network security group](https://docs.microsoft.com/en-us/azure/virtual-network/manage-network-security-group)

#### DNS and Name Resolution
- [Azure Private DNS zones](https://docs.microsoft.com/en-us/azure/dns/private-dns-overview)
- [Create an Azure private DNS zone](https://docs.microsoft.com/en-us/azure/dns/private-dns-getstarted-portal)
- [Name resolution for resources in Azure virtual networks](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-name-resolution-for-vms-and-role-instances)
- [What is Azure DNS?](https://docs.microsoft.com/en-us/azure/dns/dns-overview)

#### Load Balancing and Traffic Distribution
- [Azure Load Balancer overview](https://docs.microsoft.com/en-us/azure/load-balancer/load-balancer-overview)
- [Azure Application Gateway overview](https://docs.microsoft.com/en-us/azure/application-gateway/overview)
- [What is Azure Front Door?](https://docs.microsoft.com/en-us/azure/frontdoor/front-door-overview)
- [Load balancing options](https://docs.microsoft.com/en-us/azure/architecture/guide/technology-choices/load-balancing-overview)

#### Monitoring and Diagnostics
- [Azure Network Watcher](https://docs.microsoft.com/en-us/azure/network-watcher/network-watcher-monitoring-overview)
- [NSG flow logs](https://docs.microsoft.com/en-us/azure/network-watcher/network-watcher-nsg-flow-logging-overview)
- [Connection monitor](https://docs.microsoft.com/en-us/azure/network-watcher/connection-monitor-overview)
- [VNet flow logs](https://docs.microsoft.com/en-us/azure/network-watcher/vnet-flow-logs-overview)

#### AI Services Networking
- [Azure Cognitive Services virtual networks](https://docs.microsoft.com/en-us/azure/cognitive-services/cognitive-services-virtual-networks)
- [Azure OpenAI Service data, privacy, and security](https://docs.microsoft.com/en-us/legal/cognitive-services/openai/data-privacy)
- [Azure AI Search security](https://docs.microsoft.com/en-us/azure/search/search-security-overview)
- [Azure Machine Learning network isolation and security](https://docs.microsoft.com/en-us/azure/machine-learning/how-to-network-security-overview)