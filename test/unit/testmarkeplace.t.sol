//SPDX-License-Identifier:MIT

pragma solidity ^0.8.24;

import {Marketplace} from "../../src/marketplace/Marketplace.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {DeployMarketplace} from "../../script/DeployMarketplace.s.sol";
import {ILineToken} from "../../src/LineToken/LineTokenInterface.sol";
import {INft} from "../../src/nft/INft.sol";

contract TestMarketplace is Test {
    Marketplace marketplace;
    address ADMIN;
    address nftAddress;
    address lineTokenAddress;
    address PLAYER1;
    address PlAYER2;

    event AuctionCreated(uint256 indexed tokenId);

    function setUp() external {
        DeployMarketplace deployer = new DeployMarketplace();
        (marketplace, PLAYER1, PlAYER2, ADMIN) = deployer.deploy();
        nftAddress = marketplace.getNftTokenAddress();
        lineTokenAddress = marketplace.getLineTokenAddress();
    }

    modifier auctionCreated() {
        vm.startPrank(ADMIN);
        INft(nftAddress).approve(address(marketplace), 0);
        marketplace.createAuction(
            0,
            20 ether,
            18000 seconds,
            1 ether,
            300 seconds
        );
        vm.stopPrank();
        _;
    }

    function testGetOwnerReturnsOwner() external view {
        assert(marketplace.getAdmin() == ADMIN);
    }

    function testCreateAuctionCreatesNewAuction() external auctionCreated {
        Marketplace.Auction memory auction = marketplace.getAuction(0);
        assert(auction.auctionState == Marketplace.AuctionState.ACTIVE);
    }

    function testNftGetsTransferedFromOwnerToMarketplaceAfterCreatingAuction()
        external
        auctionCreated
    {
        address actualOwner = INft(nftAddress).ownerOf(0);
        assert(actualOwner == address(marketplace));
    }

    function testCreateAuctionRevertsIfAuctionAlreadyExisitsForToken()
        external
        auctionCreated
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                Marketplace.Marketplace_AuctionAlreadyExistsForTokenId.selector,
                0
            )
        );
        vm.startPrank(ADMIN);
        marketplace.createAuction(
            0,
            20 ether,
            18000 seconds,
            1 ether,
            300 seconds
        );
    }

    function testOnlyTokenOwnerCanCreateAuction() external {
        vm.startPrank(ADMIN);
        INft(nftAddress).transferFrom(ADMIN, PLAYER1, 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                Marketplace.Marketplace_CallerNotOwnerOfTokenId.selector,
                0
            )
        );
        marketplace.createAuction(
            0,
            20 ether,
            18000 seconds,
            1 ether,
            300 seconds
        );
    }

    function testCannotCreateAuctionForNonExisitentTokenId() external {
        vm.startPrank(ADMIN);
        vm.expectRevert(
            abi.encodeWithSelector(
                Marketplace.Marketplace_NonExistentTokenId.selector,
                1
            )
        );
        marketplace.createAuction(
            1,
            20 ether,
            18000 seconds,
            1 ether,
            300 seconds
        );
    }

    function testCannotCreateAuctionForTokenIdIfMarketplaceNotApproved()
        external
    {
        vm.startPrank(ADMIN);
        vm.expectRevert(
            abi.encodeWithSelector(
                Marketplace
                    .Marketplace_MarketplaceNotApprovedForTokenId
                    .selector,
                0
            )
        );
        marketplace.createAuction(
            0,
            20 ether,
            18000 seconds,
            1 ether,
            300 seconds
        );
    }

    function testAuctionGetsCreatedWithCorrectValues() external {
        uint256 startingBid = 20 ether;
        uint256 auctionDuration = 18000 seconds;
        uint256 minimumIncrement = 1 ether;
        uint256 extensionWindow = 300 seconds;

        vm.startPrank(ADMIN);
        INft(nftAddress).approve(address(marketplace), 0);
        uint256 expectedEndTime = block.timestamp + auctionDuration;
        marketplace.createAuction(
            0,
            startingBid,
            auctionDuration,
            minimumIncrement,
            extensionWindow
        );
        vm.stopPrank();

        Marketplace.Auction memory auction = marketplace.getAuction(0);

        assertEq(auction.seller, ADMIN);
        assertEq(auction.highestBidder, address(0));
        assertEq(auction.endTime, expectedEndTime);
        assertEq(auction.highestBid, startingBid);
        assert(auction.auctionState == Marketplace.AuctionState.ACTIVE);
        assertEq(auction.minimumIncrement, minimumIncrement);
        assertEq(auction.extentionWindow, extensionWindow);
    }

    function testCreateAuctionEmitsAuctionCreated() external {
        vm.startPrank(ADMIN);
        INft(nftAddress).approve(address(marketplace), 0);
        vm.expectEmit();
        emit AuctionCreated(0);
        marketplace.createAuction(
            0,
            20 ether,
            18000 seconds,
            1 ether,
            300 seconds
        );
    }

    function testBidRevertsIfAuctionDoesntExistForTokenId() external {
        vm.prank(PLAYER1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Marketplace.Marketplace_AuctionDoesntExistForTokenId.selector,
                0
            )
        );
        marketplace.bid(0, 21 ether);
    }

    function testBidAmountMustExceedPreviousBid() external auctionCreated {
        uint256 currentBid = marketplace.getAuction(0).highestBid;
        vm.prank(PLAYER1);
        vm.expectRevert(
            Marketplace.Marketplace_BidAmountMustExceedPreviousBid.selector
        );
        marketplace.bid(0, currentBid - 1 ether);
    }

    function testInsufficientBalanceForBid() external auctionCreated {
        uint256 currentBid = marketplace.getAuction(0).highestBid;
        vm.prank(address(0));
        vm.expectRevert(
            Marketplace.Maketplace_InsufficientBalanceForBid.selector
        );
        marketplace.bid(0, currentBid + 1 ether);
    }

    function testMarketplaceMustBeAllowedRequiredTokensForBid()
        external
        auctionCreated
    {
        uint256 currentBid = marketplace.getAuction(0).highestBid;
        uint256 newBidAmount = currentBid + 1 ether;
        vm.startPrank(PLAYER1);
        // PLAYER1 has tokens but hasn't approved marketplace
        vm.expectRevert(
            Marketplace.Marketplace_InsufficientApprovalForBid.selector
        );
        marketplace.bid(0, newBidAmount);
        vm.stopPrank();
    }

    function testAntiSnipeMechanismWorksForBidding() external auctionCreated {
        uint256 currentEndTime = marketplace.getAuction(0).endTime;
        uint256 timeToWarp = currentEndTime - 50;
        uint256 extentionWindow = 300 seconds;
        uint256 endtimeExpectedAfterBid = timeToWarp + extentionWindow;
        uint256 currentBid = 20 ether;
        vm.warp(timeToWarp);
        vm.roll(block.number + 1);
        vm.startPrank(PLAYER1);
        ILineToken(lineTokenAddress).approve(
            address(marketplace),
            currentBid + 1 ether
        );
        marketplace.bid(0, currentBid + 1 ether);
        vm.stopPrank();
        assert(marketplace.getAuction(0).endTime == endtimeExpectedAfterBid);
    }

    function testHighestBidAndBidderGetsUpdatedAfterBid()
        external
        auctionCreated
    {
        uint256 currentBid = marketplace.getAuction(0).highestBid;
        uint256 newBidAmount = currentBid + 1 ether;

        vm.startPrank(PLAYER1);
        ILineToken(lineTokenAddress).approve(
            address(marketplace),
            newBidAmount
        );
        marketplace.bid(0, newBidAmount);
        vm.stopPrank();

        Marketplace.Auction memory auction = marketplace.getAuction(0);
        assertEq(auction.highestBid, newBidAmount);
        assertEq(auction.highestBidder, PLAYER1);
    }

    function testLineTokenGetsTransferedFromBidderToMarketplaceAfterBid()
        external
        auctionCreated
    {
        uint256 currentBid = marketplace.getAuction(0).highestBid;
        uint256 newBidAmount = currentBid + 1 ether;

        uint256 player1BalanceBefore = ILineToken(lineTokenAddress).balanceOf(
            PLAYER1
        );
        uint256 marketplaceBalanceBefore = ILineToken(lineTokenAddress)
            .balanceOf(address(marketplace));

        vm.startPrank(PLAYER1);
        ILineToken(lineTokenAddress).approve(
            address(marketplace),
            newBidAmount
        );
        marketplace.bid(0, newBidAmount);
        vm.stopPrank();

        uint256 player1BalanceAfter = ILineToken(lineTokenAddress).balanceOf(
            PLAYER1
        );
        uint256 marketplaceBalanceAfter = ILineToken(lineTokenAddress)
            .balanceOf(address(marketplace));

        assertEq(player1BalanceBefore - player1BalanceAfter, newBidAmount);
        assertEq(
            marketplaceBalanceAfter - marketplaceBalanceBefore,
            newBidAmount
        );
    }

    function testClaimRefundActuallyRefundsTheBidder() external auctionCreated {
        uint256 currentBid = marketplace.getAuction(0).highestBid;
        uint256 newBidAmount = currentBid + 1 ether;

        vm.startPrank(PLAYER1);
        ILineToken(lineTokenAddress).approve(
            address(marketplace),
            newBidAmount
        );
        marketplace.bid(0, newBidAmount);
        vm.stopPrank();

        vm.startPrank(PlAYER2);
        ILineToken(lineTokenAddress).approve(
            address(marketplace),
            newBidAmount + 1 ether
        );
        marketplace.bid(0, newBidAmount + 1 ether);
        vm.stopPrank();

        vm.startPrank(PLAYER1);
        assert(marketplace.checkRefundStatus() == newBidAmount);
        uint256 balanceOfPlayer1BeforeRefund = ILineToken(lineTokenAddress)
            .balanceOf(PLAYER1);
        marketplace.claimRefund();
        uint256 balanceOfPlayer1AfterRefund = ILineToken(lineTokenAddress)
            .balanceOf(PLAYER1);
        assert(
            balanceOfPlayer1AfterRefund ==
                balanceOfPlayer1BeforeRefund + newBidAmount
        );
    }

    function testCancelAuctionActuallyCancelsTheAuction()
        external
        auctionCreated
    {
        vm.prank(ADMIN);
        marketplace.cancelAuction(0);
        Marketplace.Auction memory auction = marketplace.getAuction(0);
        assert(auction.auctionState == Marketplace.AuctionState.CANCELED);
    }

    function testCancelAuctionRefundsHighestBidderAndTransferNftBackToSeller()
        external
        auctionCreated
    {
        uint256 currentBid = marketplace.getAuction(0).highestBid;
        uint256 newBidAmount = currentBid + 1 ether;

        // PLAYER1 places a bid
        vm.startPrank(PLAYER1);
        ILineToken(lineTokenAddress).approve(
            address(marketplace),
            newBidAmount
        );
        marketplace.bid(0, newBidAmount);
        vm.stopPrank();

        uint256 player1BalanceBefore = ILineToken(lineTokenAddress).balanceOf(
            PLAYER1
        );
        address sellerAddress = marketplace.getAuction(0).seller;

        // Admin cancels the auction
        vm.prank(ADMIN);
        marketplace.cancelAuction(0);

        // Check PLAYER1 got refunded
        uint256 player1BalanceAfter = ILineToken(lineTokenAddress).balanceOf(
            PLAYER1
        );
        assertEq(player1BalanceAfter, player1BalanceBefore + newBidAmount);

        // Check NFT returned to seller
        address nftOwner = INft(nftAddress).ownerOf(0);
        assertEq(nftOwner, sellerAddress);
    }

    function testCancelAuctionOnlyByAdmin() external auctionCreated {
        vm.prank(PLAYER1);
        vm.expectRevert(Marketplace.Marketplace_CallerNotAdmin.selector);
        marketplace.cancelAuction(0);
    }

    function testCancelAuctionEmitsAuctionCanceled() external auctionCreated {
        vm.prank(ADMIN);
        vm.expectEmit(true, false, false, false);
        emit Marketplace.AuctionCanceled(0);
        marketplace.cancelAuction(0);
    }

    function testCancelAuctionRevertsForNonExistentAuction() external {
        vm.prank(ADMIN);
        vm.expectRevert(
            abi.encodeWithSelector(
                Marketplace.Marketplace_AuctionDoesntExistForTokenId.selector,
                0
            )
        );
        marketplace.cancelAuction(0);
    }

    function testcheckUpkeepReturnsTrueIfAuctionTimePasses()
        external
        auctionCreated
    {
        Marketplace.Auction memory auction = marketplace.getAuction(0);
        vm.warp(auction.endTime);
        vm.roll(block.number + 1);
        (bool upkeepNeeded, ) = marketplace.checkUpkeep("");
        assert(upkeepNeeded == true);
    }

    function testCheckUpkeepReturnsFalseIfNoAuctionExpired()
        external
        auctionCreated
    {
        (bool upkeepNeeded, ) = marketplace.checkUpkeep("");
        assert(upkeepNeeded == false);
    }

    function testCheckUpkeepReturnsAuctionToBeEndedAsPerformData()
        external
        auctionCreated
    {
        Marketplace.Auction memory auction = marketplace.getAuction(0);
        vm.warp(auction.endTime);
        vm.roll(block.number + 1);
        (, bytes memory performData) = marketplace.checkUpkeep("");
        (uint256[] memory auctionsToEnd, uint256 count) = abi.decode(
            performData,
            (uint256[], uint256)
        );
        assertEq(count, 1);
        assertEq(auctionsToEnd[0], 0);
    }

    function testPerformUpkeepEndsTheAuction() external auctionCreated {
        Marketplace.Auction memory auction = marketplace.getAuction(0);
        vm.warp(auction.endTime);
        vm.roll(block.number + 1);
        (, bytes memory auctionsToEnd) = marketplace.checkUpkeep("");
        marketplace.performUpkeep(auctionsToEnd);
        assert(
            marketplace.getAuction(0).auctionState ==
                Marketplace.AuctionState.ENDED
        );
    }

    function testPerformUpkeepTransfersNftToWinnerAndTokensToSeller()
        external
        auctionCreated
    {
        Marketplace.Auction memory auction = marketplace.getAuction(0);
        uint256 currentBid = auction.highestBid;
        uint256 newBidAmount = currentBid + 1 ether;
        uint256 balanceOfSellerBeforeTransfer = ILineToken(lineTokenAddress)
            .balanceOf(auction.seller);
        vm.startPrank(PLAYER1);
        ILineToken(lineTokenAddress).approve(
            address(marketplace),
            newBidAmount
        );
        marketplace.bid(0, newBidAmount);
        vm.stopPrank();
        vm.warp(auction.endTime);
        vm.roll(block.number + 1);
        (, bytes memory auctionsToEnd) = marketplace.checkUpkeep("");
        marketplace.performUpkeep(auctionsToEnd);
        address newOwnerOfNft = INft(nftAddress).ownerOf(0);
        uint256 balanceOfSellerAfterTransfer = ILineToken(lineTokenAddress)
            .balanceOf(auction.seller);
        assert(newOwnerOfNft == PLAYER1);
        assert(
            balanceOfSellerAfterTransfer ==
                balanceOfSellerBeforeTransfer + newBidAmount
        );
    }

    function testPerformUpkeepReturnsNftToSellerWhenNoBids()
        external
        auctionCreated
    {
        Marketplace.Auction memory auction = marketplace.getAuction(0);
        vm.warp(auction.endTime);
        vm.roll(block.number + 1);
        (, bytes memory auctionsToEnd) = marketplace.checkUpkeep("");
        marketplace.performUpkeep(auctionsToEnd);

        // NFT should return to seller since no bids were placed
        address nftOwner = INft(nftAddress).ownerOf(0);
        assertEq(nftOwner, auction.seller);
    }

    function testPerformUpkeepEmitsAuctionEnded() external auctionCreated {
        Marketplace.Auction memory auction = marketplace.getAuction(0);
        vm.warp(auction.endTime);
        vm.roll(block.number + 1);
        (, bytes memory auctionsToEnd) = marketplace.checkUpkeep("");
        vm.expectEmit(true, false, false, false);
        emit Marketplace.AuctionEnded(0);
        marketplace.performUpkeep(auctionsToEnd);
    }

    function testClaimRefundRevertsWhenNoRefundAvailable() external {
        vm.prank(PLAYER1);
        vm.expectRevert(
            Marketplace.Marketplace_NoRefundBalanceToClaim.selector
        );
        marketplace.claimRefund();
    }

    function testBidEmitsBidPlacedEvent() external auctionCreated {
        uint256 currentBid = marketplace.getAuction(0).highestBid;
        uint256 newBidAmount = currentBid + 1 ether;

        vm.startPrank(PLAYER1);
        ILineToken(lineTokenAddress).approve(
            address(marketplace),
            newBidAmount
        );
        vm.expectEmit(true, true, false, true);
        emit Marketplace.BidPlaced(0, PLAYER1, newBidAmount);
        marketplace.bid(0, newBidAmount);
        vm.stopPrank();
    }

    function testBidRevertsAfterAuctionEnded() external auctionCreated {
        Marketplace.Auction memory auction = marketplace.getAuction(0);
        vm.warp(auction.endTime + 1);
        vm.roll(block.number + 1);

        uint256 currentBid = auction.highestBid;
        uint256 newBidAmount = currentBid + 1 ether;

        vm.startPrank(PLAYER1);
        ILineToken(lineTokenAddress).approve(
            address(marketplace),
            newBidAmount
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                Marketplace.Marketplace_AuctionDoesntExistForTokenId.selector,
                0
            )
        );
        marketplace.bid(0, newBidAmount);
        vm.stopPrank();
    }

    function testBidMustExceedPreviousBidByMinimumIncrement()
        external
        auctionCreated
    {
        uint256 currentBid = marketplace.getAuction(0).highestBid;
        uint256 minimumIncrement = marketplace.getAuction(0).minimumIncrement;
        uint256 invalidBidAmount = currentBid + minimumIncrement - 1; // Less than required

        vm.startPrank(PLAYER1);
        ILineToken(lineTokenAddress).approve(
            address(marketplace),
            invalidBidAmount
        );
        vm.expectRevert(
            Marketplace.Marketplace_BidAmountMustExceedPreviousBid.selector
        );
        marketplace.bid(0, invalidBidAmount);
        vm.stopPrank();
    }

    function testMultipleBiddersRefundTracking() external auctionCreated {
        uint256 currentBid = marketplace.getAuction(0).highestBid;

        // PLAYER1 bids first
        uint256 player1BidAmount = currentBid + 1 ether;
        vm.startPrank(PLAYER1);
        ILineToken(lineTokenAddress).approve(
            address(marketplace),
            player1BidAmount
        );
        marketplace.bid(0, player1BidAmount);
        vm.stopPrank();

        // PLAYER2 outbids PLAYER1
        uint256 player2BidAmount = player1BidAmount + 1 ether;
        vm.startPrank(PlAYER2);
        ILineToken(lineTokenAddress).approve(
            address(marketplace),
            player2BidAmount
        );
        marketplace.bid(0, player2BidAmount);
        vm.stopPrank();

        // PLAYER1 should have a refund available
        vm.prank(PLAYER1);
        assertEq(marketplace.checkRefundStatus(), player1BidAmount);

        // PLAYER2 should not have a refund (they're the current highest bidder)
        vm.prank(PlAYER2);
        assertEq(marketplace.checkRefundStatus(), 0);
    }

    function testCannotBidOnCanceledAuction() external auctionCreated {
        vm.prank(ADMIN);
        marketplace.cancelAuction(0);

        uint256 newBidAmount = 25 ether;
        vm.startPrank(PLAYER1);
        ILineToken(lineTokenAddress).approve(
            address(marketplace),
            newBidAmount
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                Marketplace.Marketplace_AuctionDoesntExistForTokenId.selector,
                0
            )
        );
        marketplace.bid(0, newBidAmount);
        vm.stopPrank();
    }

    function testGetterFunctions() external auctionCreated {
        assertEq(marketplace.getAdmin(), ADMIN);
        assertEq(marketplace.getNftTokenAddress(), nftAddress);
        assertEq(marketplace.getLineTokenAddress(), lineTokenAddress);
    }

    function testConstructorRevertsWithZeroNftAddress() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                Marketplace
                    .Marketplace_InvalidParametersForConstructors
                    .selector,
                address(0),
                lineTokenAddress
            )
        );
        new Marketplace(address(0), lineTokenAddress);
    }

    function testConstructorRevertsWithZeroLineTokenAddress() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                Marketplace
                    .Marketplace_InvalidParametersForConstructors
                    .selector,
                nftAddress,
                address(0)
            )
        );
        new Marketplace(nftAddress, address(0));
    }

    function testAntiSnipeDoesNotExtendWhenOutsideWindow()
        external
        auctionCreated
    {
        // Get the auction details
        Marketplace.Auction memory auction = marketplace.getAuction(0);
        uint256 originalEndTime = auction.endTime;
        uint256 extentionWindow = auction.extentionWindow;

        // Warp to a time outside the extension window (more than 300s before end)
        uint256 timeToWarp = originalEndTime - extentionWindow - 100;
        vm.warp(timeToWarp);
        vm.roll(block.number + 1);

        uint256 currentBid = auction.highestBid;
        vm.startPrank(PLAYER1);
        ILineToken(lineTokenAddress).approve(
            address(marketplace),
            currentBid + 1 ether
        );
        marketplace.bid(0, currentBid + 1 ether);
        vm.stopPrank();

        // End time should NOT be extended
        assertEq(marketplace.getAuction(0).endTime, originalEndTime);
    }

    function testCumulativeRefundsForSameBidder() external auctionCreated {
        uint256 currentBid = marketplace.getAuction(0).highestBid;

        // PLAYER1 bids first
        uint256 player1FirstBid = currentBid + 1 ether;
        vm.startPrank(PLAYER1);
        ILineToken(lineTokenAddress).approve(
            address(marketplace),
            player1FirstBid
        );
        marketplace.bid(0, player1FirstBid);
        vm.stopPrank();

        // PLAYER2 outbids
        uint256 player2Bid = player1FirstBid + 1 ether;
        vm.startPrank(PlAYER2);
        ILineToken(lineTokenAddress).approve(address(marketplace), player2Bid);
        marketplace.bid(0, player2Bid);
        vm.stopPrank();

        // PLAYER1 bids again
        uint256 player1SecondBid = player2Bid + 1 ether;
        vm.startPrank(PLAYER1);
        ILineToken(lineTokenAddress).approve(
            address(marketplace),
            player1SecondBid
        );
        marketplace.bid(0, player1SecondBid);
        vm.stopPrank();

        // PLAYER2 outbids again
        uint256 player2SecondBid = player1SecondBid + 1 ether;
        vm.startPrank(PlAYER2);
        ILineToken(lineTokenAddress).approve(
            address(marketplace),
            player2SecondBid
        );
        marketplace.bid(0, player2SecondBid);
        vm.stopPrank();

        // PLAYER1 should have cumulative refund from both their outbid amounts
        vm.prank(PLAYER1);
        assertEq(
            marketplace.checkRefundStatus(),
            player1FirstBid + player1SecondBid
        );
    }

    function testClaimRefundResetsBalanceToZero() external auctionCreated {
        uint256 currentBid = marketplace.getAuction(0).highestBid;
        uint256 newBidAmount = currentBid + 1 ether;

        // PLAYER1 places bid
        vm.startPrank(PLAYER1);
        ILineToken(lineTokenAddress).approve(
            address(marketplace),
            newBidAmount
        );
        marketplace.bid(0, newBidAmount);
        vm.stopPrank();

        // PLAYER2 outbids PLAYER1
        vm.startPrank(PlAYER2);
        ILineToken(lineTokenAddress).approve(
            address(marketplace),
            newBidAmount + 1 ether
        );
        marketplace.bid(0, newBidAmount + 1 ether);
        vm.stopPrank();

        // PLAYER1 claims refund
        vm.startPrank(PLAYER1);
        marketplace.claimRefund();
        assertEq(marketplace.checkRefundStatus(), 0);
        vm.stopPrank();
    }
}
