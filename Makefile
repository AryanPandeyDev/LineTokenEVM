-include .env

.PHONY: all build test clean

# Default network settings (uses .env variables)
NETWORK_ARGS := --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY) --broadcast

# For local anvil testing
ANVIL_ARGS := --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast

# For Sepolia testnet (set SEPOLIA_RPC_URL and PRIVATE_KEY in .env)
SEPOLIA_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY)

###############################
#         BUILD & TEST        #
###############################

build:
	@forge build

test:
	@forge test

test-v:
	@forge test -vvv

test-integration:
	@forge test --match-contract IntegrationsTestMarketplace -vvv

test-unit:
	@forge test --match-path "test/unit/*" -vvv

# Fork tests (against Sepolia)
test-fork:
	@forge test --fork-url $(SEPOLIA_RPC_URL) -vvv

test-fork-integration:
	@forge test --match-contract IntegrationsTestMarketplace --fork-url $(SEPOLIA_RPC_URL) -vvv

test-fork-unit:
	@forge test --match-path "test/unit/*" --fork-url $(SEPOLIA_RPC_URL) -vvv

clean:
	@forge clean

###############################
#         DEPLOYMENTS         #
###############################

# Deploy LINE Token
deploy-line-token:
	@forge script script/DeployLineToken.s.sol:DeployLineToken $(NETWORK_ARGS)

deploy-line-token-anvil:
	@forge script script/DeployLineToken.s.sol:DeployLineToken $(ANVIL_ARGS)

# Deploy NFT
deploy-nft:
	@forge script script/DeployNft.s.sol:DeployNft $(NETWORK_ARGS)

deploy-nft-anvil:
	@forge script script/DeployNft.s.sol:DeployNft $(ANVIL_ARGS)

# Deploy Marketplace (includes NFT and LINE token on Anvil)
deploy-marketplace:
	@forge script script/DeployMarketplace.s.sol:DeployMarketplace $(NETWORK_ARGS)

deploy-marketplace-anvil:
	@forge script script/DeployMarketplace.s.sol:DeployMarketplace $(ANVIL_ARGS)

# Deploy all (for testnets)
deploy-all: deploy-line-token deploy-nft deploy-marketplace

###############################
#     SEPOLIA DEPLOYMENTS     #
###############################

deploy-line-token-sepolia:
	@forge script script/DeployLineToken.s.sol:DeployLineToken $(SEPOLIA_ARGS)

deploy-nft-sepolia:
	@forge script script/DeployNft.s.sol:DeployNft $(SEPOLIA_ARGS)

deploy-marketplace-sepolia:
	@forge script script/DeployMarketplace.s.sol:DeployMarketplace $(SEPOLIA_ARGS)

deploy-all-sepolia: deploy-line-token-sepolia deploy-nft-sepolia deploy-marketplace-sepolia

###############################
#    LINE TOKEN INTERACTIONS  #
###############################

# Mint LINE tokens
line-mint:
	@forge script script/Interactions.s.sol:MintLineToken $(NETWORK_ARGS)

line-mint-anvil:
	@forge script script/Interactions.s.sol:MintLineToken $(ANVIL_ARGS)

line-mint-sepolia:
	@forge script script/Interactions.s.sol:MintLineToken $(SEPOLIA_ARGS)

# Transfer LINE tokens
line-transfer:
	@forge script script/Interactions.s.sol:TransferLineToken $(NETWORK_ARGS)

line-transfer-anvil:
	@forge script script/Interactions.s.sol:TransferLineToken $(ANVIL_ARGS)

line-transfer-sepolia:
	@forge script script/Interactions.s.sol:TransferLineToken $(SEPOLIA_ARGS)

# Approve LINE tokens
line-approve:
	@forge script script/Interactions.s.sol:ApproveLineToken $(NETWORK_ARGS)

line-approve-anvil:
	@forge script script/Interactions.s.sol:ApproveLineToken $(ANVIL_ARGS)

line-approve-sepolia:
	@forge script script/Interactions.s.sol:ApproveLineToken $(SEPOLIA_ARGS)

###############################
#  MARKETPLACE INTERACTIONS   #
###############################

# Create auction
marketplace-create-auction:
	@forge script script/MarketplaceInteractions.s.sol:CreateAuction $(NETWORK_ARGS)

marketplace-create-auction-anvil:
	@forge script script/MarketplaceInteractions.s.sol:CreateAuction $(ANVIL_ARGS)

marketplace-create-auction-sepolia:
	@forge script script/MarketplaceInteractions.s.sol:CreateAuction $(SEPOLIA_ARGS)

