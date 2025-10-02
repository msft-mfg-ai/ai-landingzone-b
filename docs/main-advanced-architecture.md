# Azure AI Landing Zone - Advanced Architecture (main-advanced.bicep)

## Overview
This document describes the architecture for the **Advanced Azure AI Landing Zone** deployment as defined in `main-advanced.bicep`. This configuration includes comprehensive private networking, security controls, and all components necessary for running AI agent applications.

## Architecture Diagram Components

### Network Architecture

#### Virtual Network (VNET)
- **Default Address Space**: `10.237.144.0/22` (configurable)
- **Resource**: Virtual Network with Network Security Groups
- **Subnets**:
  1. **Application Gateway Subnet** (`subnetAppGw`)
     - Default: `/24` - `10.237.145.0/24`
     - Purpose: Hosts Application Gateway for ingress traffic
  
  2. **App Service Environment Subnet** (`subnetAppSe`)
     - Default: `/24` - `10.237.144.0/24`
     - Purpose: Container Apps Environment
  
  3. **Private Endpoints Subnet** (`subnetPe`)
     - Default: `/27` - `10.237.146.0/27`
     - Purpose: Private endpoints for all Azure services
  
  4. **Agent Subnet** (`subnetAgent`)
     - Default: `/27` - `10.237.146.32/27`
     - Purpose: AI agent compute resources
  
  5. **Bastion Subnet** (`AzureBastionSubnet`)
     - Default: `/26` - `10.237.146.64/26`
     - Purpose: Azure Bastion for secure VM access
  
  6. **Jumpbox Subnet** (`subnetJumpbox`)
     - Default: `/28` - `10.237.146.128/28`
     - Purpose: Management jumpbox VMs
  
  7. **Training Subnet** (`subnetTraining`)
     - Default: `/25` - `10.237.147.0/25`
     - Purpose: ML training workloads
  
  8. **Scoring Subnet** (`subnetScoring`)
     - Default: `/25` - `10.237.147.128/25`
     - Purpose: ML inference/scoring workloads

#### DNS Configuration
- **Private DNS Zones**: Created for all Azure services
- **Zone Linking**: Linked to VNET for name resolution
- **Services with DNS Zones**:
  - Key Vault (`privatelink.vaultcore.azure.net`)
  - Azure OpenAI (`privatelink.openai.azure.com`)
  - AI Search (`privatelink.search.windows.net`)
  - Storage Account - Blob (`privatelink.blob.core.windows.net`)
  - Storage Account - Queue (`privatelink.queue.core.windows.net`)
  - Storage Account - Table (`privatelink.table.core.windows.net`)
  - Cosmos DB (`privatelink.documents.azure.com`)
  - Container Registry (`privatelink.azurecr.io`)
  - Container Apps (`privatelink.azurecontainerapps.io`)
  - Document Intelligence (`privatelink.cognitiveservices.azure.com`)

### Ingress Layer

#### Azure Bastion
- **Resource**: Azure Bastion Host (Standard SKU)
- **Purpose**: Secure RDP/SSH access to VMs without public IPs
- **Features**:
  - Tunneling enabled
  - File copy enabled
- **Subnet**: AzureBastionSubnet

#### Application Gateway (Optional)
- **Resource**: Application Gateway v2
- **SKU Options**: Standard_v2 or WAF_v2 (default)
- **Purpose**: Load balancing and WAF protection
- **Configuration**:
  - Autoscaling: Min 1, Max 10 instances (configurable)
  - HTTP/2 Support: Enabled
  - FIPS: Disabled (configurable)
  - Availability Zones: 1, 2, 3
- **Components**:
  - Public IP with DNS label
  - WAF Policy (OWASP 3.2 + Bot Manager 1.0)
  - Backend pools for Container Apps
  - SSL certificate from Key Vault (optional)
  - HTTP (80) and HTTPS (443) listeners
- **Monitoring**: Diagnostic settings to Log Analytics and Storage

### Compute & Application Layer

#### Virtual Machine Jumpbox (Optional)
- **Resource**: Windows VM (Standard_B2s_v2)
- **Purpose**: Management and access to private resources
- **OS Disk**: 128 GB
- **Network**: Connected to Jumpbox subnet with NSG
- **Access**: Via Azure Bastion
- **Configuration**: 
  - Admin credentials (parameters: `vm_username`, `vm_password`)
  - Public IP (optional for direct access)

