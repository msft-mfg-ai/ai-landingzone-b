# Networking Configuration Guide for AI Landing Zones

## Overview

This guide provides detailed configuration instructions for implementing networking components in Azure AI Landing Zones. Each section includes practical examples, configuration parameters, and best practices.

## Virtual Network Configuration

### 1. VNet Setup

**Bicep Configuration Example**:
```bicep
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-ai-landing-zone'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'  // Main address space
      ]
    }
    enableDdosProtection: false
    enableVmProtection: false
  }
}
```

**Key Configuration Parameters**:
- **Address Space**: Plan for growth, use /16 for large deployments
- **DNS Servers**: Configure custom DNS if required
- **DDoS Protection**: Enable for production workloads
- **Peering**: Configure for multi-VNet scenarios

### 2. Subnet Configuration

**Application Subnet**:
```bicep
resource appSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  parent: virtualNetwork
  name: 'snet-app'
  properties: {
    addressPrefix: '10.0.1.0/24'
    networkSecurityGroup: {
      id: appNsg.id
    }
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
  }
}
```

**Private Endpoints Subnet**:
```bicep
resource privateEndpointSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  parent: virtualNetwork
  name: 'snet-private-endpoints'
  properties: {
    addressPrefix: '10.0.2.0/24'
    networkSecurityGroup: {
      id: privateEndpointNsg.id
    }
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
  }
}
```

**Configuration Notes**:
- **privateEndpointNetworkPolicies**: Must be 'Disabled' for private endpoints
- **privateLinkServiceNetworkPolicies**: Typically 'Disabled' for flexibility
- **delegations**: Required for some services (e.g., Container Apps)

## Network Security Groups Configuration

### 3. Application Tier NSG

```bicep
resource appNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-app-subnet'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHttpsInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '10.0.1.0/24'
        }
      }
      {
        name: 'AllowHttpInbound'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '10.0.1.0/24'
        }
      }
      {
        name: 'AllowAIServicesOutbound'
        properties: {
          priority: 200
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '10.0.1.0/24'
          destinationAddressPrefix: '10.0.2.0/24'
        }
      }
      {
        name: 'AllowAzureMonitorOutbound'
        properties: {
          priority: 300
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: ['443', '12000']
          sourceAddressPrefix: '10.0.1.0/24'
          destinationAddressPrefix: 'AzureMonitor'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4000
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}
```

### 4. Private Endpoints NSG

```bicep
resource privateEndpointNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-private-endpoints'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowAppSubnetInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '10.0.1.0/24'
          destinationAddressPrefix: '10.0.2.0/24'
        }
      }
      {
        name: 'AllowManagementInbound'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '10.0.3.0/24'
          destinationAddressPrefix: '10.0.2.0/24'
        }
      }
      {
        name: 'DenyAllOtherInbound'
        properties: {
          priority: 4000
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}
```

## Private Endpoint Configuration

### 5. Azure OpenAI Private Endpoint

```bicep
resource openAIPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: 'pe-openai'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'openai-connection'
        properties: {
          privateLinkServiceId: openAIAccount.id
          groupIds: [
            'account'
          ]
        }
      }
    ]
  }
}
```

### 6. Azure AI Search Private Endpoint

```bicep
resource searchPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: 'pe-search'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'search-connection'
        properties: {
          privateLinkServiceId: searchService.id
          groupIds: [
            'searchService'
          ]
        }
      }
    ]
  }
}
```

### 7. Storage Account Private Endpoints

```bicep
resource storagePrivateEndpointBlob 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: 'pe-storage-blob'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'storage-blob-connection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

resource storagePrivateEndpointFile 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: 'pe-storage-file'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'storage-file-connection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'file'
          ]
        }
      }
    ]
  }
}
```

## Private DNS Zone Configuration

### 8. DNS Zone Setup

```bicep
resource openAIPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.openai.azure.com'
  location: 'global'
}

resource searchPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.search.windows.net'
  location: 'global'
}

resource blobPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.blob.core.windows.net'
  location: 'global'
}

resource filePrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.file.core.windows.net'
  location: 'global'
}
```

### 9. VNet Links

```bicep
resource openAIVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: openAIPrivateDnsZone
  name: 'vnet-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetwork.id
    }
  }
}

resource searchVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: searchPrivateDnsZone
  name: 'vnet-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetwork.id
    }
  }
}
```

