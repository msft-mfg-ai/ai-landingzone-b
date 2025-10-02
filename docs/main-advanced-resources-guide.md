# Azure AI Landing Zone - Advanced Deployment Resource Guide

## Overview
This document provides a detailed explanation of every resource deployed by `main-advanced.bicep`, their purposes, configurations, and how they interact with each other to form a comprehensive Azure AI Landing Zone.

---

## Table of Contents
- [Network Infrastructure](#network-infrastructure)
- [Compute Resources](#compute-resources)
- [AI & Cognitive Services](#ai--cognitive-services)
- [Data Services](#data-services)
- [Security & Identity](#security--identity)
- [API Management](#api-management)
- [Monitoring & Observability](#monitoring--observability)
- [Resource Interactions](#resource-interactions)
- [Data Flow Scenarios](#data-flow-scenarios)

---

## Network Infrastructure

### 1. Virtual Network (VNET)
**Module:** `modules/networking/vnet.bicep`

**Purpose:**
- Provides isolated network infrastructure for all Azure resources
- Enables private communication between services
- Implements network segmentation for security and traffic management

**Configuration:**
- **Address Space:** `10.237.144.0/22` (default, configurable)
- **Can reuse existing VNET:** Set `existingVnetName` parameter

**Key Features:**
- Network Security Groups (NSGs) for traffic filtering
- Route tables for custom routing
- Service endpoints for Azure services
- Multiple subnets for workload isolation

**Interactions:**
- **Contains:** All subnets and their resources
- **Linked to:** Private DNS zones for name resolution
- **Secured by:** NSGs and route tables
- **Monitored by:** Network Watcher (implicit)

---

### 2. Application Gateway Subnet
**Subnet CIDR:** `10.237.145.0/24` (default)

**Purpose:**
- Dedicated subnet for Application Gateway deployment
- Isolates ingress traffic handling from other workloads

**Contains:**
- Application Gateway v2
- Public IP for Application Gateway

**Network Rules:**
- Allows inbound traffic from internet (HTTP/HTTPS)
- Allows Azure infrastructure traffic
- Routes traffic to Container Apps subnet

**Interactions:**
- **Receives:** External user traffic via Public IP
- **Sends to:** Container Apps Environment subnet
- **Monitored by:** Application Gateway diagnostics

---

### 3. App Service Environment Subnet
**Subnet CIDR:** `10.237.144.0/24` (default)

**Purpose:**
- Hosts Container Apps Environment infrastructure
- Provides dedicated networking for containerized applications

**Contains:**
- Container Apps Environment
- API Container App
- UI Container App

**Network Rules:**
- Allows inbound from Application Gateway subnet
- Allows outbound to private endpoints
- Allows outbound to internet (for dependencies)
- Integrated with NSG for security

**Interactions:**
- **Receives from:** Application Gateway
- **Connects to:** Private Endpoints subnet for Azure services
- **Uses:** DNS for service name resolution

---

### 4. Private Endpoints Subnet
**Subnet CIDR:** `10.237.146.0/27` (default)

**Purpose:**
- Centralized location for all private endpoints
- Provides private network connectivity to Azure PaaS services
- Eliminates need for public internet access to services

**Contains Private Endpoints for:**
- Key Vault
- Azure OpenAI/Foundry
- AI Search
- Cosmos DB
- Storage Account (Blob, Queue, Table)
- Container Registry
- Container Apps Environment (when private)
- Document Intelligence

**Network Rules:**
- Allows inbound from all other subnets
- Network policies enabled for security
- Private DNS integration for name resolution

**Interactions:**
- **Provides access to:** All Azure PaaS services in private mode
- **Connected from:** Container Apps, VM, Agent workloads
- **Resolves via:** Private DNS zones

---

### 5. Agent Subnet
**Subnet CIDR:** `10.237.146.32/27` (default)

**Purpose:**
- Reserved for AI agent compute resources
- Provides outbound connectivity for AI Foundry agents
- Isolated from other workloads for security

**Contains:**
- AI agent runtime resources (when deployed)
- Outbound connectivity infrastructure

**Network Rules:**
- Allows outbound to Azure OpenAI
- Allows outbound to other AI services
- Restricted inbound traffic

**Interactions:**
- **Used by:** AI Foundry projects and agents
- **Connects to:** Azure OpenAI, AI Search via private endpoints
- **Integrated with:** AI Foundry Hub

---

### 6. Bastion Subnet
**Subnet CIDR:** `10.237.146.64/26` (default)
**Name:** `AzureBastionSubnet` (Azure-required name)

**Purpose:**
- Provides secure RDP/SSH access to virtual machines
- Eliminates need for VM public IPs
- Centralized access point for management

**Contains:**
- Azure Bastion Host
- Bastion Public IP

**Network Rules:**
- Allows inbound from internet on ports 443, 4443
- Allows outbound to VMs on ports 22 (SSH) and 3389 (RDP)
- Azure-managed traffic rules

**Interactions:**
- **Accessed by:** Administrators via Azure Portal
- **Connects to:** Jumpbox VM and other VMs
- **Secured by:** Azure Bastion service security

---

### 7. Jumpbox Subnet
**Subnet CIDR:** `10.237.146.128/28` (default)

**Purpose:**
- Hosts management virtual machines
- Provides administrative access to private resources
- Testing and troubleshooting platform

**Contains:**
- Windows jumpbox VM (optional)
- VM network interface
- VM NSG

**Network Rules:**
- Allows inbound from Bastion subnet
- Allows outbound to all private endpoints
- Restricted public internet access

**Interactions:**
- **Accessed via:** Azure Bastion
- **Can access:** All private resources in VNET
- **Used for:** Management, testing, troubleshooting

---

### 8. Training Subnet
**Subnet CIDR:** `10.237.147.0/25` (default)

**Purpose:**
- Reserved for machine learning training workloads
- Future use for Azure Machine Learning compute
- Isolated from inference workloads

**Contains:**
- ML training compute (when deployed)
- Training cluster nodes

**Network Rules:**
- Allows outbound to storage and data sources
- Allows outbound to Azure ML services
- Large address space for scaling

**Interactions:**
- **Will connect to:** Storage Account for training data
- **Will use:** AI services for model training
- **Isolated from:** Production workloads

---

### 9. Scoring Subnet
**Subnet CIDR:** `10.237.147.128/25` (default)

**Purpose:**
- Reserved for machine learning inference/scoring workloads
- Future use for Azure Machine Learning endpoints
- Isolated from training workloads

**Contains:**
- ML inference endpoints (when deployed)
- Scoring service nodes

**Network Rules:**
- Allows inbound from application subnets
- Allows outbound to storage and logging
- Optimized for low-latency inference

**Interactions:**
- **Will be called by:** Application services for predictions
- **Will connect to:** Storage and monitoring services
- **Isolated from:** Training workloads

---

### 10. Private DNS Zones
**Module:** `modules/networking/all-zones.bicep`

**Purpose:**
- Provides name resolution for private endpoints
- Ensures services resolve to private IP addresses
- Eliminates need for public DNS lookups

**DNS Zones Created:**
- `privatelink.vaultcore.azure.net` - Key Vault
- `privatelink.openai.azure.com` - Azure OpenAI
- `privatelink.search.windows.net` - AI Search
- `privatelink.blob.core.windows.net` - Storage Blobs
- `privatelink.queue.core.windows.net` - Storage Queues
- `privatelink.table.core.windows.net` - Storage Tables
- `privatelink.documents.azure.com` - Cosmos DB
- `privatelink.azurecr.io` - Container Registry
- `privatelink.azurecontainerapps.io` - Container Apps
- `privatelink.cognitiveservices.azure.com` - Cognitive Services

**Configuration:**
- All zones linked to VNET
- Auto-registration enabled where applicable
- A records automatically created for private endpoints

**Interactions:**
- **Used by:** All resources in VNET for name resolution
- **Populated by:** Private endpoints when created
- **Resolves:** Service FQDNs to private IPs

---

### 11. Network Security Groups (NSGs)
**Module:** `modules/networking/network-security-group.bicep`

**Purpose:**
- Filter network traffic at subnet level
- Implement security rules for inbound/outbound traffic
- Provide defense-in-depth security

**Applied to:**
- VNET subnets (various)
- VM network interfaces
- Application Gateway subnet

**Key Rules:**
- Allow Azure infrastructure traffic
- Allow specific application ports
- Deny all other traffic (implicit)
- Log security events

**Interactions:**
- **Protects:** All subnet resources
- **Logged to:** Log Analytics workspace
- **Monitored by:** Network Watcher flow logs

---

## Compute Resources

### 12. Azure Bastion Host
**Module:** `modules/networking/bastion.bicep`
**SKU:** Standard

**Purpose:**
- Provides secure, seamless RDP/SSH connectivity to VMs
- Eliminates need for public IPs on VMs
- Centralized access control and auditing

**Key Features:**
- **Tunneling:** Native SSH/RDP client support
- **File Copy:** Upload/download files to/from VMs
- **Shareable Links:** Share VM access temporarily
- **Session Recording:** Audit trail of connections

**Configuration:**
- Public IP with static allocation
- Standard SKU for advanced features
- Deployed in dedicated Bastion subnet
- Integrated with Azure RBAC

**Interactions:**
- **Accessed by:** Administrators via Azure Portal (HTTPS 443)
- **Connects to:** Jumpbox VM and other VMs in VNET
- **Authenticated via:** Azure AD/Entra ID
- **Logged to:** Activity logs and diagnostics

**Security:**
- All traffic encrypted (TLS 1.2+)
- No public IPs needed on VMs
- Just-in-time access control
- Session monitoring and recording

---

### 13. Windows Jumpbox Virtual Machine
**Module:** `modules/virtualMachine/virtualMachine.bicep`
**SKU:** Standard_B2s_v2 (optional deployment)

**Purpose:**
- Management workstation for private resources
- Testing and troubleshooting platform
- Access point for resources without public endpoints

**Specifications:**
- **OS:** Windows Server
- **Size:** 2 vCPU, 4 GB RAM
- **OS Disk:** 128 GB SSD
- **Network:** Private IP only
- **Access:** Via Azure Bastion only

**Configuration:**
- Deployed only if `vm_username` and `vm_password` provided
- Computer name limited to 15 characters (Windows requirement)
- NSG attached to network interface
- Managed disk with encryption

**Interactions:**
- **Accessed via:** Azure Bastion (no public IP)
- **Can access:** All private endpoints and services
- **Can manage:** Azure resources via Azure CLI/PowerShell
- **Used for:** Testing, troubleshooting, administration

**Tools Pre-installed (typical):**
- Azure CLI
- PowerShell Azure modules
- Visual Studio Code
- SQL Server Management Studio
- Storage Explorer

**Security:**
- No public IP address
- Bastion-only access
- NSG rules for traffic filtering
- Disk encryption enabled
- Admin credentials in Key Vault (recommended)

---

### 14. Container Apps Environment
**Module:** `modules/app/managedEnvironment.bicep`

**Purpose:**
- Managed Kubernetes-like platform for containers
- Serverless container hosting with auto-scaling
- Simplified deployment and management

**Configuration:**
- **Workload Profiles:** D4 (4 vCPU, 8 GB RAM) with 1-10 instances
- **Network:** Integrated with App Service Environment subnet
- **Public Access:** Configurable via `makeWebAppsPublic` parameter
- **Private Endpoint:** Created when in private mode

**Key Features:**
- Auto-scaling based on HTTP requests or CPU/memory
- Built-in load balancing
- Zero-downtime deployments
- Integrated with VNET
- Default domain for applications
- Static IP for private access

**Interactions:**
- **Receives traffic from:** Application Gateway
- **Hosts:** API and UI Container Apps
- **Connects to:** Private endpoints for services
- **Monitored by:** Application Insights and Log Analytics
- **Uses:** Container Registry for images

**Environment Variables (inherited by apps):**
- Application Insights connection string
- AI Foundry project endpoint
- Managed identity client ID
- Tracing and diagnostics settings

---

### 15. API Container App
**Module:** `modules/app/containerappstub.bicep`
**Port:** 8000 (optional deployment)

**Purpose:**
- Backend API service for AI agent applications
- Handles AI orchestration and business logic
- Interfaces with AI services and data stores

**Configuration:**
- **Image:** Pulled from Azure Container Registry
- **Identity:** User-assigned managed identity
- **Workload Profile:** Configurable (default: D4)
- **Scaling:** Auto-scale based on HTTP requests
- **Secrets:** Sourced from Key Vault

**Environment Variables:**
- `APPLICATIONINSIGHTS_CONNECTION_STRING` - Telemetry
- `AppSettings__AppAgentEndpoint` - AI Foundry project URL
- `AppSettings__AppAgentId` - Agent identifier
- `AZURE_CLIENT_ID` - Managed identity
- `COSMOS_DB_ENDPOINT` - Database connection
- `COSMOS_DB_API_SESSIONS_DATABASE_NAME` - Session database
- `COSMOS_DB_API_SESSIONS_CONTAINER_NAME` - Session container
- `APIM_BASE_URL` - API Management gateway (optional)
- `APIM_ACCESS_URL` - API Management endpoint (optional)

**Secrets (from Key Vault):**
- `apikey` - API authentication key
- `apimkey` - APIM subscription key (optional)
- `entraclientid` - Entra client ID (optional)
- `entraclientsecret` - Entra client secret (optional)

**Interactions:**
- **Called by:** UI Container App internally
- **Calls:** Azure OpenAI/Foundry for AI operations
- **Calls:** AI Search for semantic search/RAG
- **Reads/writes:** Cosmos DB for sessions and chat history
- **Reads/writes:** Storage Account for data
- **Authenticates via:** Managed Identity
- **Monitored by:** Application Insights
- **Optional:** Routes through APIM

**Capabilities:**
- AI agent orchestration
- Semantic search integration
- Document processing
- Session management
- Chat history storage
- Authentication and authorization

---

### 16. UI Container App
**Module:** `modules/app/containerappstub.bicep`
**Port:** 8001 (optional deployment)

**Purpose:**
- Frontend web application for user interaction
- Chat interface for AI agents
- User authentication and session management

**Configuration:**
- **Image:** Pulled from Azure Container Registry
- **Identity:** User-assigned managed identity
- **Workload Profile:** Configurable (default: D4)
- **Scaling:** Auto-scale based on HTTP requests
- **Public URL:** `https://{appname}.{domain}/`

**Environment Variables:**
- All API Container App variables, plus:
- `API_URL` - Internal URL to API Container App
- `ENTRA_TENANT_ID` - Azure AD tenant (optional)
- `ENTRA_API_AUDIENCE` - API audience (optional)
- `ENTRA_SCOPES` - OAuth scopes (optional)
- `ENTRA_REDIRECT_URI` - OAuth callback (optional)

**Authentication Flow (when Entra enabled):**
1. User accesses UI
2. UI redirects to Entra ID for authentication
3. User authenticates with Azure AD
4. Entra redirects back to `{appurl}/auth/callback`
5. UI obtains access token
6. UI calls API with bearer token

**Interactions:**
- **Accessed by:** External users via Application Gateway
- **Calls:** API Container App for all backend operations
- **Reads:** Cosmos DB for UI session state
- **Authenticates users via:** Entra ID (optional)
- **Monitored by:** Application Insights

**User Experience:**
- Chat interface for AI conversations
- Document upload and management
- Session history and management
- Responsive web design
- Real-time updates

---

### 17. Azure Container Registry
**Module:** `modules/app/containerregistry.bicep`
**SKU:** Premium

**Purpose:**
- Private Docker registry for container images
- Stores API and UI container images
- Version control for container deployments

**Configuration:**
- **Admin User:** Disabled (uses managed identity)
- **Public Access:** Configurable
- **Private Endpoint:** In Private Endpoints subnet
- **Geo-replication:** Available with Premium SKU
- **Content Trust:** Available for image signing

**Key Features:**
- **Image Storage:** Versioned container images
- **Security Scanning:** Vulnerability scanning
- **Webhooks:** Trigger on image push
- **Tasks:** Build automation
- **Artifact Cache:** Performance optimization

**Interactions:**
- **Pushed to by:** CI/CD pipelines (GitHub Actions, Azure DevOps)
- **Pulled from by:** Container Apps Environment
- **Authenticated via:** Managed Identity (AcrPull role)
- **Secured by:** Private endpoint and firewall rules
- **Monitored by:** Diagnostic settings

**Images Stored:**
- `{registry}.azurecr.io/api:{tag}` - API application
- `{registry}.azurecr.io/ui:{tag}` - UI application
- Base images and dependencies

---

## AI & Cognitive Services

### 18. Azure AI Foundry (Azure OpenAI)
**Module:** `modules/ai/cognitive-services.bicep`
**Resource Type:** Cognitive Services - OpenAI

**Purpose:**
- Host and serve AI language models
- Provide chat completions and embeddings
- Enterprise-grade AI capabilities with governance

**AI Models Deployed:**

#### 18a. GPT-4o
- **Deployment Name:** `gpt-4o` (configurable)
- **Model Version:** `2024-11-20` (configurable)
- **Capacity:** 10 TPM (configurable)
- **SKU:** Standard
- **Purpose:** Advanced chat completions, reasoning, multimodal

#### 18b. GPT-4.1
- **Deployment Name:** `gpt-4.1` (configurable)
- **Model Version:** `2025-04-14` (configurable)
- **Capacity:** 10 TPM (configurable)
- **SKU:** GlobalStandard
- **Purpose:** Latest model with improved performance

#### 18c. GPT-3.5 Turbo
- **Deployment Name:** `gpt-35-turbo`
- **Model Version:** `0125`
- **Capacity:** Default (20 TPM)
- **Purpose:** Fast, cost-effective chat completions

#### 18d. Text Embedding Ada 002
- **Deployment Name:** `text-embedding-ada-002`
- **Model Version:** `2`
- **Purpose:** Generate embeddings for semantic search

**Configuration:**
- **Local Auth:** Disabled (uses managed identity only)
- **Public Network Access:** Configurable via `makeWebAppsPublic`
- **Private Endpoint:** In Private Endpoints subnet
- **Agent Subnet:** For outbound agent connectivity
- **Firewall:** IP-based access control

**Key Features:**
- **Content Filtering:** Built-in safety filters
- **Rate Limiting:** Per-deployment TPM limits
- **Usage Tracking:** Token consumption metrics
- **Prompt Engineering:** System messages support
- **Function Calling:** Tool integration
- **Streaming:** Real-time response streaming

**Interactions:**
- **Called by:** API Container App (via private endpoint)
- **Called by:** AI Foundry projects and agents
- **Authenticated via:** Managed Identity (Cognitive Services OpenAI User role)
- **Monitored by:** Application Insights for traces
- **Optional:** Fronted by APIM for additional controls

**Integration Points:**
- AI Search for RAG (Retrieval Augmented Generation)
- Cosmos DB for prompt history
- Storage Account for large context
- Application Insights for diagnostics

---

### 19. AI Foundry Hub and Project
**Modules:** 
- `modules/ai/ai-project-with-caphost.bicep`
- `modules/ai/ai-project.bicep`
- `modules/ai/add-project-capability-host.bicep`

**Purpose:**
- Unified AI platform for agent development
- Project workspace for AI applications
- Integration hub for AI services and data

**Components:**

#### AI Foundry Hub
- Container for AI projects
- Shared configuration and policies
- Connection management
- Resource organization

#### AI Project
- Individual workspace for agent development
- Code, data, and model management
- Experiment tracking
- Deployment pipelines

#### Capability Host
- Execution environment for AI agents
- Runtime for agent logic
- Integration with Azure services
- Scalable agent hosting

**Configuration:**
- **Number of Projects:** 1 (configurable via `numberOfProjects`)
- **Location:** Same as resource group
- **Managed Identity:** User-assigned for authentication
- **Delay Scripts:** Optional for CAP host deployment timing

**Connected Services (AI Dependencies):**
- **AI Search:** For semantic search and knowledge retrieval
- **Azure Storage:** For data and artifacts
- **Cosmos DB:** For state and metadata
- **Azure OpenAI:** For AI models (parent resource)

**Key Features:**
- **Agent Development:** Build and test AI agents
- **Prompt Engineering:** Design and iterate prompts
- **RAG Integration:** Connect data sources for grounding
- **Evaluation:** Test and validate agent responses
- **Deployment:** Deploy agents to production
- **Monitoring:** Track agent performance

**Interactions:**
- **Accessed by:** Developers via Azure portal or SDK
- **Called by:** Container Apps for agent execution
- **Uses:** All connected AI dependencies
- **Outputs:** Project connection URL for applications
- **Monitored by:** Application Insights

**Project Connection URL:**
Used by API Container App as `AppSettings__AppAgentEndpoint`

---

### 20. Azure AI Search
**Module:** `modules/search/search-services.bicep`
**SKU:** Basic

**Purpose:**
- Semantic search for AI applications
- Vector search for embeddings
- Knowledge base for RAG (Retrieval Augmented Generation)

**Configuration:**
- **Local Auth:** Disabled (managed identity only)
- **Public Network Access:** Configurable
- **Private Endpoint:** In Private Endpoints subnet
- **Search Units:** 1 replica, 1 partition (Basic)

**Key Features:**
- **Vector Search:** Similarity search on embeddings
- **Semantic Search:** Improved relevance ranking
- **Full-Text Search:** Traditional keyword search
- **Faceted Navigation:** Filter and aggregate results
- **Suggesters:** Auto-complete functionality
- **Scoring Profiles:** Custom relevance tuning
- **Indexers:** Automated data ingestion
- **Skillsets:** AI enrichment pipeline

**Search Indexes (typical):**
- Document index with vector embeddings
- Chat history index for context
- Knowledge base index for RAG

**Interactions:**
- **Called by:** API Container App for semantic search
- **Called by:** AI Foundry agents for knowledge retrieval
- **Populated by:** Indexers from data sources
- **Populated by:** Application via SDK
- **Authenticated via:** Managed Identity (Search Index Data Contributor)
- **Connected to:** AI Foundry project as data source

**RAG Pattern:**
1. User asks question
2. API generates embedding via Azure OpenAI
3. Vector search finds relevant documents
4. Documents added to prompt context
5. Azure OpenAI generates grounded response

---

### 21. Document Intelligence (Optional)
**Module:** `modules/ai/document-intelligence.bicep`
**Service:** Azure Form Recognizer / Document Intelligence

**Purpose:**
- Extract text, tables, and structure from documents
- OCR for images and PDFs
- Form processing and understanding

**Configuration:**
- **Local Auth:** Disabled (managed identity only)
- **Public Network Access:** Configurable
- **Private Endpoint:** In Private Endpoints subnet
- **Deployed:** Only if `deployDocumentIntelligence = true`

**Key Features:**
- **Prebuilt Models:** Invoices, receipts, ID cards, business cards
- **Custom Models:** Train on your documents
- **Layout Analysis:** Extract text, tables, paragraphs
- **OCR:** Optical character recognition
- **Key-Value Pairs:** Extract form fields

**Document Processing Pipeline:**
1. Upload document to Storage Account
2. Container App calls Document Intelligence
3. Extract text and structure
4. Generate embeddings via Azure OpenAI
5. Index in AI Search
6. Document available for RAG queries

**Interactions:**
- **Called by:** API Container App for document processing
- **Reads from:** Storage Account (documents)
- **Writes to:** Storage Account (results)
- **Sends data to:** AI Search for indexing
- **Authenticated via:** Managed Identity
- **Monitored by:** Diagnostic logs

**Supported Formats:**
- PDF, JPEG, PNG, BMP, TIFF
- Office documents (via conversion)
- Multi-page documents

---

## Data Services

### 22. Cosmos DB for NoSQL
**Module:** `modules/database/cosmosdb.bicep`

**Purpose:**
- Globally distributed, multi-model database
- Store chat history and conversations
- Session management and state
- Agent logs and telemetry

**Configuration:**
- **Account Name:** Generated or reuse existing via `existingCosmosAccountName`
- **API:** NoSQL (Core SQL)
- **Authentication:** RBAC only (keys disabled)
- **Public Network Access:** Configurable
- **Private Endpoint:** In Private Endpoints subnet

**Databases and Containers:**

#### Database: `ChatHistory`
Stores conversation data and user interactions

**Containers:**
1. **AgentLog**
   - **Partition Key:** `/requestId`
   - **Purpose:** AI agent execution logs and traces
   - **Data:** Request details, timing, tokens used
   
2. **UserDocuments**
   - **Partition Key:** `/userId`
   - **Purpose:** User-uploaded documents and metadata
   - **Data:** Document references, processing status
   
3. **ChatTurn**
   - **Partition Key:** `/chatId`
   - **Purpose:** Individual chat messages and turns
   - **Data:** User messages, AI responses, timestamps
   
4. **ChatHistory**
   - **Partition Key:** `/chatId`
   - **Purpose:** Complete conversation threads
   - **Data:** Session metadata, conversation summaries

#### Database: `sessions`
Stores application session data

**Containers:**
1. **apisessions**
   - **Partition Key:** `/id`
   - **Purpose:** API session state and authentication
   - **Data:** Session tokens, user context, expiry
   
2. **uisessions**
   - **Partition Key:** `/id`
   - **Purpose:** UI session state and preferences
   - **Data:** User preferences, UI state, navigation

**Key Features:**
- **Global Distribution:** Multi-region replication
- **Automatic Indexing:** No schema required
- **Low Latency:** Single-digit millisecond reads
- **Consistency Levels:** Configurable guarantees
- **Change Feed:** Real-time data streaming
- **Time to Live (TTL):** Auto-expire old data

**Interactions:**
- **Read/write by:** API Container App
- **Read/write by:** UI Container App (uisessions)
- **Connected to:** AI Foundry project as data source
- **Authenticated via:** Managed Identity (Cosmos DB Data Contributor)
- **Monitored by:** Diagnostic settings and metrics

**Role Assignments:**
- Managed Identity: Cosmos DB Data Contributor (custom role)
- User/Admin: Same for development access

---

### 23. Azure Storage Account
**Module:** `modules/storage/storage-account.bicep`
**Type:** StorageV2 (General Purpose v2)

**Purpose:**
- Blob storage for documents and files
- Queue storage for message processing
- Table storage for structured NoSQL data

**Configuration:**
- **Redundancy:** LRS (default, configurable to ZRS/GRS)
- **Shared Key Access:** Disabled (RBAC only)
- **Public Network Access:** Configurable
- **Private Endpoints:** 3 endpoints (Blob, Queue, Table)
- **Firewall:** IP-based rules for development

**Blob Containers:**

1. **data**
   - **Purpose:** General application data
   - **Usage:** User uploads, processed documents
   - **Access:** Via managed identity

2. **batch-input**
   - **Purpose:** Batch processing input files
   - **Usage:** Large-scale document processing
   - **Pattern:** Jobs pick up files, process, move to output

3. **batch-output**
   - **Purpose:** Batch processing results
   - **Usage:** Processed documents, extracted data
   - **Pattern:** Results written here, read by applications

**Storage Services:**

#### Blob Storage
- **Tiers:** Hot (default), Cool, Archive available
- **Features:** 
  - Hierarchical namespace (optional)
  - Blob versioning
  - Soft delete
  - Lifecycle management
  - Change feed

#### Queue Storage
- **Purpose:** Asynchronous message processing
- **Usage:** 
  - Background job triggers
  - Decoupled service communication
  - Reliable message delivery

#### Table Storage
- **Purpose:** Structured NoSQL data
- **Usage:**
  - Application configuration
  - Lightweight data storage
  - Fast key-value lookups

**Interactions:**
- **Accessed by:** API Container App for data operations
- **Accessed by:** Document Intelligence for documents
- **Accessed by:** AI Foundry for artifacts
- **Authenticated via:** Managed Identity (Storage Blob Data Contributor, Storage Table Data Contributor)
- **Monitored by:** Storage metrics and logs

**Data Flow Examples:**
1. **Document Upload:**
   - User uploads via UI → API → Blob storage
   - Document Intelligence processes → Extracts text
   - Results indexed in AI Search

2. **Batch Processing:**
   - Files placed in `batch-input`
   - Function/job processes files
   - Results written to `batch-output`

---

## Security & Identity

### 24. User-Assigned Managed Identity
**Module:** `modules/iam/identity.bicep`

**Purpose:**
- Service-to-service authentication without credentials
- Eliminates need for connection strings and keys
- Centralized identity for multiple resources

**Used By:**
- API Container App
- UI Container App
- AI Foundry project
- Container Registry operations
- Deployment scripts

**Azure RBAC Role Assignments:**

#### Container Registry
- **Role:** AcrPull
- **Purpose:** Pull container images
- **Scope:** Container Registry resource

#### Storage Account
- **Roles:** 
  - Storage Blob Data Contributor
  - Storage Table Data Contributor
- **Purpose:** Read/write data in storage
- **Scope:** Storage Account resource

#### AI Search
- **Roles:**
  - Search Service Contributor
  - Search Index Data Contributor
- **Purpose:** Manage search indexes and data
- **Scope:** AI Search resource

#### Azure OpenAI/Foundry
- **Role:** Cognitive Services OpenAI User
- **Purpose:** Call AI models
- **Scope:** Cognitive Services account

#### Cosmos DB
- **Role:** Cosmos DB Data Contributor (custom role)
- **Purpose:** Read/write database data
- **Scope:** Cosmos DB account
- **Note:** Custom role via script `scripts/AddCosmosRole.ps1`

#### Key Vault
- **Role:** Key Vault Secrets User
- **Purpose:** Read secrets
- **Scope:** Key Vault resource

#### API Management (Optional)
- **Role:** API Management Service Reader
- **Purpose:** Read APIM configuration
- **Scope:** APIM resource

**Benefits:**
- No credentials in code or configuration
- Automatic credential rotation
- Audit trail of all access
- Fine-grained access control
- Disabled when not needed

**Interactions:**
- **Assigned to:** Container Apps, AI Foundry
- **Authenticates to:** All Azure services
- **Managed by:** Azure AD/Entra ID
- **Monitored via:** Activity logs

---

### 25. Azure Key Vault
**Module:** `modules/security/keyvault.bicep`

**Purpose:**
- Secure storage for secrets, keys, and certificates
- Centralized secret management
- Access auditing and logging

**Configuration:**
- **Public Network Access:** Configurable
- **Private Endpoint:** In Private Endpoints subnet
- **RBAC:** Azure RBAC for access control (not access policies)
- **Soft Delete:** Enabled (90-day retention)
- **Purge Protection:** Enabled for production

**Secrets Stored:**

#### 1. `api-key`
- **Value:** Unique string based on resource group and location
- **Purpose:** API authentication between UI and API apps
- **Generated:** Automatically during deployment
- **Usage:** API Container App validates requests

#### 2. `apimkey`
- **Value:** APIM subscription key
- **Purpose:** Authenticate to APIM gateway
- **Stored:** Only if APIM deployed
- **Usage:** Container Apps call APIM

#### 3. `appInsightsConnectingString`
- **Value:** Application Insights connection string
- **Purpose:** Send telemetry from APIM
- **Stored:** Only if APIM deployed
- **Usage:** APIM logger configuration

#### 4. `managed-identity-id`
- **Value:** Resource ID of managed identity
- **Purpose:** Reference identity in scripts
- **Stored:** Only if APIM deployed
- **Usage:** Configuration and automation

#### 5. `entraclientid`
- **Value:** Entra ID application client ID
- **Purpose:** OAuth authentication
- **Stored:** Only if Entra configured
- **Usage:** UI and API apps for user authentication

#### 6. `entraclientsecret`
- **Value:** Entra ID application client secret
- **Purpose:** OAuth token exchange
- **Stored:** Only if Entra configured
- **Usage:** Backend authentication flow

**Secret Deduplication:**
- Optional script to avoid duplicate secrets
- Disabled for private networks (access issues)
- Lists existing secrets before creating new ones

**Access Control:**
- **Deploying User:** Key Vault Owner (via RBAC)
- **Managed Identity:** Key Vault Secrets User
- **Admin Users:** Configurable via `adminUserObjectIds`

**Interactions:**
- **Accessed by:** Container Apps for secrets
- **Accessed by:** Application Gateway for SSL certificates
- **Accessed by:** Deployment scripts for configuration
- **Authenticated via:** Managed Identity and Azure AD
- **Monitored by:** Audit logs and diagnostic settings

**Best Practices:**
- Secrets rotated regularly
- Access logged and audited
- No secrets in code or config files
- Soft delete prevents accidental loss
- Private endpoint for secure access

---

## API Management

### 26. Azure API Management (Optional)
**Module:** `modules/api-management/apim.bicep`
**Deployed:** Only if `deployAPIM = true`

**Purpose:**
- API gateway for rate limiting and throttling
- Centralized API policies and security
- API versioning and transformation
- Analytics and monitoring

**Configuration:**
- **SKU:** Developer or Consumption (configurable)
- **Publisher Email:** From parameter `apimPublisherEmail`
- **Publisher Name:** From parameter `adminPublisherName`
- **Subscription:** Created with name `aiagent-subscription`
- **Public Access:** External (configurable to internal)

**Components:**

#### API Gateway
- Receives API requests
- Applies policies (rate limiting, authentication, transformation)
- Routes to backends
- Returns responses

#### Publisher Portal
- API documentation
- Developer onboarding
- API testing interface
- Subscription management

#### Developer Portal
- Self-service API access
- Interactive documentation
- Code samples
- Subscription key management

**APIM Configuration Module:**
**Module:** `modules/api-management/apim-oai-config.bicep`

**Sets up:**
- Azure OpenAI backend connection
- API policies for OpenAI endpoints
- Named values for configuration
- Application Insights logger

**Policies Applied:**

#### Rate Limiting
- Requests per second/minute limits
- Token consumption limits
- Quota enforcement

#### Authentication
- Subscription key validation
- JWT token validation (if Entra configured)
- IP filtering

#### Transformation
- Request/response modification
- Header manipulation
- Protocol translation

#### Monitoring
- Request logging to Application Insights
- Performance tracking
- Error logging

**Interactions:**
- **Called by:** API Container App (optional)
- **Calls:** Azure OpenAI as backend
- **Authenticated via:** Subscription keys or JWT tokens
- **Monitored by:** Application Insights logger
- **Secured via:** IP restrictions, subscription keys

**Benefits:**
- Protect Azure OpenAI from direct access
- Implement rate limiting and quotas
- Add caching for improved performance
- Track API usage and analytics
- Monetize APIs with subscriptions
- Version management

**When to Use:**
- Multiple applications sharing OpenAI
- Need for rate limiting beyond Azure OpenAI
- Require API monetization
- Need request/response transformation
- Want centralized API analytics

---

## Monitoring & Observability

### 27. Log Analytics Workspace
**Module:** `modules/monitor/loganalytics.bicep`

**Purpose:**
- Centralized log aggregation and analysis
- Query logs across all resources
- Power Azure Monitor and alerts

**Configuration:**
- **Retention:** 365 days (configurable via `logRetentionInDays`)
- **Pricing Tier:** Pay-as-you-go (per GB)
- **Location:** Same as resource group

**Data Sources:**
- All Azure resources with diagnostic settings
- Application Insights data
- Container logs
- Azure Activity logs
- Security logs

**Key Features:**
- **KQL Queries:** Kusto Query Language for log analysis
- **Workbooks:** Interactive data visualization
- **Alerts:** Metric and log-based alerts
- **Export:** Send data to Storage or Event Hubs
- **Solutions:** Pre-built monitoring solutions

**Common Queries:**

#### Container App Errors
```kql
ContainerAppConsoleLogs_CL
| where Log_s contains "error"
| summarize count() by ContainerName_s, bin(TimeGenerated, 5m)
```

#### API Performance
```kql
requests
| where name contains "api"
| summarize avg(duration), percentiles(duration, 50, 95, 99) by bin(timestamp, 5m)
```

#### Azure OpenAI Token Usage
```kql
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.COGNITIVESERVICES"
| summarize sum(TokenCount_d) by bin(TimeGenerated, 1h)
```

**Interactions:**
- **Receives logs from:** All Azure resources
- **Queried by:** Azure Portal, API, PowerShell
- **Powers:** Dashboards, alerts, workbooks
- **Integrated with:** Application Insights
- **Exported to:** Storage (optional)

---

### 28. Application Insights
**Module:** `modules/monitor/applicationinsights.bicep`
**Type:** Workspace-based

**Purpose:**
- Application Performance Management (APM)
- Distributed tracing
- Real-time monitoring
- User analytics

**Configuration:**
- **Linked to:** Log Analytics Workspace
- **Sampling:** Adaptive (default)
- **Ingestion Limit:** None (pay-as-you-go)

**Telemetry Collected:**

#### Requests
- HTTP requests to Container Apps
- Duration, response code
- Success/failure rates
- Request properties

#### Dependencies
- Calls to Azure OpenAI
- Calls to Cosmos DB
- Calls to Storage
- Calls to AI Search
- External HTTP calls
- SQL queries (if applicable)

#### Exceptions
- Unhandled exceptions
- Stack traces
- Failure rates
- Exception properties

#### Traces
- Custom logging from applications
- Structured logging
- Debug information
- Correlation IDs

#### Metrics
- Custom metrics
- Performance counters
- System metrics

#### Page Views
- UI page loads
- User sessions
- User behavior

**Distributed Tracing:**

Container Apps are configured with:
```
AZURE_SDK_TRACING_IMPLEMENTATION=opentelemetry
AZURE_TRACING_GEN_AI_CONTENT_RECORDING_ENABLED=true
SEMANTICKERNEL_EXPERIMENTAL_GENAI_ENABLE_OTEL_DIAGNOSTICS=true
```

**Trace Flow Example:**
1. User request arrives at UI Container App
   - Request tracked with operation ID
2. UI calls API Container App
   - Linked with parent operation ID
3. API calls Azure OpenAI
   - Tracked as dependency
   - Prompt and response recorded (if enabled)
4. API calls Cosmos DB
   - Tracked as dependency
   - Query details recorded
5. Response returns to user
   - End-to-end duration tracked

**Features:**

#### Live Metrics
- Real-time performance dashboard
- Request rates
- Failure rates
- Server metrics

#### Application Map
- Visual topology of dependencies
- Performance of each component
- Failure rates per dependency

#### Transaction Search
- Find specific transactions
- Drill into details
- View related telemetry

#### Failures
- Exception analysis
- Failure trends
- Impact analysis

#### Performance
- Slow operations
- Dependency performance
- Operation timings

#### Availability
- URL ping tests
- Multi-step web tests
- Uptime monitoring

**Interactions:**
- **Receives telemetry from:** Container Apps, Azure OpenAI, APIM
- **Stores data in:** Log Analytics Workspace
- **Queried via:** Azure Portal, KQL, API
- **Powers:** Dashboards, alerts, workbooks
- **Integrated with:** Azure Monitor alerts

**Gen AI Tracing:**
Special handling for AI operations:
- Prompt text (if content recording enabled)
- Response text (if content recording enabled)
- Token counts
- Model used
- Completion reason
- Latency

---

### 29. Application Gateway Diagnostics
**Diagnostic Settings:** Configured on Application Gateway

**Purpose:**
- Monitor ingress traffic
- Detect and prevent attacks
- Performance analysis
- Troubleshooting

**Logs Sent:**

#### Access Logs
- All HTTP requests
- Client IP, URL, status code
- Backend target
- Response time

#### Performance Logs
- Backend health
- Request/response sizes
- Connection counts

#### Firewall Logs (WAF)
- Blocked requests
- Rule matches
- Attack patterns
- False positives

**Metrics:**
- Request count
- Failed requests
- Response time
- Throughput
- Backend status
- WAF events

**Destinations:**
- Log Analytics Workspace
- Storage Account (long-term retention)

**Use Cases:**
- Identify attack patterns
- Tune WAF rules
- Analyze traffic patterns
- Debug routing issues
- Capacity planning

---

## Resource Interactions

### Complete Data Flow Diagram

```
External User
     |
     | HTTPS
     v
Application Gateway (WAF)
     |
     | HTTP
     v
Container Apps Environment
     |
     +---> UI Container App
     |         |
     |         | Internal HTTP
     |         v
     +---> API Container App
               |
               +---> [Private Endpoint] ---> Azure OpenAI/Foundry
               |         |                       |
               |         |                       v
               |         |                   AI Models (GPT-4o, etc.)
               |         |
               +---> [Private Endpoint] ---> AI Search
               |         |                       |
               |         |                       v
               |         |                   Search Indexes
               |         |
               +---> [Private Endpoint] ---> Cosmos DB
               |         |                       |
               |         |                       v
               |         |                   Databases/Containers
               |         |
               +---> [Private Endpoint] ---> Storage Account
               |         |                       |
               |         |                       v
               |         |                   Blob/Queue/Table
               |         |
               +---> [Private Endpoint] ---> Key Vault
               |         |                       |
               |         |                       v
               |         |                   Secrets
               |         |
               +---> [Private Endpoint] ---> Document Intelligence
               |
               v
          Managed Identity (authenticates all above calls)
               |
               v
          Application Insights (all telemetry)
               |
               v
          Log Analytics Workspace
```

---

## Data Flow Scenarios

### Scenario 1: User Asks a Question (RAG Pattern)

**Step-by-Step Flow:**

1. **User Action:**
   - User types question in UI
   - Browser sends HTTPS request to Application Gateway

2. **Ingress Layer:**
   - Application Gateway receives request
   - WAF inspects for threats
   - Routes to UI Container App

3. **UI Container App:**
   - Receives user question
   - Authenticates user (if Entra ID enabled)
   - Retrieves session from Cosmos DB (`uisessions`)
   - Calls API Container App with question

4. **API Container App:**
   - Receives question from UI
   - Authenticates request (API key or token)
   - Retrieves conversation history from Cosmos DB (`ChatHistory`)

5. **AI Search (Semantic Search):**
   - API calls Azure OpenAI to generate embedding for question
   - API queries AI Search with embedding (vector search)
   - Search returns relevant documents/chunks
   - Documents added to context

6. **Azure OpenAI (Generation):**
   - API constructs prompt with:
     - System message
     - Conversation history
     - Retrieved documents (RAG context)
     - Current question
   - Calls Azure OpenAI (GPT-4o or GPT-4.1)
   - Receives AI-generated response

7. **Store Results:**
   - API saves chat turn to Cosmos DB:
     - User message in `ChatTurn`
     - AI response in `ChatTurn`
     - Update `ChatHistory` with summary
   - Logs operation in `AgentLog`

8. **Return to User:**
   - API returns response to UI Container App
   - UI updates session in Cosmos DB (`uisessions`)
   - UI sends response to browser
   - User sees AI response

**Resources Involved:**
- Application Gateway (ingress)
- UI Container App (frontend)
- API Container App (orchestration)
- Azure OpenAI (embedding + generation)
- AI Search (semantic search)
- Cosmos DB (history, sessions, logs)
- Managed Identity (authentication)
- Application Insights (telemetry)

**Telemetry Captured:**
- Request received at App Gateway
- UI processing time
- API processing time
- OpenAI latency and tokens
- Search query time
- Database read/write times
- End-to-end duration

---

### Scenario 2: Document Upload and Processing

**Step-by-Step Flow:**

1. **User Uploads Document:**
   - User selects file in UI
   - Browser POSTs file to UI Container App

2. **UI Processing:**
   - UI Container App receives file
   - Authenticates user
   - Generates unique document ID
   - Uploads file to Storage Account (`data` container)

3. **API Processing:**
   - UI calls API to process document
   - API retrieves file from Storage Account
   - Saves document metadata to Cosmos DB (`UserDocuments`)

4. **Document Intelligence (Optional):**
   - If PDF/image, call Document Intelligence
   - Extract text, tables, structure
   - Save extracted text to Storage Account

5. **Generate Embeddings:**
   - API chunks text into segments
   - For each chunk:
     - Call Azure OpenAI (text-embedding-ada-002)
     - Generate vector embedding
     - Prepare for indexing

6. **Index in AI Search:**
   - API creates or updates document in search index
   - Fields: document ID, text, vector, metadata
   - Document now searchable

7. **Update Status:**
   - API updates Cosmos DB (`UserDocuments`)
   - Status: "Processed" and "Indexed"
   - Returns success to UI
   - UI shows document in user's list

**Resources Involved:**
- UI Container App (upload)
- API Container App (orchestration)
- Storage Account (file storage)
- Document Intelligence (extraction)
- Azure OpenAI (embeddings)
- AI Search (indexing)
- Cosmos DB (metadata)
- Managed Identity (authentication)

---

### Scenario 3: Background Batch Processing

**Step-by-Step Flow:**

1. **Files Uploaded:**
   - External process uploads files to Storage Account
   - Destination: `batch-input` container

2. **Processing Triggered:**
   - Azure Function or job monitors container (not in bicep, but typical)
   - Detects new files
   - Reads files using Managed Identity

3. **Document Processing:**
   - For each file:
     - Call Document Intelligence
     - Extract data
     - Transform as needed
     - Generate embeddings
     - Index in AI Search

4. **Store Results:**
   - Write processed data to `batch-output` container
   - Update Cosmos DB with processing status
   - Log results in `AgentLog`

5. **Notification (optional):**
   - Send message to Queue Storage
   - Application picks up notification
   - Updates UI or triggers next step

**Resources Involved:**
- Storage Account (input/output)
- Document Intelligence (processing)
- Azure OpenAI (embeddings)
- AI Search (indexing)
- Cosmos DB (status tracking)
- Queue Storage (messaging)
- Managed Identity (authentication)

---

### Scenario 4: Administrator Access via Bastion

**Step-by-Step Flow:**

1. **Administrator Login:**
   - Admin logs into Azure Portal
   - Navigates to Jumpbox VM
   - Clicks "Connect" → "Bastion"

2. **Bastion Authentication:**
   - Azure validates admin's identity
   - Checks RBAC permissions
   - Establishes connection to Bastion service

3. **VM Connection:**
   - Bastion connects to VM private IP
   - Traffic flows through VNET
   - RDP/SSH session established
   - Admin sees VM desktop/terminal

4. **Admin Activities:**
   - Install Azure CLI
   - Run commands against private services
   - Test connectivity to private endpoints
   - Query Cosmos DB
   - Download/upload to Storage Account
   - Run SQL queries (if applicable)

5. **Access Private Services:**
   - VM has access to all private endpoints
   - DNS resolves to private IPs
   - No public internet required
   - All traffic stays in VNET

**Resources Involved:**
- Azure Bastion (secure access)
- Jumpbox VM (management)
- Private Endpoints (service access)
- Private DNS Zones (name resolution)
- VNET (connectivity)

---

### Scenario 5: CI/CD Pipeline Deployment

**Step-by-Step Flow:**

1. **Code Commit:**
   - Developer commits code to GitHub/Azure DevOps
   - Triggers pipeline

2. **Build Stage:**
   - Pipeline builds container images
   - Tags with version number
   - Runs tests

3. **Push to ACR:**
   - Pipeline authenticates to Container Registry
   - Uses service principal or managed identity
   - Pushes images:
     - `{registry}.azurecr.io/api:v1.2.3`
     - `{registry}.azurecr.io/ui:v1.2.3`

4. **Update Container Apps:**
   - Pipeline calls Azure CLI/ARM
   - Updates Container App image references
   - Container Apps Environment pulls new images
   - Performs rolling deployment

5. **Health Checks:**
   - Container Apps performs health checks
   - New revision becomes active
   - Old revision drained and stopped

6. **Verification:**
   - Pipeline runs smoke tests
   - Checks Application Insights for errors
   - Validates deployment success

**Resources Involved:**
- Container Registry (image storage)
- Container Apps (hosting)
- Container Apps Environment (orchestration)
- Application Insights (monitoring)
- Managed Identity (authentication)

---

## Security Boundaries and Trust Zones

### Zone 1: External (Internet)
**Resources:**
- Application Gateway Public IP
- Bastion Public IP

**Access:**
- From: Internet
- To: VNET (restricted)
- Protocol: HTTPS only
- Protection: WAF, DDoS Protection

### Zone 2: DMZ (Application Gateway Subnet)
**Resources:**
- Application Gateway

**Access:**
- From: Internet via Public IP
- To: Container Apps subnet
- Protection: WAF policies, NSG

### Zone 3: Application Tier (App Service Environment Subnet)
**Resources:**
- Container Apps Environment
- API Container App
- UI Container App

**Access:**
- From: Application Gateway
- To: Private Endpoints subnet
- Protection: NSG, Container Apps isolation

### Zone 4: Private Services (Private Endpoints Subnet)
**Resources:**
- All private endpoints

**Access:**
- From: Application tier, management tier
- To: Azure PaaS services (private)
- Protection: Private Link, NSG

### Zone 5: Management (Bastion + Jumpbox Subnets)
**Resources:**
- Azure Bastion
- Jumpbox VM

**Access:**
- From: Azure Portal (Bastion)
- To: All subnets (Jumpbox)
- Protection: Bastion security, NSG, RBAC

### Zone 6: Data Plane (Outside VNET)
**Resources:**
- Azure OpenAI
- AI Search
- Cosmos DB
- Storage Account
- Key Vault
- Document Intelligence

**Access:**
- Via: Private endpoints only (when configured)
- Protection: RBAC, private link, encryption

---

## Performance Considerations

### Latency Optimization

**Network:**
- Private endpoints reduce latency vs public internet
- Resources in same region minimize distance
- Availability zones increase resilience

**Caching:**
- AI Search caches search results
- Application Gateway caches static content
- Container Apps use CDN for assets (optional)

**Scaling:**
- Container Apps auto-scale based on load
- Application Gateway auto-scales instances
- Cosmos DB auto-scales throughput

### Cost Optimization

**Right-Sizing:**
- Basic AI Search for development
- D4 workload profile for Container Apps
- B-series VMs for jumpbox

**Auto-Scaling:**
- Scale down during low usage
- Scale to zero (if supported)
- Burstable VM sizes

**Data Management:**
- Cosmos DB TTL for old data
- Storage lifecycle policies
- Log Analytics retention policies

---

## Disaster Recovery and Business Continuity

### Backup Strategy

**Cosmos DB:**
- Continuous backup (7-30 days)
- Periodic backup (configurable)
- Point-in-time restore

**Storage Account:**
- Geo-redundant storage (optional)
- Soft delete for blobs
- Versioning

**Configuration:**
- Infrastructure as Code (Bicep)
- Version controlled
- Automated deployment

### High Availability

**Application Gateway:**
- Zone-redundant (1, 2, 3)
- Multiple instances
- Health probes

**Container Apps:**
- Multiple replicas
- Zone redundancy
- Health checks

**Data Services:**
- Cosmos DB multi-region (configurable)
- Storage ZRS/GRS (configurable)
- AI services regional failover

---

## Summary

This deployment creates a comprehensive, secure, and scalable Azure AI Landing Zone with:

✅ **Network Isolation:** Private networking with 8 subnets
✅ **Secure Access:** Bastion for management, Application Gateway for users
✅ **AI Services:** OpenAI, AI Search, Document Intelligence
✅ **Data Storage:** Cosmos DB, Storage Account
✅ **Compute:** Container Apps for scalable applications
✅ **Security:** Managed Identity, Key Vault, Private Endpoints
✅ **Monitoring:** Application Insights, Log Analytics
✅ **Optional:** API Management, Jumpbox VM

All resources work together to provide a production-ready platform for AI agent applications with enterprise-grade security, scalability, and observability.

---

*Document Version: 1.0*  
*Based on: main-advanced.bicep*  
*Last Updated: October 2, 2025*
