//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {Marketplace} from "src/marketplace/Marketplace.sol";
import {ILineToken} from "src/LineToken/LineTokenInterface.sol";
import {INft} from "src/nft/INft.sol";

/**
 * @title MarketplaceConstants
 * @notice Shared constants for marketplace interactions and tests
 */
abstract contract MarketplaceConstants {
    uint256 public constant DEFAULT_STARTING_BID = 20 ether;
    uint256 public constant DEFAULT_AUCTION_DURATION = 18000; // 5 hours
    uint256 public constant DEFAULT_MINIMUM_INCREMENT = 1 ether;
    uint256 public constant DEFAULT_EXTENSION_WINDOW = 300; // 5 minutes
}

/**
 * @title CreateAuction
 * @notice Script to create a new auction for an NFT
 * @dev Admin must own the NFT and approve the marketplace before creating auction
 */
contract CreateAuction is Script, MarketplaceConstants {
    function createAuction(
        address marketplaceAddress,
        uint256 tokenId,
        uint256 startingBid,
        uint256 auctionDuration,
        uint256 minimumIncrement,
        uint256 extensionWindow,
        address account
    ) public {
        Marketplace marketplace = Marketplace(marketplaceAddress);
        address nftAddress = marketplace.getNftTokenAddress();

        vm.startBroadcast(account);
        // Approve marketplace to transfer the NFT
        INft(nftAddress).approve(marketplaceAddress, tokenId);
        // Create the auction
        marketplace.createAuction(
            tokenId,
            startingBid,
            auctionDuration,
            minimumIncrement,
            extensionWindow
        );
        vm.stopBroadcast();

        console.log("---------------------------------------------");
        console.log("Auction created successfully!");
        console.log("Token ID:", tokenId);
        console.log("Starting Bid:", startingBid);
        console.log("Auction Duration (seconds):", auctionDuration);
        console.log("Minimum Increment:", minimumIncrement);
        console.log("Extension Window (seconds):", extensionWindow);
        console.log("---------------------------------------------");
    }

    function createAuctionWithDefaults(
        address marketplaceAddress,
        uint256 tokenId,
        address account
    ) public {
        createAuction(
            marketplaceAddress,
            tokenId,
            DEFAULT_STARTING_BID,
            DEFAULT_AUCTION_DURATION,
            DEFAULT_MINIMUM_INCREMENT,
            DEFAULT_EXTENSION_WINDOW,
            account
        );
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Marketplace",
            block.chainid
        );
        // Default: create auction for token ID 0
        createAuctionWithDefaults(mostRecentlyDeployed, 0, msg.sender);
    }
}

/**
 * @title PlaceBid
 * @notice Script to place a bid on an active auction
 * @dev Bidder must have sufficient LINE tokens and approve marketplace
 */
contract PlaceBid is Script {
    function placeBid(
        address marketplaceAddress,
        uint256 tokenId,
        uint256 bidAmount,
        address account
    ) public {
        Marketplace marketplace = Marketplace(marketplaceAddress);
        address lineTokenAddress = marketplace.getLineTokenAddress();

        vm.startBroadcast(account);
        // Approve marketplace to transfer LINE tokens
        ILineToken(lineTokenAddress).approve(marketplaceAddress, bidAmount);
        // Place the bid
        marketplace.bid(tokenId, bidAmount);
        vm.stopBroadcast();

        console.log("---------------------------------------------");
        console.log("Bid placed successfully!");
        console.log("Token ID:", tokenId);
        console.log("Bid Amount:", bidAmount);
        console.log("---------------------------------------------");
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Marketplace",
            block.chainid
        );
        // Default: bid 21 ether on token ID 0
        placeBid(mostRecentlyDeployed, 0, 21 ether, msg.sender);
    }
}

/**
 * @title ClaimRefund
 * @notice Script to claim refund for outbid users
 */
contract ClaimRefund is Script {
    function claimRefund(address marketplaceAddress, address account) public {
        Marketplace marketplace = Marketplace(marketplaceAddress);

        vm.startBroadcast(account);
        uint256 refundAmount = marketplace.checkRefundStatus();
        require(refundAmount > 0, "No refund available");
        marketplace.claimRefund();
        vm.stopBroadcast();

        console.log("---------------------------------------------");
        console.log("Refund claimed successfully!");
        console.log("Refund Amount:", refundAmount);
        console.log("---------------------------------------------");
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Marketplace",
            block.chainid
        );
        claimRefund(mostRecentlyDeployed, msg.sender);
    }
}

/**
 * @title CancelAuction
 * @notice Script to cancel an active auction (Admin only)
 */