#### Container Apps Environment
- **Resource**: Azure Container Apps Managed Environment
- **Purpose**: Hosts containerized AI agent applications
- **Configuration**:
  - Workload Profiles: D4 (1-10 instances)
  - Public Access: Configurable (`makeWebAppsPublic` parameter)
  - Private Endpoint: In PE subnet (if private)
- **Networking**:
  - Subnet: App Service Environment subnet
  - Internal Load Balancer: For private deployments
  - Custom DNS: For Container Apps domain
- **Monitoring**:
  - Application Insights integration
  - Log Analytics workspace

#### API Container App (Optional)
- **Resource**: Container App for API service
- **Configuration**:
  - Port: 8000
  - Workload Profile: Configurable
  - Registry: Azure Container Registry
  - Identity: User-assigned managed identity
- **Environment Variables**:
  - Application Insights connection string
  - AI Foundry project endpoint and ID
  - Cosmos DB settings
  - APIM settings (if deployed)
  - Entra ID settings (if configured)
- **Secrets** (from Key Vault):
  - API key
  - APIM key (if applicable)
  - Entra client ID/secret (if applicable)

#### UI Container App (Optional)
- **Resource**: Container App for UI service
- **Configuration**:
  - Port: 8001
  - Workload Profile: Configurable
  - Registry: Azure Container Registry
  - Identity: User-assigned managed identity
- **Environment Variables**:
  - Same as API Container App
  - API URL pointing to API Container App
- **Authentication**:
  - Entra ID integration (optional)
  - Redirect URI: `https://{appname}.{domain}/auth/callback`

#### Container Registry
- **Resource**: Azure Container Registry (Premium SKU)
- **Purpose**: Store container images for applications
- **Configuration**:
  - Public Access: Configurable
  - Private Endpoint: In PE subnet
  - Admin User: Disabled (uses managed identity)
- **Security**: Firewall rules for IP access

### AI & Cognitive Services Layer

#### Azure AI Foundry (OpenAI)
- **Resource**: Cognitive Services (OpenAI)
- **Purpose**: Host AI models for agent applications
- **Models Deployed**:
  1. **text-embedding-ada-002** (version 2)
     - Purpose: Text embeddings for semantic search
  
  2. **gpt-35-turbo** (version 0125)
     - Purpose: Conversational AI
  
  3. **GPT-4o** (default: `gpt-4o`)
     - Version: 2024-11-20 (configurable)
     - Capacity: 10 TPM (configurable)
     - SKU: Standard
  
  4. **GPT-4.1** (default: `gpt-4.1`)
     - Version: 2025-04-14 (configurable)
     - Capacity: 10 TPM (configurable)
     - SKU: GlobalStandard

- **Configuration**:
  - Local Auth: Disabled (uses managed identity)
  - Public Network Access: Configurable
  - Private Endpoint: In PE subnet
  - Agent Subnet: For outbound connectivity
  - Application Insights: Integrated for monitoring

#### AI Foundry Hub & Project
- **Resources**: 
  - AI Foundry Hub (Cognitive Services account)
  - AI Project with Capability Host
- **Dependencies**:
  - AI Search connection
  - Azure Storage connection
  - Cosmos DB connection
- **Configuration**:
  - Managed Identity integration
  - Optional delay scripts for CAP Host deployment
  - Project connection URL for agents

#### Azure AI Search
- **Resource**: Azure Cognitive Search (Basic SKU)
- **Purpose**: Vector and semantic search for AI agents
- **Configuration**:
  - Local Auth: Disabled
  - Public Network Access: Configurable
  - Private Endpoint: In PE subnet
  - IP Firewall: Custom IP allowed
  - Managed Identity: For authentication

#### Document Intelligence (Optional)
- **Resource**: Azure Form Recognizer/Document Intelligence
- **Purpose**: Document processing and extraction
- **Configuration**:
  - Local Auth: Disabled
  - Public Network Access: Configurable
  - Private Endpoint: In PE subnet
  - Managed Identity integration

### Data Layer

