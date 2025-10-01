# Learning Resources

This folder contains educational materials and learning resources for understanding and working with AI landing zones on Azure.

## Contents

This folder is organized to provide structured learning materials covering:

- **Azure AI Services**: Guides for Azure OpenAI, Cognitive Services, and AI Search
- **Infrastructure as Code**: Learning materials for Bicep, ARM templates, and Azure deployment patterns
- **Security & Governance**: Best practices for AI workload security and compliance
- **Architecture Patterns**: Common patterns and design principles for AI solutions
- **Hands-on Labs**: Step-by-step tutorials and exercises
- **Troubleshooting**: Common issues and their solutions

## Featured Content

### 🌐 Networking Architecture Documentation

Comprehensive guides covering Azure AI Landing Zone networking patterns, components, and traffic flows:

#### [Networking Architecture Overview](./architecture/networking-architecture.md)
Learn the foundational networking principles and high-level architecture patterns for secure AI workloads. This guide covers:
- Zero Trust network architecture principles
- Network segmentation strategies
- Private connectivity patterns
- Integration with Azure AI services
- **Start here** if you're new to Azure AI networking concepts

#### [Networking Components Guide](./architecture/networking-components.md)
Deep dive into the specific Azure networking resources used in AI landing zones. This comprehensive reference covers:
- Virtual Networks (VNets) and Subnets
- Private Link and Private Endpoints
- Network Security Groups (NSGs) and Application Security Groups (ASGs)
- Private DNS Zones and name resolution
- Load balancers and traffic distribution
- **Use this** as a detailed reference for understanding each networking component

#### [Networking Configuration Guide](./architecture/networking-configuration.md)
Practical implementation guide with real-world configuration examples. This hands-on guide includes:
- Complete Bicep templates for all networking components
- NSG rule configurations with security best practices
- Private endpoint setup for Azure AI services
- DNS zone configuration and VNet linking
- Application Gateway and WAF configuration
- **Follow this** when implementing networking infrastructure

#### [Network Traffic Flow Analysis](./architecture/networking-traffic-flow.md)
Complete end-to-end analysis of network traffic from web applications to Azure AI Foundry services. This detailed guide covers:
- Step-by-step network flow walkthrough
- DNS resolution process and private zone routing
- Security enforcement points and rule evaluation
- Performance characteristics and optimization
- Troubleshooting common connectivity issues
- **Reference this** for understanding how traffic flows and resolving network issues

## Structure

```
learn/
├── README.md                 # This file
├── fundamentals/            # Basic concepts and getting started
├── azure-ai-services/       # AI-specific service documentation
├── infrastructure/          # IaC and deployment learning materials
├── security/               # Security and compliance guides
├── architecture/           # Design patterns and best practices
├── labs/                   # Hands-on exercises and tutorials
└── troubleshooting/        # Common issues and solutions
```

## Getting Started

### For Beginners
1. Start with the **[Networking Architecture Overview](./architecture/networking-architecture.md)** to understand core concepts
2. Review the **[Networking Components Guide](./architecture/networking-components.md)** to learn about specific Azure resources
3. Work through the `fundamentals/` folder for basic Azure AI concepts

### For Implementers
1. Use the **[Networking Configuration Guide](./architecture/networking-configuration.md)** for hands-on implementation
2. Reference the **[Network Traffic Flow Analysis](./architecture/networking-traffic-flow.md)** for understanding data flows
3. Work through the `labs/` folder for practical exercises

### For Troubleshooters
1. Start with the **[Network Traffic Flow Analysis](./architecture/networking-traffic-flow.md)** to understand expected behavior
2. Reference the `troubleshooting/` folder for common issues and solutions
3. Use the **[Networking Components Guide](./architecture/networking-components.md)** for configuration reference

## Contributing

When adding new learning materials:
- Use clear, descriptive filenames
- Include practical examples and code snippets
- Link to official Microsoft documentation where appropriate
- Keep content up-to-date with the latest Azure services and features

## Additional Resources

### Azure Documentation
- [Azure AI Documentation](https://docs.microsoft.com/en-us/azure/ai-services/)
- [Azure Architecture Center](https://docs.microsoft.com/en-us/azure/architecture/)
- [Azure OpenAI Service Documentation](https://docs.microsoft.com/en-us/azure/cognitive-services/openai/)
- [Azure Private Link Documentation](https://docs.microsoft.com/en-us/azure/private-link/)
- [Azure Virtual Network Documentation](https://docs.microsoft.com/en-us/azure/virtual-network/)

### Related Learning Paths
- [Azure AI Fundamentals](https://docs.microsoft.com/en-us/learn/paths/get-started-with-artificial-intelligence-on-azure/)
- [Azure Networking Fundamentals](https://docs.microsoft.com/en-us/learn/paths/azure-networking-fundamentals/)
- [Azure Security Best Practices](https://docs.microsoft.com/en-us/learn/paths/azure-security/)

### Quick Reference
- **Architecture Patterns**: See `architecture/` folder for design patterns and networking guides
- **Implementation**: Use `infrastructure/` folder for IaC templates and deployment guides
- **Security**: Reference `security/` folder for best practices and compliance
- **Hands-on Practice**: Work through `labs/` folder exercises
- **Problem Solving**: Check `troubleshooting/` folder for common issues