# Place bid
marketplace-bid:
	@forge script script/MarketplaceInteractions.s.sol:PlaceBid $(NETWORK_ARGS)

marketplace-bid-anvil:
	@forge script script/MarketplaceInteractions.s.sol:PlaceBid $(ANVIL_ARGS)

marketplace-bid-sepolia:
	@forge script script/MarketplaceInteractions.s.sol:PlaceBid $(SEPOLIA_ARGS)

# Claim refund
marketplace-claim-refund:
	@forge script script/MarketplaceInteractions.s.sol:ClaimRefund $(NETWORK_ARGS)

marketplace-claim-refund-anvil:
	@forge script script/MarketplaceInteractions.s.sol:ClaimRefund $(ANVIL_ARGS)

marketplace-claim-refund-sepolia:
	@forge script script/MarketplaceInteractions.s.sol:ClaimRefund $(SEPOLIA_ARGS)

# Cancel auction
marketplace-cancel-auction:
	@forge script script/MarketplaceInteractions.s.sol:CancelAuction $(NETWORK_ARGS)

marketplace-cancel-auction-anvil:
	@forge script script/MarketplaceInteractions.s.sol:CancelAuction $(ANVIL_ARGS)

marketplace-cancel-auction-sepolia:
	@forge script script/MarketplaceInteractions.s.sol:CancelAuction $(SEPOLIA_ARGS)

# Perform upkeep
marketplace-upkeep:
	@forge script script/MarketplaceInteractions.s.sol:PerformUpkeep $(NETWORK_ARGS)

marketplace-upkeep-anvil:
	@forge script script/MarketplaceInteractions.s.sol:PerformUpkeep $(ANVIL_ARGS)

marketplace-upkeep-sepolia:
	@forge script script/MarketplaceInteractions.s.sol:PerformUpkeep $(SEPOLIA_ARGS)

# Check auction status (view only, no broadcast)
marketplace-check-auction:
	@forge script script/MarketplaceInteractions.s.sol:CheckAuctionStatus --rpc-url $(RPC_URL)

marketplace-check-auction-anvil:
	@forge script script/MarketplaceInteractions.s.sol:CheckAuctionStatus --rpc-url http://127.0.0.1:8545

marketplace-check-auction-sepolia:
	@forge script script/MarketplaceInteractions.s.sol:CheckAuctionStatus --rpc-url $(SEPOLIA_RPC_URL)

# Check refund status
marketplace-check-refund:
	@forge script script/MarketplaceInteractions.s.sol:CheckRefundStatus $(NETWORK_ARGS)

marketplace-check-refund-anvil:
	@forge script script/MarketplaceInteractions.s.sol:CheckRefundStatus $(ANVIL_ARGS)

marketplace-check-refund-sepolia:
	@forge script script/MarketplaceInteractions.s.sol:CheckRefundStatus $(SEPOLIA_ARGS)

# Check upkeep needed (view only, no broadcast)
marketplace-check-upkeep:
	@forge script script/MarketplaceInteractions.s.sol:CheckUpkeepNeeded --rpc-url $(RPC_URL)

marketplace-check-upkeep-anvil:
	@forge script script/MarketplaceInteractions.s.sol:CheckUpkeepNeeded --rpc-url http://127.0.0.1:8545

marketplace-check-upkeep-sepolia:
	@forge script script/MarketplaceInteractions.s.sol:CheckUpkeepNeeded --rpc-url $(SEPOLIA_RPC_URL)

# Get marketplace info (view only, no broadcast)
marketplace-info:
	@forge script script/MarketplaceInteractions.s.sol:GetMarketplaceInfo --rpc-url $(RPC_URL)

marketplace-info-anvil:
	@forge script script/MarketplaceInteractions.s.sol:GetMarketplaceInfo --rpc-url http://127.0.0.1:8545

marketplace-info-sepolia:
	@forge script script/MarketplaceInteractions.s.sol:GetMarketplaceInfo --rpc-url $(SEPOLIA_RPC_URL)

# Approve marketplace for NFT
marketplace-approve-nft:
	@forge script script/MarketplaceInteractions.s.sol:ApproveMarketplaceForNft $(NETWORK_ARGS)

marketplace-approve-nft-anvil:
	@forge script script/MarketplaceInteractions.s.sol:ApproveMarketplaceForNft $(ANVIL_ARGS)

marketplace-approve-nft-sepolia:
	@forge script script/MarketplaceInteractions.s.sol:ApproveMarketplaceForNft $(SEPOLIA_ARGS)