#### Cosmos DB
- **Resource**: Cosmos DB for NoSQL
- **Purpose**: Store chat history, sessions, and agent logs
- **Databases**:
  1. **ChatHistory**
     - Containers:
       - `AgentLog` (partition: `/requestId`)
       - `UserDocuments` (partition: `/userId`)
       - `ChatTurn` (partition: `/chatId`)
       - `ChatHistory` (partition: `/chatId`)
  
  2. **sessions**
     - Containers:
       - `apisessions` (partition: `/id`)
       - `uisessions` (partition: `/id`)

- **Configuration**:
  - Public Network Access: Configurable
  - Private Endpoint: In PE subnet
  - Key-based Auth: Disabled (uses RBAC)
  - IP Firewall: Custom IP allowed
  - Role Assignments: For managed identity and user

#### Azure Storage Account
- **Resource**: Storage Account v2
- **Purpose**: Store data, batch inputs/outputs
- **Containers**:
  - `data`: General data storage
  - `batch-input`: Batch processing input
  - `batch-output`: Batch processing output
- **Configuration**:
  - Shared Key Access: Disabled
  - Private Endpoints: 
    - Blob (in PE subnet)
    - Queue (in PE subnet)
    - Table (in PE subnet)
  - IP Firewall: Custom IP allowed
  - Role Assignments: For managed identity

### Security Layer

#### Key Vault
- **Resource**: Azure Key Vault
- **Purpose**: Secure storage of secrets, keys, and certificates
- **Secrets Stored**:
  - `api-key`: API authentication key
  - `apimkey`: APIM subscription key (if APIM deployed)
  - `appInsightsConnectingString`: Application Insights connection
  - `managed-identity-id`: User-assigned identity ID
  - `entraclientid`: Entra client ID (if configured)
  - `entraclientsecret`: Entra client secret (if configured)
- **Configuration**:
  - Public Network Access: Configurable
  - Private Endpoint: In PE subnet
  - IP Firewall: Custom IP allowed
  - RBAC: Owner role for deployer, managed identity access

#### Managed Identity
- **Resource**: User-Assigned Managed Identity
- **Purpose**: Authenticate applications to Azure services
- **Role Assignments** (via RBAC):
  - **Container Registry**: AcrPull
  - **Storage Account**: Storage Blob Data Contributor, Storage Table Data Contributor
  - **AI Search**: Search Service Contributor, Search Index Data Contributor
  - **Azure OpenAI/Foundry**: Cognitive Services OpenAI User
  - **Cosmos DB**: Cosmos DB Data Contributor (custom role)
  - **Key Vault**: Key Vault Secrets User
  - **APIM**: API Management Service Reader (if deployed)

### API Management Layer (Optional)

#### Azure API Management
- **Resource**: API Management service
- **Purpose**: API gateway, rate limiting, and monitoring
- **Configuration**:
  - Publisher email and name
  - Subscription: `aiagent-subscription`
  - Application Insights logger integration
  - Azure OpenAI backend configuration
- **Policies**: 
  - Rate limiting
  - Authentication
  - Request/response logging
- **Named Values**: APIM configuration settings

### Monitoring Layer

#### Log Analytics Workspace
- **Resource**: Log Analytics Workspace
- **Purpose**: Centralized logging and monitoring
- **Retention**: 365 days (configurable)
- **Connected Resources**:
  - Application Insights
  - Container Apps Environment
  - Application Gateway
  - All Azure services with diagnostic settings

#### Application Insights
- **Resource**: Application Insights
- **Purpose**: Application performance monitoring
- **Configuration**:
  - Connected to Log Analytics workspace
  - Instrumentation for Container Apps
  - Azure OpenAI integration
  - Custom telemetry from applications
- **Features**:
  - Distributed tracing
  - OpenTelemetry support
  - Gen AI content recording

### Network Security

#### Network Security Groups (NSGs)
- **VNET NSG**: Applied to multiple subnets
- **VM NSG**: Applied to jumpbox network interface
- **Rules**:
  - Inbound: Bastion, Application Gateway, internal traffic
  - Outbound: Azure services, internet (limited)