### 10. DNS Zone Groups

```bicep
resource openAIDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  parent: openAIPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'openai-config'
        properties: {
          privateDnsZoneId: openAIPrivateDnsZone.id
        }
      }
    ]
  }
}

resource searchDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  parent: searchPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'search-config'
        properties: {
          privateDnsZoneId: searchPrivateDnsZone.id
        }
      }
    ]
  }
}
```

## Application Gateway Configuration

### 11. Public Frontend Setup

```bicep
resource applicationGateway 'Microsoft.Network/applicationGateways@2023-09-01' = {
  name: 'agw-ai-landing-zone'
  location: location
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
      capacity: 2
    }
    gatewayIPConfigurations: [
      {
        name: 'agw-ip-config'
        properties: {
          subnet: {
            id: agwSubnet.id
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'agw-frontend-ip'
        properties: {
          publicIPAddress: {
            id: agwPublicIP.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'agw-frontend-port-80'
        properties: {
          port: 80
        }
      }
      {
        name: 'agw-frontend-port-443'
        properties: {
          port: 443
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'agw-backend-pool'
        properties: {
          backendAddresses: [
            {
              fqdn: 'app.internal.example.com'
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'agw-backend-http-settings'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 30
        }
      }
    ]
    httpListeners: [
      {
        name: 'agw-http-listener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', 'agw-ai-landing-zone', 'agw-frontend-ip')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', 'agw-ai-landing-zone', 'agw-frontend-port-80')
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'agw-routing-rule'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', 'agw-ai-landing-zone', 'agw-http-listener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', 'agw-ai-landing-zone', 'agw-backend-pool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', 'agw-ai-landing-zone', 'agw-backend-http-settings')
          }
        }
      }
    ]
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Prevention'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.2'
    }
  }
}
```

## Container Apps Environment Configuration

### 12. Container Apps with VNet Integration

```bicep
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: 'cae-ai-landing-zone'
  location: location
  properties: {
    vnetConfiguration: {
      infrastructureSubnetId: containerAppsSubnet.id
      internal: true
    }
    zoneRedundant: false
  }
}
```

## Monitoring and Diagnostics Configuration

### 13. Network Watcher Setup

```bicep
resource networkWatcher 'Microsoft.Network/networkWatchers@2023-09-01' = {
  name: 'nw-${location}'
  location: location
  properties: {}
}

resource flowLogs 'Microsoft.Network/networkWatchers/flowLogs@2023-09-01' = {
  parent: networkWatcher
  name: 'fl-app-nsg'
  location: location
  properties: {
    targetResourceId: appNsg.id
    storageId: storageAccount.id
    enabled: true
    retentionPolicy: {
      days: 7
      enabled: true
    }
    format: {
      type: 'JSON'
      version: 2
    }
  }
}
```

## Configuration Best Practices

### Security Configuration
1. **Least Privilege**: Grant minimal required access
2. **Defense in Depth**: Multiple security layers
3. **Regular Updates**: Keep security rules current
4. **Monitoring**: Comprehensive logging and alerting

### Performance Configuration
1. **Right-sizing**: Appropriate SKUs for workload
2. **Caching**: Implement where appropriate
3. **Load Balancing**: Distribute traffic effectively
4. **Auto-scaling**: Handle varying loads

### Reliability Configuration
1. **Redundancy**: Multiple availability zones
2. **Health Checks**: Monitor service health
3. **Failover**: Automatic failover mechanisms
4. **Backup**: Network configuration backups

### Cost Optimization
1. **Resource Sizing**: Match capacity to demand
2. **Reserved Instances**: For predictable workloads
3. **Automation**: Reduce operational overhead
4. **Monitoring**: Track and optimize costs

## Validation and Testing

### Connectivity Testing
```bash
# Test private endpoint connectivity
nslookup myaiservice.openai.azure.com

# Test NSG rules
az network watcher connectivity-check \
  --source-resource /subscriptions/.../virtualMachines/test-vm \
  --dest-address 10.0.2.4 \
  --dest-port 443

# Test application gateway
curl -I https://myapp.example.com
```

### Security Validation
```bash
# Verify NSG effective rules
az network nic list-effective-nsg \
  --name myapp-nic \
  --resource-group myapp-rg

# Test firewall rules
az network application-gateway waf-policy show \
  --name myapp-waf-policy \
  --resource-group myapp-rg
```

