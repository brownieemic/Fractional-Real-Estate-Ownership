# 🏠 Fractional Real Estate Ownership

A Clarity smart contract enabling tokenized property ownership on the Stacks blockchain. Investors can buy, sell, and trade fractions of real estate properties as fungible tokens.

## 🎯 Features

### 🏢 Property Management
- **Create Properties**: Register new real estate properties with tokenized ownership
- **Property Details**: Store address, total value, and token supply information
- **Status Control**: Enable/disable property trading

### 💰 Token Trading
- **Direct Purchase**: Buy property tokens directly from the property owner
- **Marketplace Listings**: List tokens for sale at custom prices
- **Peer-to-Peer Trading**: Transfer tokens between users
- **Platform Fees**: Built-in fee system for transactions (2.5% default)

### 📊 Dividend Distribution
- **Dividend Payments**: Property owners can distribute rental income to token holders
- **Proportional Claims**: Token holders claim dividends based on their ownership percentage
- **Claim Tracking**: Prevent double-claiming with blockchain-based verification

## 🚀 Usage Instructions

### Creating a Property
```clarity
(contract-call? .fractional-real-estate create-property 
  "123 Main St, New York, NY" 
  u1000000  ;; Property value in microSTX
  u100)     ;; Total tokens
```

### Buying Property Tokens
```clarity
(contract-call? .fractional-real-estate buy-tokens 
  u1        ;; Property ID
  u10)      ;; Number of tokens to buy
```

### Listing Tokens for Sale
```clarity
(contract-call? .fractional-real-estate list-tokens-for-sale 
  u1        ;; Property ID
  u5        ;; Tokens to sell
  u12000)   ;; Price per token in microSTX
```

### Buying from Marketplace
```clarity
(contract-call? .fractional-real-estate buy-from-listing 
  u1                    ;; Property ID
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7  ;; Seller address
  u3)                   ;; Number of tokens
```

### Distributing Dividends
```clarity
(contract-call? .fractional-real-estate distribute-dividends 
  u1        ;; Property ID
  u50000)   ;; Total dividend amount in microSTX
```

### Claiming Dividends
```clarity
(contract-call? .fractional-real-estate claim-dividends u1)  ;; Property ID
```

## 📖 Read-Only Functions

### Get Property Information
```clarity
(contract-call? .fractional-real-estate get-property u1)
```

### Check User Token Balance
```clarity
(contract-call? .fractional-real-estate get-user-tokens 
  u1 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

### View Marketplace Listing
```clarity
(contract-call? .fractional-real-estate get-property-listing 
  u1 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

### Get Dividend Information
```clarity
(contract-call? .fractional-real-estate get-property-dividends u1)
```

## ⚙️ Configuration

### Platform Fee Management
Only the contract owner can modify the platform fee:
```clarity
(contract-call? .fractional-real-estate set-platform-fee u300)  ;; 3% fee
```

### Property Status Toggle
Property owners can enable/disable trading:
```clarity
(contract-call? .fractional-real-estate toggle-property-status u1)
```

## 🔒 Security Features

- **Authorization Checks**: Only authorized users can perform sensitive operations
- **Balance Verification**: Ensures sufficient token/STX balances before transactions
- **Double-Claim Prevention**: Blockchain-based dividend claim tracking
- **Property Status Controls**: Owners can pause trading when needed

## 🏗️ Contract Architecture

### Data Structures
- **Properties Map**: Core property information and metadata
- **Property Ownership**: Token balance tracking per user per property
- **Property Sales**: Marketplace listing management
- **Dividend System**: Distribution and claim tracking

### Error Codes
- `u100`: Not authorized
- `u101`: Property not found
- `u102`: Insufficient balance
- `u103`: Property already exists
- `u104`: Invalid amount
- `u105`: Transfer failed
- `u106`: Not owner
- `u107`: Property not active
- `u108`: Invalid price
- `u109`: Insufficient funds

## 🧪 Testing

Run tests using Clarinet:
```bash
clarinet test
```

## 📋 Development

### Prerequisites
- Clarinet CLI
- Node.js (for additional tooling)

### Setup
```bash
git clone <repository-url>
cd fractional-real-estate-ownership
clarinet check
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and check for compilation errors
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.
