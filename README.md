# VaultForge Protocol

> Revolutionary over-collateralized lending protocol with intelligent liquidation engine

## Overview

VaultForge represents the next evolution in DeFi lending infrastructure. Built on Stacks, this protocol combines military-grade security with institutional-level risk management. Features include dynamic interest compounding, automated liquidation cascades, and sophisticated collateral optimization algorithms that maximize capital efficiency while maintaining bulletproof solvency guarantees.

## 🏗️ System Architecture

### Core Components

```text
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Collateral    │    │   Lending       │    │  Liquidation    │
│   Management    │◄──►│   Operations    │◄──►│   Engine        │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │              ┌─────────────────┐              │
         └─────────────►│  Interest Rate  │◄─────────────┘
                        │    Engine       │
                        └─────────────────┘
                                 │
                        ┌─────────────────┐
                        │   Protocol      │
                        │   Treasury      │
                        └─────────────────┘
```

### Contract Architecture

The VaultForge Protocol consists of several interconnected modules:

1. **Collateral Management**: Handles STX deposits and withdrawals
2. **Lending Operations**: Manages loan creation and borrowing logic
3. **Interest Accrual Engine**: Calculates and compounds interest over time
4. **Liquidation Engine**: Automated liquidation for unhealthy positions
5. **Protocol Treasury**: Fee collection and protocol revenue management
6. **Risk Management**: Real-time health monitoring and safety mechanisms

## 📊 Key Features

### Risk Management Parameters

- **Collateral Ratio**: 150% minimum collateral requirement
- **Liquidation Threshold**: 130% automatic liquidation trigger
- **Interest Rate**: 5.0% annual rate with block-level compounding
- **Protocol Fee**: 1.0% fee on accrued interest

### Security Features

- Over-collateralized loans ensure protocol solvency
- Automated liquidation prevents bad debt accumulation
- Emergency pause functionality for protocol safety
- Strict access controls and authorization checks

## 🔧 Core Functions

### Collateral Management

```clarity
;; Deposit STX as collateral
(deposit (amount uint))

;; Withdraw available collateral
(withdraw (amount uint))
```

### Lending Operations

```clarity
;; Create a collateralized loan
(borrow (collateral-amount uint) (loan-amount uint))

;; Repay loan (partial or full)
(repay-loan (loan-id uint) (repay-amount uint))
```

### Liquidation

```clarity
;; Liquidate unhealthy loans
(liquidate (loan-id uint))
```

### Read-Only Functions

```clarity
;; Get user's deposit balance
(get-user-deposit (user principal))

;; Get loan details
(get-loan-details (loan-id uint))

;; Check loan health status
(get-loan-health (loan-id uint))

;; Get protocol statistics
(get-protocol-stats)
```

## 🔄 Data Flow

### Borrowing Process

1. User deposits STX collateral via `deposit()`
2. User calls `borrow()` with desired loan amount
3. System validates collateral ratio (≥150%)
4. Loan position is created and STX is transferred to user
5. Interest begins accruing immediately

### Repayment Process

1. User calls `repay-loan()` with STX amount
2. Interest is calculated and updated
3. Payment is applied (interest first, then principal)
4. If fully repaid, collateral is released
5. Protocol fees are collected from accrued interest

### Liquidation Process

1. Monitor continuously checks loan health
2. When collateral ratio drops below 130%, loan becomes liquidatable
3. Liquidator calls `liquidate()` and pays off debt
4. Liquidator receives collateral + 5% bonus
5. Protocol collects fee from liquidation bonus

## 📈 Economic Model

### Interest Calculation

Interest is calculated per block using the formula:

```text
Interest = Principal × (Annual Rate / Blocks Per Year) × Blocks Elapsed
```

### Collateral Ratio

```text
Collateral Ratio = (Collateral Amount × 1000) / (Loan Amount + Accrued Interest)
```

### Fee Structure

- **Protocol Fee**: 1.0% of all accrued interest
- **Liquidation Bonus**: 5.0% of collateral value
- **Liquidation Fee**: 50% of liquidation bonus goes to protocol

## 🛠️ Development Setup

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) for Stacks development
- Node.js 18+ for testing framework
- TypeScript for type-safe testing

### Installation

```bash
# Clone the repository
git clone https://github.com/saviour-frank/vault-forge.git
cd vault-forge

# Install dependencies
npm install

# Run contract checks
clarinet check

# Run tests
npm test
```

### Project Structure

```text
vault-forge/
├── contracts/
│   └── vault-forge.clar       # Main protocol contract
├── tests/
│   └── vault-forge.test.ts    # Comprehensive test suite
├── settings/
│   ├── Devnet.toml            # Development network config
│   ├── Testnet.toml           # Testnet configuration
│   └── Mainnet.toml           # Mainnet configuration
├── Clarinet.toml              # Project configuration
└── README.md                  # This file
```

## 🧪 Testing

The protocol includes comprehensive tests covering:

- Collateral deposit and withdrawal
- Loan creation and validation
- Interest accrual calculations
- Liquidation scenarios
- Edge cases and error conditions

```bash
# Run all tests
npm test

# Check contract syntax
clarinet check

# Run specific test file
npx vitest tests/vault-forge.test.ts
```

## 🔒 Security Considerations

### Audit Status

⚠️ **This contract has not been audited yet. Use at your own risk.**

### Known Risks

- Smart contract risk: Bugs in contract logic
- Liquidation risk: Rapid price movements may cause liquidation
- Protocol risk: Governance and parameter changes
- Stacks blockchain risk: Network-specific risks

### Best Practices

- Start with small amounts to test functionality
- Monitor your collateral ratio regularly
- Understand liquidation mechanics before borrowing
- Keep buffer above minimum collateral requirements

## 📚 Documentation

### Error Codes

- `401`: Not authorized
- `402`: Insufficient balance
- `403`: Invalid amount
- `404`: Insufficient collateral
- `405`: Loan not found
- `406`: Loan already exists
- `407`: Math overflow
- `408`: Loan not liquidatable
- `409`: Loan not repayable
- `410`: Invalid loan ID

### Constants

| Parameter | Value | Description |
|-----------|-------|-------------|
| COLLATERAL_RATIO | 150% | Minimum collateral requirement |
| LIQUIDATION_THRESHOLD | 130% | Liquidation trigger point |
| INTEREST_RATE_YEARLY | 5.0% | Annual interest rate |
| PROTOCOL_FEE_PERCENT | 1.0% | Protocol fee on interest |
| BLOCKS_PER_YEAR | 52,560 | Estimated blocks per year |

## 🤝 Contributing

We welcome contributions to improve VaultForge Protocol! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

VaultForge Protocol is experimental software. Use at your own risk. The developers assume no responsibility for any losses incurred through the use of this software. Always do your own research and consider the risks before using any DeFi protocol.

## 🔗 Links

- **Repository**: [GitHub](https://github.com/saviour-frank/vault-forge)
- **Stacks Explorer**: [View on Explorer](https://explorer.stacks.co)
- **Documentation**: [Protocol Docs](https://vault-forge.docs)
- **Discord**: [Community Chat](https://discord.gg/vault-forge)

---

Built with ❤️ on [Stacks](https://stacks.co) blockchain.
