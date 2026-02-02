//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Marketplace} from "../../src/marketplace/Marketplace.sol";
import {DeployMarketplace} from "../../script/DeployMarketplace.s.sol";
import {ILineToken} from "../../src/LineToken/LineTokenInterface.sol";
import {INft} from "../../src/nft/INft.sol";

// Import interaction scripts
import {
    MarketplaceConstants,
    CreateAuction,
    PlaceBid,
    ClaimRefund,
    CancelAuction,
    PerformUpkeep,
    ApproveMarketplaceForNft,
    ApproveMarketplaceForTokens
} from "../../script/MarketplaceInteractions.s.sol";

/**
 * @title IntegrationsTestMarketplace
 * @notice Integration tests that verify all marketplace interaction scripts work together
 * @dev Uses actual script contracts to test end-to-end flows
 */
contract IntegrationsTestMarketplace is Test, MarketplaceConstants {
    // Core contracts
    Marketplace marketplace;
    address nftAddress;
    address lineTokenAddress;

    // Actors
    address ADMIN;
    address PLAYER1;
    address PLAYER2;

    // Script instances
    CreateAuction createAuctionScript;
    PlaceBid placeBidScript;
    ClaimRefund claimRefundScript;
    CancelAuction cancelAuctionScript;
    PerformUpkeep performUpkeepScript;
    ApproveMarketplaceForNft approveNftScript;
    ApproveMarketplaceForTokens approveTokensScript;

    function setUp() public {
        // Deploy marketplace and dependencies
        DeployMarketplace deployer = new DeployMarketplace();
        (marketplace, PLAYER1, PLAYER2, ADMIN) = deployer.deploy();
        nftAddress = marketplace.getNftTokenAddress();
        lineTokenAddress = marketplace.getLineTokenAddress();

        // Deploy script instances
        createAuctionScript = new CreateAuction();
        placeBidScript = new PlaceBid();
        claimRefundScript = new ClaimRefund();
        cancelAuctionScript = new CancelAuction();
        performUpkeepScript = new PerformUpkeep();
        approveNftScript = new ApproveMarketplaceForNft();
        approveTokensScript = new ApproveMarketplaceForTokens();
    }

    /*//////////////////////////////////////////////////////////////
                    FULL AUCTION FLOW TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Tests complete auction flow: create → bid → upkeep → settlement
     * @dev Verifies NFT transfers to winner and tokens transfer to seller
     */
    function test_FullAuctionFlowWithWinner() public {
        uint256 tokenId = 0;
        uint256 bidAmount = DEFAULT_STARTING_BID + DEFAULT_MINIMUM_INCREMENT;

        // Step 1: Admin creates auction using script
        createAuctionScript.createAuctionWithDefaults(
            address(marketplace),
            tokenId,
            ADMIN
        );

        // Verify auction created
        Marketplace.Auction memory auction = marketplace.getAuction(tokenId);
        assert(auction.auctionState == Marketplace.AuctionState.ACTIVE);
        assertEq(INft(nftAddress).ownerOf(tokenId), address(marketplace));

        // Step 2: Player1 places bid using script
        placeBidScript.placeBid(
            address(marketplace),
            tokenId,
            bidAmount,
            PLAYER1
        );

        // Verify bid placed
        auction = marketplace.getAuction(tokenId);
        assertEq(auction.highestBidder, PLAYER1);
        assertEq(auction.highestBid, bidAmount);

        // Step 3: Time passes, auction ends
        vm.warp(auction.endTime + 1);
        vm.roll(block.number + 1);

        // Step 4: Perform upkeep using script
        uint256 sellerBalanceBefore = ILineToken(lineTokenAddress).balanceOf(
            ADMIN
        );
        performUpkeepScript.performUpkeep(address(marketplace), address(this));

        // Verify auction ended correctly
        auction = marketplace.getAuction(tokenId);
        assert(auction.auctionState == Marketplace.AuctionState.ENDED);

        // Verify NFT transferred to winner
        assertEq(INft(nftAddress).ownerOf(tokenId), PLAYER1);

        // Verify tokens transferred to seller
        uint256 sellerBalanceAfter = ILineToken(lineTokenAddress).balanceOf(
            ADMIN
        );
        assertEq(sellerBalanceAfter - sellerBalanceBefore, bidAmount);

        console.log("Full auction flow with winner completed successfully!");
    }

    /**
     * @notice Tests auction with no bids - NFT returns to seller
     */
    function test_FullAuctionFlowWithNoBids() public {
        uint256 tokenId = 0;

        // Admin creates auction
        createAuctionScript.createAuctionWithDefaults(
            address(marketplace),
            tokenId,
            ADMIN
        );

        // Time passes, auction ends
        Marketplace.Auction memory auction = marketplace.getAuction(tokenId);
        vm.warp(auction.endTime + 1);
        vm.roll(block.number + 1);

        // Perform upkeep
        performUpkeepScript.performUpkeep(address(marketplace), address(this));

        // Verify NFT returned to seller
        assertEq(INft(nftAddress).ownerOf(tokenId), ADMIN);

        // Verify auction ended
        auction = marketplace.getAuction(tokenId);
        assert(auction.auctionState == Marketplace.AuctionState.ENDED);

        console.log("Auction with no bids - NFT returned to seller!");
    }

    /*//////////////////////////////////////////////////////////////
                    MULTI-BIDDER COMPETITION TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Tests multiple bidders competing with refund claims
     */
    function test_MultipleBiddersWithRefundClaims() public {
        uint256 tokenId = 0;
        uint256 player1Bid = DEFAULT_STARTING_BID + DEFAULT_MINIMUM_INCREMENT;
        uint256 player2Bid = player1Bid + DEFAULT_MINIMUM_INCREMENT;

        // Create auction
        createAuctionScript.createAuctionWithDefaults(
            address(marketplace),
            tokenId,
            ADMIN
        );

        // Player1 bids first
        placeBidScript.placeBid(
            address(marketplace),
            tokenId,
            player1Bid,
            PLAYER1
        );

        uint256 player1BalanceAfterBid = ILineToken(lineTokenAddress).balanceOf(
            PLAYER1
        );

        // Player2 outbids Player1
        placeBidScript.placeBid(
            address(marketplace),
            tokenId,
            player2Bid,
            PLAYER2
        );

        // Verify Player1 has pending refund
        vm.prank(PLAYER1);
        uint256 refundAmount = marketplace.checkRefundStatus();
        assertEq(refundAmount, player1Bid);

        // Player1 claims refund using script
        claimRefundScript.claimRefund(address(marketplace), PLAYER1);

        // Verify refund received
        uint256 player1BalanceAfterRefund = ILineToken(lineTokenAddress)
            .balanceOf(PLAYER1);
        assertEq(
            player1BalanceAfterRefund - player1BalanceAfterBid,
            player1Bid
        );

        // Verify no more refund available
        vm.prank(PLAYER1);
        assertEq(marketplace.checkRefundStatus(), 0);

        console.log("Multi-bidder competition with refund claims completed!");
    }

    /*//////////////////////////////////////////////////////////////
                    AUCTION CANCELLATION TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Tests auction cancellation flow - refunds bidder and returns NFT
     */
    function test_AuctionCancellationFlow() public {
        uint256 tokenId = 0;
        uint256 bidAmount = DEFAULT_STARTING_BID + DEFAULT_MINIMUM_INCREMENT;

        // Create auction
        createAuctionScript.createAuctionWithDefaults(
            address(marketplace),
            tokenId,
            ADMIN
        );

        // Player1 places bid
        placeBidScript.placeBid(
            address(marketplace),
            tokenId,
            bidAmount,
            PLAYER1
        );

        uint256 player1BalanceBefore = ILineToken(lineTokenAddress).balanceOf(
            PLAYER1
        );

        // Admin cancels auction using script
        cancelAuctionScript.cancelAuction(address(marketplace), tokenId, ADMIN);

        // Verify auction canceled
        Marketplace.Auction memory auction = marketplace.getAuction(tokenId);
        assert(auction.auctionState == Marketplace.AuctionState.CANCELED);

        // Verify NFT returned to seller
        assertEq(INft(nftAddress).ownerOf(tokenId), ADMIN);

        // Verify bidder got refunded (direct refund on cancel)
        uint256 player1BalanceAfter = ILineToken(lineTokenAddress).balanceOf(
            PLAYER1
        );
        assertEq(player1BalanceAfter - player1BalanceBefore, bidAmount);

        console.log("Auction cancellation flow completed successfully!");
    }

    /*//////////////////////////////////////////////////////////////
                    ANTI-SNIPE MECHANISM TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Tests anti-snipe: bid in final minutes extends auction
     */
    function test_AntiSnipeMechanismExtension() public {
        uint256 tokenId = 0;
        uint256 bidAmount = DEFAULT_STARTING_BID + DEFAULT_MINIMUM_INCREMENT;

        // Create auction
        createAuctionScript.createAuctionWithDefaults(
            address(marketplace),
            tokenId,
            ADMIN
        );

        Marketplace.Auction memory auction = marketplace.getAuction(tokenId);
        uint256 originalEndTime = auction.endTime;

        // Warp to within extension window (50 seconds before end)
        vm.warp(originalEndTime - 50);
        vm.roll(block.number + 1);

        // Player1 places bid
        placeBidScript.placeBid(
            address(marketplace),
            tokenId,
            bidAmount,
            PLAYER1
        );

        // Verify end time was extended
        auction = marketplace.getAuction(tokenId);
        uint256 expectedNewEndTime = block.timestamp + DEFAULT_EXTENSION_WINDOW;
        assertEq(auction.endTime, expectedNewEndTime);
        assertTrue(auction.endTime > originalEndTime);

        console.log("Anti-snipe mechanism working - auction extended!");
    }

    /**
     * @notice Tests that bids outside extension window don't extend auction
     */
    function test_NoExtensionOutsideWindow() public {
        uint256 tokenId = 0;
        uint256 bidAmount = DEFAULT_STARTING_BID + DEFAULT_MINIMUM_INCREMENT;

        // Create auction
        createAuctionScript.createAuctionWithDefaults(
            address(marketplace),
            tokenId,
            ADMIN
        );

        Marketplace.Auction memory auction = marketplace.getAuction(tokenId);
        uint256 originalEndTime = auction.endTime;

        // Warp to outside extension window (500 seconds before end)
        vm.warp(originalEndTime - 500);
        vm.roll(block.number + 1);

        // Player1 places bid
        placeBidScript.placeBid(
            address(marketplace),
            tokenId,
            bidAmount,
            PLAYER1
        );

        // Verify end time was NOT extended
        auction = marketplace.getAuction(tokenId);
        assertEq(auction.endTime, originalEndTime);

        console.log("No extension outside window - correct behavior!");
    }

    /*//////////////////////////////////////////////////////////////
                    APPROVAL SCRIPTS TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Tests NFT approval script works correctly
     */
    function test_ApproveMarketplaceForNftScript() public {
        // First, mint a new NFT to ADMIN (token 0 is used by deploy)
        vm.prank(ADMIN);
        INft(nftAddress).mint("test-uri");
        uint256 tokenId = 1; // New token

        // Verify marketplace not approved initially
        assertEq(INft(nftAddress).getApproved(tokenId), address(0));

        // Use approval script
        approveNftScript.approveMarketplaceForNft(
            address(marketplace),
            tokenId,
            ADMIN
        );

        // Verify approval granted
        assertEq(INft(nftAddress).getApproved(tokenId), address(marketplace));

        console.log("NFT approval script works correctly!");
    }

    /**
     * @notice Tests token approval script works correctly
     */
    function test_ApproveMarketplaceForTokensScript() public {
        uint256 approvalAmount = 100 ether;

        // Verify no allowance initially
        uint256 allowanceBefore = ILineToken(lineTokenAddress).allowance(
            PLAYER1,
            address(marketplace)
        );
        assertEq(allowanceBefore, 0);

        // Use approval script
        approveTokensScript.approveMarketplaceForTokens(
            address(marketplace),
            approvalAmount,
            PLAYER1
        );

        // Verify approval granted
        uint256 allowanceAfter = ILineToken(lineTokenAddress).allowance(
            PLAYER1,
            address(marketplace)
        );
        assertEq(allowanceAfter, approvalAmount);

        console.log("Token approval script works correctly!");
    }

    /*//////////////////////////////////////////////////////////////
                    CHAINLINK AUTOMATION TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Tests checkUpkeep returns correct data for expired auctions
     */
    function test_CheckUpkeepReturnsExpiredAuctions() public {
        uint256 tokenId = 0;

        // Create auction
        createAuctionScript.createAuctionWithDefaults(
            address(marketplace),
            tokenId,
            ADMIN
        );

        // Verify no upkeep needed initially
        (bool upkeepNeeded, ) = marketplace.checkUpkeep("");
        assertFalse(upkeepNeeded);

        // Time passes
        Marketplace.Auction memory auction = marketplace.getAuction(tokenId);
        vm.warp(auction.endTime + 1);
        vm.roll(block.number + 1);

        // Verify upkeep now needed
        bytes memory performData;
        (upkeepNeeded, performData) = marketplace.checkUpkeep("");
        assertTrue(upkeepNeeded);

        // Verify perform data contains correct auction
        (uint256[] memory auctionsToEnd, uint256 count) = abi.decode(
            performData,
            (uint256[], uint256)
        );
        assertEq(count, 1);
        assertEq(auctionsToEnd[0], tokenId);

        console.log("checkUpkeep correctly identifies expired auctions!");
    }
}