# Approve marketplace for tokens
marketplace-approve-tokens:
	@forge script script/MarketplaceInteractions.s.sol:ApproveMarketplaceForTokens $(NETWORK_ARGS)

marketplace-approve-tokens-anvil:
	@forge script script/MarketplaceInteractions.s.sol:ApproveMarketplaceForTokens $(ANVIL_ARGS)

marketplace-approve-tokens-sepolia:
	@forge script script/MarketplaceInteractions.s.sol:ApproveMarketplaceForTokens $(SEPOLIA_ARGS)

# Full auction flow demo
marketplace-full-flow:
	@forge script script/MarketplaceInteractions.s.sol:FullAuctionFlow $(NETWORK_ARGS)

marketplace-full-flow-anvil:
	@forge script script/MarketplaceInteractions.s.sol:FullAuctionFlow $(ANVIL_ARGS)

marketplace-full-flow-sepolia:
	@forge script script/MarketplaceInteractions.s.sol:FullAuctionFlow $(SEPOLIA_ARGS)

###############################
#    CHAINLINK AUTOMATION     #
###############################

# Register upkeep with Chainlink
register-upkeep:
	@forge script script/Interactions.s.sol:RegisterUpkeep $(NETWORK_ARGS)

register-upkeep-sepolia:
	@forge script script/Interactions.s.sol:RegisterUpkeep $(SEPOLIA_ARGS)

###############################
#         HELP                #
###############################

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Suffixes: -anvil (local), -sepolia (testnet), or none (uses RPC_URL from .env)"
	@echo ""
	@echo "Environment Variables (.env):"
	@echo "  RPC_URL, PRIVATE_KEY              - Default network"
	@echo "  SEPOLIA_RPC_URL, ETHERSCAN_API_KEY - Sepolia testnet"
	@echo ""
	@echo "Deployments"
	@echo "==========="
	@echo "  deploy-line-token[-anvil|-sepolia]     - Deploy LINE token"
	@echo "  deploy-nft[-anvil|-sepolia]            - Deploy NFT contract"
	@echo "  deploy-marketplace[-anvil|-sepolia]    - Deploy Marketplace"
	@echo "  deploy-all[-sepolia]                   - Deploy all contracts"
	@echo ""
	@echo "LINE Token Interactions"
	@echo "======================="
	@echo "  line-mint[-anvil|-sepolia]         - Mint LINE tokens"
	@echo "  line-transfer[-anvil|-sepolia]     - Transfer LINE tokens"
	@echo "  line-approve[-anvil|-sepolia]      - Approve token spending"
	@echo ""
	@echo "Marketplace Interactions"
	@echo "========================"
	@echo "  marketplace-create-auction[-anvil|-sepolia]  - Create auction"
	@echo "  marketplace-bid[-anvil|-sepolia]             - Place bid"
	@echo "  marketplace-claim-refund[-anvil|-sepolia]    - Claim refund"
	@echo "  marketplace-cancel-auction[-anvil|-sepolia]  - Cancel auction"
	@echo "  marketplace-upkeep[-anvil|-sepolia]          - Perform upkeep"
	@echo "  marketplace-check-auction[-anvil|-sepolia]   - Check auction status"
	@echo "  marketplace-check-refund[-anvil|-sepolia]    - Check refund status"
	@echo "  marketplace-check-upkeep[-anvil|-sepolia]    - Check if upkeep needed"
	@echo "  marketplace-info[-anvil|-sepolia]            - Get marketplace info"
	@echo "  marketplace-approve-nft[-anvil|-sepolia]     - Approve NFT"
	@echo "  marketplace-approve-tokens[-anvil|-sepolia]  - Approve tokens"
	@echo "  marketplace-full-flow[-anvil|-sepolia]       - Full auction demo"
	@echo ""
	@echo "Chainlink Automation"
	@echo "===================="
	@echo "  register-upkeep[-sepolia]          - Register upkeep"
	@echo ""
	@echo "Testing"
	@echo "======="
	@echo "  test                               - Run all tests"
	@echo "  test-v                             - Run tests with verbosity"
	@echo "  test-integration                   - Run integration tests"
	@echo "  test-unit                          - Run unit tests"
	@echo ""
	@echo "Fork Tests (against Sepolia)"
	@echo "============================"
	@echo "  test-fork                          - Run all tests on Sepolia fork"
	@echo "  test-fork-integration              - Integration tests on fork"
	@echo "  test-fork-unit                     - Unit tests on fork"