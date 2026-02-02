# LINE Token Marketplace

A decentralized NFT auction marketplace built with Solidity and Foundry. Features automated auction settlement via Chainlink Automation, anti-snipe protection, and pull-based refund mechanism.

## Features

- **NFT Auctions** - Create timed auctions for ERC721 NFTs
- **LINE Token Bidding** - Bid using the native LINE ERC20 token
- **Anti-Snipe Protection** - Bids in final 5 minutes extend auction
- **Automated Settlement** - Chainlink Automation handles auction finalization
- **Pull-Based Refunds** - Outbid users can claim refunds securely

## Architecture

```
src/
├── marketplace/Marketplace.sol  # Core auction contract
├── LineToken/LineToken.sol      # ERC20 token for bidding
└── nft/Nft.sol                  # ERC721 NFT contract

script/
├── DeployMarketplace.s.sol      # Marketplace deployment
├── MarketplaceInteractions.s.sol # Interaction scripts
└── Interactions.s.sol           # Token interactions

test/
├── unit/                        # Unit tests
└── integration/                 # Integration tests
```

## Quick Start

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js (optional, for additional tooling)

### Install
```bash
git clone <repo-url>
cd line-solidity
forge install
```

### Build
```bash
make build
```

### Test
```bash
# All tests
make test

# Unit tests only
make test-unit

# Integration tests only
make test-integration
```

## Deployment

### Environment Setup
Create a `.env` file:
```bash
# For Sepolia
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
PRIVATE_KEY=your_private_key
ETHERSCAN_API_KEY=your_etherscan_key

# For local Anvil (optional)
RPC_URL=http://127.0.0.1:8545
```

### Deploy Commands

```bash
# Local Anvil
make deploy-marketplace-anvil

# Sepolia Testnet (with verification)
make deploy-marketplace-sepolia

# Deploy all contracts
make deploy-all-sepolia
```

## Interactions

### Auction Operations
```bash
# Create auction
make marketplace-create-auction-sepolia

# Place bid
make marketplace-bid-sepolia

# Claim refund (if outbid)
make marketplace-claim-refund-sepolia

# Cancel auction (admin only)
make marketplace-cancel-auction-sepolia

# Perform upkeep (settle ended auctions)
make marketplace-upkeep-sepolia
```

### View/Check Operations
```bash
# Check auction status
make marketplace-check-auction-sepolia

# Check pending refunds
make marketplace-check-refund-sepolia

# Get marketplace info
make marketplace-info-sepolia
```

### Token Operations
```bash
# Mint LINE tokens
make line-mint-sepolia

# Approve tokens for bidding
make marketplace-approve-tokens-sepolia

# Approve NFT for auction
make marketplace-approve-nft-sepolia
```

Run `make help` for all available commands.

## Testing

| Test Type | Command | Description |
|-----------|---------|-------------|
| All | `make test` | Run all tests |
| Unit | `make test-unit` | Unit tests only |
| Integration | `make test-integration` | End-to-end flows |
| Fork | `make test-fork` | Against Sepolia fork |

## Chainlink Automation

The marketplace uses Chainlink Automation for trustless auction settlement:

```bash
# Register upkeep after deployment
make register-upkeep-sepolia
```

Requires LINK tokens in your account for upkeep registration.

## Contract Addresses (Sepolia)

| Contract | Address |
|----------|---------|
| LINE Token | `0xb09CA4C105fBAd8970dbebf36760203a3801387D` |
| NFT | `0xDcDC4A8431391524B993a229482E0C27b68fCE8C` |
| LINK Token | `0x779877A7B0D9E8603169DdbD7836e478b4624789` |

## License

MIT