contract CancelAuction is Script {
    function cancelAuction(
        address marketplaceAddress,
        uint256 tokenId,
        address account
    ) public {
        Marketplace marketplace = Marketplace(marketplaceAddress);

        vm.startBroadcast(account);
        marketplace.cancelAuction(tokenId);
        vm.stopBroadcast();

        console.log("---------------------------------------------");
        console.log("Auction canceled successfully!");
        console.log("Token ID:", tokenId);
        console.log("---------------------------------------------");
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Marketplace",
            block.chainid
        );
        // Default: cancel auction for token ID 0
        cancelAuction(mostRecentlyDeployed, 0, msg.sender);
    }
}

/**
 * @title PerformUpkeep
 * @notice Script to manually trigger upkeep for ended auctions
 * @dev Useful for testing or when Chainlink Automation is not set up
 */
contract PerformUpkeep is Script {
    function performUpkeep(address marketplaceAddress, address account) public {
        Marketplace marketplace = Marketplace(marketplaceAddress);

        (bool upkeepNeeded, bytes memory performData) = marketplace.checkUpkeep(
            ""
        );

        if (!upkeepNeeded) {
            console.log("---------------------------------------------");
            console.log("No upkeep needed at this time");
            console.log("---------------------------------------------");
            return;
        }

        vm.startBroadcast(account);
        marketplace.performUpkeep(performData);
        vm.stopBroadcast();

        console.log("---------------------------------------------");
        console.log("Upkeep performed successfully!");
        console.log("---------------------------------------------");
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Marketplace",
            block.chainid
        );
        performUpkeep(mostRecentlyDeployed, msg.sender);
    }
}

/**
 * @title CheckAuctionStatus
 * @notice Script to check the status of an auction
 */
contract CheckAuctionStatus is Script {
    function checkAuctionStatus(
        address marketplaceAddress,
        uint256 tokenId
    ) public view {
        Marketplace marketplace = Marketplace(marketplaceAddress);
        Marketplace.Auction memory auction = marketplace.getAuction(tokenId);

        string memory stateString;
        if (auction.auctionState == Marketplace.AuctionState.NOT_STARTED) {
            stateString = "NOT_STARTED";
        } else if (auction.auctionState == Marketplace.AuctionState.ACTIVE) {
            stateString = "ACTIVE";
        } else if (auction.auctionState == Marketplace.AuctionState.ENDED) {
            stateString = "ENDED";
        } else {
            stateString = "CANCELED";
        }

        console.log("---------------------------------------------");
        console.log("Auction Status for Token ID:", tokenId);
        console.log("---------------------------------------------");
        console.log("Seller:", auction.seller);
        console.log("Highest Bidder:", auction.highestBidder);
        console.log("Highest Bid:", auction.highestBid);
        console.log("End Time:", auction.endTime);
        console.log("Auction State:", stateString);
        console.log("Minimum Increment:", auction.minimumIncrement);
        console.log("Extension Window:", auction.extentionWindow);
        console.log("---------------------------------------------");
    }

    function run() external view {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Marketplace",
            block.chainid
        );
        checkAuctionStatus(mostRecentlyDeployed, 0);
    }
}

/**
 * @title CheckRefundStatus
 * @notice Script to check refund status for a user
 */
contract CheckRefundStatus is Script {
    function checkRefundStatus(address marketplaceAddress) public {
        Marketplace marketplace = Marketplace(marketplaceAddress);

        vm.startBroadcast();
        uint256 refundAmount = marketplace.checkRefundStatus();
        vm.stopBroadcast();

        console.log("---------------------------------------------");
        console.log("Refund Status");
        console.log("---------------------------------------------");
        console.log("Refund Amount Available:", refundAmount);
        console.log("---------------------------------------------");
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Marketplace",
            block.chainid
        );
        checkRefundStatus(mostRecentlyDeployed);
    }
}

/**
 * @title ApproveMarketplaceForNft
 * @notice Script to approve marketplace to transfer an NFT
 */
contract ApproveMarketplaceForNft is Script {
    function approveMarketplaceForNft(
        address marketplaceAddress,
        uint256 tokenId,
        address account
    ) public {
        Marketplace marketplace = Marketplace(marketplaceAddress);
        address nftAddress = marketplace.getNftTokenAddress();

        vm.startBroadcast(account);
        INft(nftAddress).approve(marketplaceAddress, tokenId);
        vm.stopBroadcast();

        console.log("---------------------------------------------");
        console.log("Marketplace approved for NFT transfer");
        console.log("Token ID:", tokenId);
        console.log("---------------------------------------------");
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Marketplace",
            block.chainid
        );
        approveMarketplaceForNft(mostRecentlyDeployed, 0, msg.sender);
    }
}

/**
 * @title ApproveMarketplaceForTokens
 * @notice Script to approve marketplace to transfer LINE tokens for bidding
 */