#### Private Endpoints
- **Purpose**: Secure private connectivity to Azure PaaS services
- **Configuration**:
  - All in Private Endpoints subnet
  - Network interfaces with private IPs
  - DNS integration for name resolution
- **Services with Private Endpoints**:
  - Key Vault
  - Azure OpenAI
  - AI Search
  - Storage (Blob, Queue, Table)
  - Cosmos DB
  - Container Registry
  - Container Apps Environment
  - Document Intelligence (if deployed)

## Traffic Flow Patterns

### External User → UI Application
1. User connects to Application Gateway public IP/FQDN
2. Application Gateway performs WAF inspection
3. Traffic routed to Container Apps Environment
4. Container Apps Environment routes to UI Container App
5. UI Container App authenticates user (Entra ID, if configured)

### UI Application → API Application
1. UI Container App calls API Container App via internal URL
2. Traffic stays within Container Apps Environment (internal routing)
3. API Container App authenticates request

### API Application → Azure Services
1. API Container App uses managed identity
2. Requests sent to private endpoints within VNET
3. Services (OpenAI, Search, Cosmos, Storage) respond via private network

### Management Access
1. Admin connects to Azure Bastion via Azure Portal
2. Bastion provides RDP/SSH to jumpbox VM
3. Jumpbox can access private resources within VNET
4. DNS resolution via private DNS zones

### AI Agent Workflow
1. User sends message via UI
2. UI stores session in Cosmos DB (`uisessions` container)
3. UI calls API with message
4. API retrieves context from Cosmos DB and Storage
5. API calls AI Foundry Project endpoint
6. AI Foundry uses OpenAI models for generation
7. AI Search provides semantic search/RAG capabilities
8. Response stored in Cosmos DB (`ChatHistory` database)
9. Response returned to user via UI

## Deployment Patterns

### Full Deployment (All Components)
- VNET with all subnets
- All private endpoints and DNS zones
- Application Gateway with WAF
- Container Apps with API and UI
- All AI services (OpenAI, Search, Document Intelligence)
- APIM (optional)
- Monitoring and security services

### Private Network Deployment
- Parameter: `publicAccessEnabled = false`
- All services deployed with private endpoints
- No public access to PaaS services
- Application Gateway for ingress
- Bastion for management access

### Public Network Deployment (Dev/Test)
- Parameter: `publicAccessEnabled = true`
- Services allow public network access
- IP firewall rules applied
- Faster deployment without DNS configuration
- Not recommended for production

### Selective Component Deployment
- **API Only**: `deployAPIApp = true`, `deployUIApp = false`
- **UI Only**: `deployUIApp = true`, `deployAPIApp = false`
- **No APIM**: `deployAPIM = false`
- **No App Gateway**: `deployApplicationGateway = false`
- **No Document Intelligence**: `deployDocumentIntelligence = false`

## Resource Naming Convention

Resources follow a structured naming pattern defined in `resourcenames.bicep`:
```
{resourceType}-{applicationName}-{environmentName}-{regionCode}-{instanceNumber}[-{resourceToken}]
```

Example resources:
- VNET: `vnet-aiapp-dev-US-001`
- Key Vault: `kv-aiapp-dev-US-001`
- Container App: `ca-api-aiapp-dev-US-001`
- AI Foundry: `cog-aiapp-dev-US-001`

## Security Features

### Identity & Access
- **Managed Identity**: Service-to-service authentication
- **RBAC**: Role-based access control for all services
- **Entra ID**: Optional user authentication for applications
- **Key Vault**: Secrets management
- **Disabled Keys**: Cosmos DB and Storage use RBAC only

### Network Security
- **Private Endpoints**: All services isolated in VNET
- **NSGs**: Network traffic filtering
- **WAF**: Web Application Firewall on Application Gateway
- **Bastion**: Secure VM access without public IPs
- **No Public IPs**: On application resources (except App Gateway)

### Data Protection
- **Encryption at Rest**: All storage services
- **Encryption in Transit**: TLS 1.2+ for all connections
- **Private Connectivity**: No internet exposure for data services
- **Diagnostic Logging**: All resource activity logged

## High Availability & Scalability

### Availability Zones
- Application Gateway: Zones 1, 2, 3
- Container Apps: Distributed across zones
- Storage: Zone-redundant (if supported in region)

