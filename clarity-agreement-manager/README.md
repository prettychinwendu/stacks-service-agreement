# Service Agreement Smart Contract

This smart contract enables the creation and management of service agreements between service providers and clients on the Stacks blockchain. It provides a trustless platform for establishing, executing, and resolving service-based relationships.

## Overview

The Service Agreement Smart Contract allows parties to create binding agreements with defined terms, manage payment expectations, track provider performance, and handle potential disputes. The contract serves as an intermediary, maintaining the state of agreements while allowing appropriate interactions from authorized parties.

## Features

- **Agreement Creation**: Establish service agreements with specific terms
- **Status Management**: Track agreements through their lifecycle (Pending, Active, Completed, Disputed, Cancelled)
- **Performance Metrics**: Maintain provider reputation through ratings and completion statistics
- **Dispute Resolution**: Built-in mechanism for filing and resolving disputes with third-party mediation
- **Rating System**: Client feedback mechanism to build provider reputation

## Contract Data Structures

The contract uses three primary data maps:

1. **ServiceAgreementDetails**: Stores the core information about each agreement
2. **ProviderPerformanceMetrics**: Maintains provider reputation and statistics
3. **DisputeRecordDetails**: Records information about disputes and their resolution

## Public Functions

### Administrative Functions

- `initialize-contract`: Set a new contract administrator
  
### Agreement Management

- `create-service-agreement`: Create a new service agreement with specified terms
- `accept-service-agreement`: Provider accepts the terms of a pending agreement
- `complete-service-agreement`: Client marks an agreement as successfully completed
- `file-service-dispute`: Either party can file a dispute on an active agreement
- `resolve-service-dispute`: Admin resolves a dispute with supporting details

### Reputation Management

- `submit-provider-rating`: Submit a rating (1-5) for a service provider

### Read-Only Functions

- `get-service-agreement-details`: Retrieve details about a specific agreement
- `get-provider-metrics`: View a provider's performance metrics
- `get-dispute-details`: Retrieve information about a dispute

## Error Codes

| Code | Description |
|------|-------------|
| u100 | Unauthorized access attempt |
| u101 | Agreement already exists |
| u102 | Agreement not found |
| u103 | Invalid agreement status |
| u104 | Insufficient payment amount |
| u105 | Invalid principal address |
| u106 | Invalid input parameters |

## Agreement Lifecycle

1. **Creation**: Client creates an agreement (PENDING status)
2. **Acceptance**: Provider accepts the agreement (ACTIVE status)
3. **Completion**: Client marks the agreement as completed (COMPLETED status)

Alternative flows:
- **Dispute**: Either party files a dispute (DISPUTED status)
- **Resolution**: Admin resolves the dispute (status determined by resolution)

## Usage Examples

### Creating a Service Agreement

```clarity
(create-service-agreement 
    u1                                    ;; agreement-id
    'SP2JXKH6GJR3TNPQKZ5PZRT7K6PSMA5D0ZWE9T50  ;; provider principal
    'SP1QR087ZD2QNMBJ6YHCT4VNJE8WJKZ86N130F2N9  ;; client principal
    u1645564800                           ;; start timestamp
    u1648156800                           ;; end timestamp
    u1000000                              ;; payment amount (in microSTX)
    "Website development with 5 pages and responsive design"  ;; service details
)
```

### Accepting an Agreement (Provider)

```clarity
(accept-service-agreement u1)
```

### Completing an Agreement (Client)

```clarity
(complete-service-agreement u1)
```

### Filing a Dispute

```clarity
(file-service-dispute 
    u1  ;; agreement-id
    "Service provider did not deliver all required functionality as specified"
)
```

## Security Considerations

- The contract validates all principal addresses to prevent self-dealing
- Only authorized parties can modify agreement status
- Agreement states follow a predefined flow to prevent invalid transitions
- Input validation ensures data integrity

## Implementation Notes

- Description texts are limited to 256 ASCII characters
- Provider ratings are stored as a weighted average
- The contract administrator serves as the final arbiter for disputes