contract ApproveMarketplaceForTokens is Script {
    function approveMarketplaceForTokens(
        address marketplaceAddress,
        uint256 amount,
        address account
    ) public {
        Marketplace marketplace = Marketplace(marketplaceAddress);
        address lineTokenAddress = marketplace.getLineTokenAddress();

        vm.startBroadcast(account);
        ILineToken(lineTokenAddress).approve(marketplaceAddress, amount);
        vm.stopBroadcast();

        console.log("---------------------------------------------");
        console.log("Marketplace approved for LINE token transfer");
        console.log("Amount:", amount);
        console.log("---------------------------------------------");
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Marketplace",
            block.chainid
        );
        // Default: approve 100 ether worth of LINE tokens
        approveMarketplaceForTokens(
            mostRecentlyDeployed,
            100 ether,
            msg.sender
        );
    }
}

/**
 * @title CheckUpkeepNeeded
 * @notice Script to check if any auctions need upkeep (have ended)
 */
contract CheckUpkeepNeeded is Script {
    function checkUpkeepNeeded(address marketplaceAddress) public view {
        Marketplace marketplace = Marketplace(marketplaceAddress);

        (bool upkeepNeeded, bytes memory performData) = marketplace.checkUpkeep(
            ""
        );

        console.log("---------------------------------------------");
        console.log("Upkeep Check");
        console.log("---------------------------------------------");
        console.log("Upkeep Needed:", upkeepNeeded);

        if (upkeepNeeded) {
            (uint256[] memory auctionsToEnd, uint256 count) = abi.decode(
                performData,
                (uint256[], uint256)
            );
            console.log("Number of auctions to end:", count);
            for (uint256 i = 0; i < count; i++) {
                console.log("  - Token ID:", auctionsToEnd[i]);
            }
        }
        console.log("---------------------------------------------");
    }

    function run() external view {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Marketplace",
            block.chainid
        );
        checkUpkeepNeeded(mostRecentlyDeployed);
    }
}

/**
 * @title GetMarketplaceInfo
 * @notice Script to get marketplace contract information
 */
contract GetMarketplaceInfo is Script {
    function getMarketplaceInfo(address marketplaceAddress) public view {
        Marketplace marketplace = Marketplace(marketplaceAddress);

        address admin = marketplace.getAdmin();
        address nftAddress = marketplace.getNftTokenAddress();
        address lineTokenAddress = marketplace.getLineTokenAddress();

        console.log("---------------------------------------------");
        console.log("Marketplace Information");
        console.log("---------------------------------------------");
        console.log("Marketplace Address:", marketplaceAddress);
        console.log("Admin Address:", admin);
        console.log("NFT Contract Address:", nftAddress);
        console.log("LINE Token Address:", lineTokenAddress);
        console.log("---------------------------------------------");
    }

    function run() external view {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Marketplace",
            block.chainid
        );
        getMarketplaceInfo(mostRecentlyDeployed);
    }
}

/**
 * @title FullAuctionFlow
 * @notice Script to demonstrate a complete auction flow (for testing)
 * @dev Creates auction, places bid, and checks status
 */
contract FullAuctionFlow is Script, MarketplaceConstants {
    function runFullFlow(
        address marketplaceAddress,
        uint256 tokenId,
        uint256 bidAmount
    ) public {
        Marketplace marketplace = Marketplace(marketplaceAddress);
        address nftAddress = marketplace.getNftTokenAddress();
        address lineTokenAddress = marketplace.getLineTokenAddress();

        console.log("==============================================");
        console.log("Starting Full Auction Flow");
        console.log("==============================================");

        // Step 1: Approve and create auction
        console.log("\nStep 1: Creating Auction...");
        vm.startBroadcast();
        INft(nftAddress).approve(marketplaceAddress, tokenId);
        marketplace.createAuction(
            tokenId,
            DEFAULT_STARTING_BID,
            DEFAULT_AUCTION_DURATION,
            DEFAULT_MINIMUM_INCREMENT,
            DEFAULT_EXTENSION_WINDOW
        );
        vm.stopBroadcast();
        console.log("Auction created for Token ID:", tokenId);

        // Step 2: Check auction status
        console.log("\nStep 2: Checking Auction Status...");
        Marketplace.Auction memory auction = marketplace.getAuction(tokenId);
        console.log("Highest Bid:", auction.highestBid);
        console.log("End Time:", auction.endTime);

        // Step 3: Place a bid (if bidAmount provided)
        if (bidAmount > 0) {
            console.log("\nStep 3: Placing Bid...");
            vm.startBroadcast();
            ILineToken(lineTokenAddress).approve(marketplaceAddress, bidAmount);
            marketplace.bid(tokenId, bidAmount);
            vm.stopBroadcast();
            console.log("Bid placed:", bidAmount);

            // Check updated status
            auction = marketplace.getAuction(tokenId);
            console.log("New Highest Bid:", auction.highestBid);
            console.log("Highest Bidder:", auction.highestBidder);
        }

        console.log("\n==============================================");
        console.log("Full Auction Flow Completed!");
        console.log("==============================================");
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Marketplace",
            block.chainid
        );
        // Default: create auction for token 0 and bid 21 ether
        runFullFlow(mostRecentlyDeployed, 0, 21 ether);
    }
}