### Autoscaling
- **Application Gateway**: 1-10 instances (configurable)
- **Container Apps**: Per workload profile (D4: 1-10)
- **Cosmos DB**: Autoscale throughput
- **AI Models**: Dynamic capacity allocation

### Redundancy
- **Storage**: LRS/ZRS/GRS options
- **Cosmos DB**: Multi-region replication (configurable)
- **Container Registry**: Geo-replication (Premium SKU)

## Monitoring & Observability

### Metrics & Logs
- **Application Insights**: Application performance, traces, metrics
- **Log Analytics**: Centralized log aggregation
- **Diagnostic Settings**: All resources send logs
- **OpenTelemetry**: Distributed tracing for Gen AI

### Dashboards
- Application Insights dashboard
- Custom workbooks (optional)
- Resource health monitoring

### Alerts (Configurable)
- Service health
- Resource metrics
- Application performance
- Security events

## Cost Optimization

### SKU Selection
- **AI Search**: Basic (upgradeable)
- **Container Apps**: D4 workload profile (adjustable)
- **App Gateway**: Standard_v2 or WAF_v2 (selectable)
- **VM**: B2s_v2 (economical for jumpbox)

### Autoscaling
- Application Gateway scales based on demand
- Container Apps scale per workload profile
- Pay only for resources used

### Resource Reuse
- Existing VNET support
- Existing Cosmos DB support
- Shared Log Analytics workspace

## Parameters Summary

### Required Parameters
- `applicationName` or `applicationPrefix`: Application identifier
- `environmentName`: Environment (dev, qa, prod)
- `location`: Azure region
- `principalId`: Deploying user's object ID (for RBAC)

### Network Parameters
- `existingVnetName`: Use existing VNET
- `vnetPrefix`: VNET address space
- `subnet*Name` and `subnet*Prefix`: Subnet configurations
- `myIpAddress`: IP for firewall rules

### Feature Flags
- `deployAPIM`: Deploy API Management
- `deployApplicationGateway`: Deploy App Gateway
- `deployAPIApp`: Deploy API Container App
- `deployUIApp`: Deploy UI Container App
- `deployDocumentIntelligence`: Deploy Document Intelligence
- `publicAccessEnabled`: Public vs private networking
- `makeWebAppsPublic`: Public access for Container Apps
- `createDnsZones`: Create private DNS zones
- `addRoleAssignments`: Configure RBAC

### AI Model Parameters
- `gpt40_DeploymentName`, `gpt40_ModelVersion`, `gpt40_DeploymentCapacity`
- `gpt41_DeploymentName`, `gpt41_ModelVersion`, `gpt41_DeploymentCapacity`

### Entra ID Parameters
- `entraTenantId`, `entraApiAudience`, `entraScopes`
- `entraClientId`, `entraClientSecret`, `entraRedirectUri`

### Application Gateway Parameters
- `appGatewaySkuName`: Standard_v2 or WAF_v2
- `appGatewayMinCapacity`, `appGatewayMaxCapacity`
- `appGatewayBackendAddresses`: Backend pool targets
- `appGatewaySslCertificateKeyVaultSecretId`: SSL cert from KV

## Outputs

Key outputs for consumption by applications and pipelines:
- Container App FQDNs and names
- Azure OpenAI/Foundry endpoints and project ID
- Cosmos DB endpoint and container names
- Storage account name and container names
- AI Search endpoint
- Application Gateway FQDN and public IP
- VNET details (ID, name, prefix)
- Resource token for unique identification

## Tags Applied

All resources tagged with:
- `creation-date`: Deployment date (yyyyMMdd)
- `created-by`: Deployer identifier
- `application-name`: Application name
- `environment-name`: Environment name
- Additional tags: `azd-service-name` for container apps

## Best Practices Implemented

1. **Security First**: Private networking, managed identities, disabled key-based auth
2. **Monitoring**: Comprehensive logging and tracing
3. **Scalability**: Autoscaling, workload profiles, zone redundancy
4. **Modularity**: Bicep modules for reusability
5. **Flexibility**: Extensive parameters for customization
6. **Standards**: Consistent naming, tagging, RBAC
7. **Cost Management**: Right-sized SKUs, autoscaling
8. **Compliance**: Diagnostic settings, audit logs, WAF policies