## Related Documentation

### Internal Guides
- [Traffic Flow Analysis](./networking-traffic-flow.md)
- [Security Configuration](../security/network-security.md)
- [Troubleshooting Guide](../troubleshooting/networking-troubleshooting.md)
- [Performance Optimization](../fundamentals/performance-optimization.md)

### Microsoft Documentation References

#### Infrastructure as Code
- [Azure Bicep documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Bicep best practices](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/best-practices)
- [Azure Resource Manager templates](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/)
- [Template reference for networking resources](https://docs.microsoft.com/en-us/azure/templates/microsoft.network/)

#### Virtual Network Configuration
- [Create a virtual network using Bicep](https://docs.microsoft.com/en-us/azure/virtual-network/quick-create-bicep)
- [Virtual network configuration parameters](https://docs.microsoft.com/en-us/azure/virtual-network/manage-virtual-network)
- [Plan and design Azure virtual networks](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-vnet-plan-design-arm)
- [Subnet configuration and management](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-manage-subnet)

#### Network Security Groups Configuration
- [Create network security group using Bicep](https://docs.microsoft.com/en-us/azure/virtual-network/tutorial-filter-network-traffic-bicep)
- [Network security group rules](https://docs.microsoft.com/en-us/azure/virtual-network/network-security-groups-overview#security-rules)
- [Augmented security rules](https://docs.microsoft.com/en-us/azure/virtual-network/network-security-groups-overview#augmented-security-rules)
- [Default security rules](https://docs.microsoft.com/en-us/azure/virtual-network/network-security-groups-overview#default-security-rules)

#### Private Endpoints Configuration
- [Create a private endpoint using Bicep](https://docs.microsoft.com/en-us/azure/private-link/create-private-endpoint-bicep)
- [Private endpoint configuration](https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-overview#private-endpoint-properties)
- [Private DNS zone groups](https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-dns#azure-services-dns-zone-configuration)
- [Supported services for private endpoints](https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-overview#private-link-resource)

#### DNS Configuration
- [Private DNS zones using Bicep](https://docs.microsoft.com/en-us/azure/dns/private-dns-getstarted-bicep)
- [Virtual network links](https://docs.microsoft.com/en-us/azure/dns/private-dns-virtual-network-links)
- [DNS zone configuration](https://docs.microsoft.com/en-us/azure/dns/dns-zones-records)
- [Private endpoint DNS configuration](https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-dns)

#### Application Gateway Configuration
- [Application Gateway using Bicep](https://docs.microsoft.com/en-us/azure/application-gateway/quick-create-bicep)
- [Application Gateway configuration overview](https://docs.microsoft.com/en-us/azure/application-gateway/configuration-overview)
- [Web Application Firewall configuration](https://docs.microsoft.com/en-us/azure/web-application-firewall/ag/ag-overview)
- [SSL termination and end-to-end SSL](https://docs.microsoft.com/en-us/azure/application-gateway/ssl-overview)

#### Container Apps Configuration
- [Container Apps with VNet integration](https://docs.microsoft.com/en-us/azure/container-apps/networking)
- [Container Apps environment with Bicep](https://docs.microsoft.com/en-us/azure/container-apps/azure-resource-manager-api-spec)
- [Internal Container Apps environment](https://docs.microsoft.com/en-us/azure/container-apps/vnet-custom-internal)

#### Monitoring and Diagnostics
- [Network Watcher using Bicep](https://docs.microsoft.com/en-us/azure/network-watcher/network-watcher-create)
- [NSG flow logs configuration](https://docs.microsoft.com/en-us/azure/network-watcher/network-watcher-nsg-flow-logging-portal)
- [Connection monitor configuration](https://docs.microsoft.com/en-us/azure/network-watcher/connection-monitor-create-using-portal)
- [Network performance monitoring](https://docs.microsoft.com/en-us/azure/azure-monitor/insights/network-performance-monitor)

#### Validation and Testing
- [Azure CLI networking commands](https://docs.microsoft.com/en-us/cli/azure/network)
- [PowerShell networking cmdlets](https://docs.microsoft.com/en-us/powershell/module/az.network/)
- [Network troubleshooting tools](https://docs.microsoft.com/en-us/azure/network-watcher/network-watcher-monitoring-overview)
- [Connectivity testing](https://docs.microsoft.com/en-us/azure/network-watcher/network-watcher-connectivity-portal)