## Visio Diagram Structure Recommendations

### Suggested Visio Pages/Tabs

**Page 1: High-Level Architecture**
- Show all major components grouped by layer
- Network boundaries (VNET, subnets)
- External connectivity (Application Gateway)
- Major services (Container Apps, AI Foundry, databases)

**Page 2: Network Topology**
- Detailed VNET with all subnets and CIDR ranges
- NSGs and their associations
- Private endpoints locations
- Bastion and jumpbox placement
- Application Gateway placement

**Page 3: Application Flow**
- User journey from external request to response
- Container Apps interaction
- AI agent workflow with all service calls
- Data flow between services

**Page 4: Security Architecture**
- Managed identity and RBAC assignments
- Private endpoints and DNS zones
- Key Vault secret references
- Network security boundaries

**Page 5: Monitoring & Operations**
- Log Analytics and Application Insights
- Diagnostic settings flow
- Metrics and alerts architecture
- OpenTelemetry tracing

### Recommended Visio Stencils/Icons

Use the official Microsoft Azure Architecture Icons:
- Networking: Virtual Network, Subnets, NSG, Private Endpoint, Bastion, Application Gateway
- Compute: Container Apps, Container Registry, Virtual Machine
- AI + ML: Azure OpenAI, AI Search, Cognitive Services, AI Foundry
- Data: Cosmos DB, Storage Account (with Blob, Queue, Table)
- Security: Key Vault, Managed Identity
- Management: Log Analytics, Application Insights, Monitor
- Integration: API Management

### Color Scheme Recommendations

- **Network Layer**: Light blue (#E3F2FD)
- **Compute Layer**: Orange (#FFE0B2)
- **AI Services**: Purple (#E1BEE7)
- **Data Layer**: Green (#C8E6C9)
- **Security Layer**: Red (#FFCDD2)
- **Monitoring Layer**: Yellow (#FFF9C4)
- **Managed Services**: Gray (#ECEFF1)

### Connection Types

- **Solid Lines**: Direct network connections
- **Dashed Lines**: Private endpoint connections
- **Bold Lines**: Primary data flow
- **Arrows**: Direction of traffic/data flow
- **Labels**: Protocol/port information

---

## Diagram Creation Steps for Visio

1. **Start with Network Foundation**
   - Draw VNET rectangle with address space
   - Add all 8 subnets with their CIDR ranges
   - Place NSG icons on relevant subnets

2. **Add Ingress Layer**
   - Place Application Gateway in App Gateway subnet
   - Add public IP to Application Gateway
   - Place Bastion in Bastion subnet
   - Add public IP to Bastion

3. **Add Compute Resources**
   - Place Container Apps Environment in App SE subnet
   - Add API and UI Container Apps within environment
   - Place VM in Jumpbox subnet
   - Add Container Registry with private endpoint

4. **Add AI Services**
   - Place Azure OpenAI/Foundry with private endpoint
   - Add AI Search with private endpoint
   - Add Document Intelligence (optional) with private endpoint
   - Show AI Foundry Hub and Project relationship

5. **Add Data Services**
   - Place Cosmos DB with private endpoint
   - Add Storage Account with 3 private endpoints (blob, queue, table)
   - Show database and container structures

6. **Add Security Services**
   - Place Key Vault with private endpoint
   - Add Managed Identity (show it as connected to Container Apps)
   - Show secret references from Key Vault to applications

7. **Add Management Services**
   - Place APIM (optional) outside VNET or in VNET
   - Add Log Analytics Workspace
   - Add Application Insights (linked to Log Analytics)

8. **Add Private Endpoints**
   - All private endpoints in PE subnet
   - DNS zones linked to VNET

9. **Add Connections**
   - User → Application Gateway → Container Apps
   - Container Apps → Private Endpoints → Services
   - Jumpbox → Services (via private network)
   - All services → Log Analytics

10. **Add Labels and Annotations**
    - Service names
    - IP ranges
    - Port numbers
    - SKUs and capacity info
    - Conditional deployments noted

---

*This architecture documentation is based on `main-advanced.bicep` and represents the full deployment capabilities. Actual deployment may vary based on parameter configuration.*
