//SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.24;

import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {INft} from "../nft/INft.sol";
import {ILineToken} from "../LineToken/LineTokenInterface.sol";

/**
 * @title Marketplace
 * @author Aryan Pandey
 * @notice A decentralized NFT auction marketplace with automated settlement
 * @dev Implements Chainlink Automation for trustless auction finalization.
 *      Uses LINE token for bidding and supports time-based auctions with
 *      minimum bid increments. NFTs are held in escrow during active auctions.
 */
contract Marketplace is AutomationCompatibleInterface {
    ///////////////////
    // Errors
    ///////////////////
    /// @notice Thrown when a provided tokenId does not exist or is invalid.
    error Marketplace_NonExistentTokenId();
    /// @notice Thrown when a function restricted to the admin is called by a non-admin address.
    error Marketplace_CallerNotAdmin();
    /// @notice Thrown when the caller is not the owner of the specified NFT.
    /// @param tokenId The ID of the NFT in question.
    error Marketplace_CallerNotOwnerOfTokenId(uint256 tokenId);
    /// @notice Thrown when the marketplace contract is not approved to manage the specified NFT.
    /// @param tokenId The ID of the NFT that needs approval.
    error Marketplace_MarketplaceNotApprovedForTokenId(uint256 tokenId);
    /// @notice Thrown when an operation is attempted on an auction that does not exist or is not active.
    /// @param tokenId The ID of the NFT whose auction is being referenced.
    error Marketplace_AuctionDoesntExistForTokenId(uint256 tokenId);
    /// @notice Thrown when a bidder does not have sufficient LINE token balance to place a bid.
    error Maketplace_InsufficientBalanceForBid();
    /// @notice Thrown when the marketplace contract does not have sufficient allowance to transfer LINE tokens from the bidder.
    error Marketplace_InsufficientApprovalForBid();
    /// @notice Thrown when a new bid amount is not greater than the current highest bid plus the minimum increment.
    error Marketplace_BidAmountMustExceedPreviousBid();
    /// @notice Thrown when a user attempts to claim a refund but has no pending refund amount.
    error Marketplace_NoRefundBalanceToClaim();

    ///////////////////
    // Type Declarations
    ///////////////////

    /// @notice Represents the lifecycle states of an auction
    enum AuctionState {
        NOT_STARTED,
        ACTIVE,
        ENDED,
        CANCELED
    }

    /// @notice Stores all data associated with a single auction
    /// @param seller The address that created the auction and owns the NFT
    /// @param highestBidder The current leading bidder's address
    /// @param endTime Unix timestamp when the auction expires
    /// @param highestBid The current highest bid amount in LINE tokens
    /// @param auctionState Current state of the auction
    /// @param minimumIncrement Minimum amount a new bid must exceed the current highest bid
    struct Auction {
        address seller;
        address highestBidder;
        uint256 endTime;
        uint256 highestBid;
        AuctionState auctionState;
        uint256 minimumIncrement;
    }

    ///////////////////
    // State Variables
    ///////////////////

    /// @dev Address of the NFT contract this marketplace supports
    address private immutable i_nftContractAddress;

    /// @dev Address of the admin who can create and cancel auctions
    address private immutable i_admin;

    /// @dev Address of the LINE token used for bidding
    address private immutable i_lineTokenAddress;

    /// @dev Array of all currently listed token IDs
    uint256[] private s_activeAuctionTokens;

    /// @dev Maps token ID to its index in the listedTokens array for O(1) removal
    mapping(uint256 tokenId => uint256 index) private s_tokenIdToIndex;

    /// @dev Maps token ID to its auction data
    mapping(uint256 tokenId => Auction) private s_tokenIdToAuction;

    /// @dev Tracks pending refunds for outbid bidders
    mapping(address => uint256 refundAmount) private s_bidderToRefundAmount;

    ///////////////////
    // Events
    ///////////////////

    /// @notice Emitted when a new auction is created
    /// @param tokenId The ID of the NFT being auctioned
    event AuctionCreated(uint256 indexed tokenId);

    /// @notice Emitted when a bid is successfully placed
    /// @param tokenId The ID of the NFT being bid on
    /// @param bidder The address of the bidder
    /// @param amount The bid amount in LINE tokens
    event BidPlaced(
        uint256 indexed tokenId,
        address indexed bidder,
        uint256 amount
    );

    /// @notice Emitted when an auction is canceled by the admin
    /// @param tokenId The ID of the NFT whose auction was canceled
    event AuctionCanceled(uint256 indexed tokenId);

    /// @notice Emitted when an auction ends (via Chainlink Automation)
    /// @param tokenId The ID of the NFT whose auction ended
    event AuctionEnded(uint256 indexed tokenId);

    ///////////////////
    // Modifiers
    ///////////////////

    /// @notice Ensures the token exists in the NFT contract
    /// @param tokenId The ID of the token to check
    modifier tokenExists(uint256 tokenId) {
        (, bool validToken) = getTokenInfo(tokenId);
        if (!validToken) {
            revert Marketplace_NonExistentTokenId();
        }
        _;
    }

    /// @notice Restricts function access to the admin only
    modifier onlyAdmin() {
        if (msg.sender != i_admin) {
            revert Marketplace_CallerNotAdmin();
        }
        _;
    }

    /// @notice Ensures an active auction exists for the given token
    /// @param tokenId The ID of the token to check
    modifier auctionExists(uint256 tokenId) {
        if (s_tokenIdToAuction[tokenId].auctionState != AuctionState.ACTIVE) {
            revert Marketplace_AuctionDoesntExistForTokenId(tokenId);
        }
        _;
    }

    ///////////////////
    // Constructor
    ///////////////////

    /**
     * @notice Initializes the marketplace with required contract addresses
     * @param nftContractAddress The address of the NFT contract
     * @param lineTokenAddress The address of the LINE token contract
     */
    constructor(address nftContractAddress, address lineTokenAddress) {
        if (nftContractAddress == address(0)) {}
        i_nftContractAddress = nftContractAddress;
        i_lineTokenAddress = lineTokenAddress;
        i_admin = msg.sender;
    }

    ///////////////////
    // External Functions
    ///////////////////

    /**
     * @notice Creates a new auction for an NFT
     * @dev The NFT must be owned by the admin and approved for this contract.
     *      Transfers the NFT to escrow upon successful creation.
     * @param tokenId The ID of the NFT to auction
     * @param startingBid The minimum starting bid in LINE tokens
     * @param auctionDurationInSeconds Duration of the auction in seconds
     * @param minimumIncrementForBid Minimum amount each new bid must exceed the previous
     */
    function createAuction(
        uint256 tokenId,
        uint256 startingBid,
        uint256 auctionDurationInSeconds,
        uint256 minimumIncrementForBid
    ) external onlyAdmin {
        (address _owner, bool validToken) = getTokenInfo(tokenId);
        if (msg.sender != _owner) {
            revert Marketplace_CallerNotOwnerOfTokenId(tokenId);
        }
        if (!validToken) {
            revert Marketplace_NonExistentTokenId();
        }
        if (INft(i_nftContractAddress).getApproved(tokenId) != address(this)) {
            revert Marketplace_MarketplaceNotApprovedForTokenId(tokenId);
        }
        s_tokenIdToIndex[tokenId] = s_activeAuctionTokens.length;
        s_activeAuctionTokens.push(tokenId);
        s_tokenIdToAuction[tokenId] = Auction({
            seller: msg.sender,
            highestBidder: address(0),
            endTime: block.timestamp + auctionDurationInSeconds,
            highestBid: startingBid,
            auctionState: AuctionState.ACTIVE,
            minimumIncrement: minimumIncrementForBid
        });
        emit AuctionCreated(tokenId);
        INft(i_nftContractAddress).transferFrom(
            msg.sender,
            address(this),
            tokenId
        );
    }

    /**
     * @notice Places a bid on an active auction
     * @dev Caller must have sufficient LINE balance and approval for this contract.
     *      Previous highest bidder's tokens are marked for refund.
     * @param tokenId The ID of the NFT to bid on
     * @param amount The bid amount in LINE tokens (must exceed current highest + minimum increment)
     */
    function bid(
        uint256 tokenId,
        uint256 amount
    ) external auctionExists(tokenId) {
        Auction storage auction = s_tokenIdToAuction[tokenId];
        if (block.timestamp > auction.endTime) {
            revert Marketplace_AuctionDoesntExistForTokenId(tokenId);
        }
        if (amount < auction.highestBid + auction.minimumIncrement) {
            revert Marketplace_BidAmountMustExceedPreviousBid();
        }
        if (ILineToken(i_lineTokenAddress).balanceOf(msg.sender) < amount) {
            revert Maketplace_InsufficientBalanceForBid();
        }
        if (
            ILineToken(i_lineTokenAddress).allowance(
                msg.sender,
                address(this)
            ) < amount
        ) {
            revert Marketplace_InsufficientApprovalForBid();
        }
        if (auction.highestBidder != address(0)) {
            s_bidderToRefundAmount[auction.highestBidder] += auction.highestBid;
        }
        auction.highestBidder = msg.sender;
        auction.highestBid = amount;
        emit BidPlaced(tokenId, msg.sender, amount);
        ILineToken(i_lineTokenAddress).transferFrom(
            msg.sender,
            address(this),
            amount
        );
    }

    /**
     * @notice Allows outbid bidders to claim their refunded LINE tokens
     * @dev Uses the pull-payment pattern for security. Resets refund balance before transfer.
     */
    function claimRefund() external {
        uint256 refundAmount = s_bidderToRefundAmount[msg.sender];
        if (refundAmount == 0) {
            revert Marketplace_NoRefundBalanceToClaim();
        }
        s_bidderToRefundAmount[msg.sender] = 0;
        ILineToken(i_lineTokenAddress).transfer(msg.sender, refundAmount);
    }

    /**
     * @notice Cancels an active auction and refunds all parties
     * @dev Admin-only function. Returns NFT to seller and refunds highest bidder if any.
     * @param tokenId The ID of the NFT whose auction should be canceled
     */
    function cancelAuction(
        uint256 tokenId
    ) external onlyAdmin auctionExists(tokenId) {
        Auction storage auction = s_tokenIdToAuction[tokenId];
        auction.auctionState = AuctionState.CANCELED;
        removeToken(s_activeAuctionTokens, tokenId);
        if (auction.highestBidder != address(0)) {
            ILineToken(i_lineTokenAddress).transfer(
                auction.highestBidder,
                auction.highestBid
            );
        }
        INft(i_nftContractAddress).transferFrom(
            address(this),
            auction.seller,
            tokenId
        );
        emit AuctionCanceled(tokenId);
    }

    /**
     * @notice Chainlink Automation check function to identify expired auctions
     * @dev Called by Chainlink nodes to determine if performUpkeep should be executed.
     *      Iterates through all active auctions to find those past their end time.
     * @return upkeepNeeded True if at least one auction has expired
     * @return performData Encoded array of expired auction token IDs and count
     */
    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        uint256[] memory auctionsToEnd = new uint256[](
            s_activeAuctionTokens.length
        );
        uint256 count = 0;
        uint256 lastIndex = s_activeAuctionTokens.length;
        for (uint256 token = 0; token < lastIndex; token++) {
            if (
                block.timestamp >=
                s_tokenIdToAuction[s_activeAuctionTokens[token]].endTime
            ) {
                auctionsToEnd[count] = s_activeAuctionTokens[token];
                count++;
            }
        }
        return (count > 0, abi.encode(auctionsToEnd, count));
    }

    /**
     * @notice Chainlink Automation execution function to finalize expired auctions
     * @dev Processes all expired auctions: transfers NFT to winner and payment to seller,
     *      or returns NFT to seller if no bids were placed.
     * @param performData Encoded array of auction token IDs to finalize (from checkUpkeep)
     */
    function performUpkeep(bytes calldata performData) external override {
        (uint256[] memory auctionsToEnd, uint256 count) = abi.decode(
            performData,
            (uint256[], uint256)
        );
        for (uint256 tokenIndex = 0; tokenIndex < count; tokenIndex++) {
            Auction storage auction = s_tokenIdToAuction[
                auctionsToEnd[tokenIndex]
            ];
            if (block.timestamp >= auction.endTime) {
                auction.auctionState = AuctionState.ENDED;
                removeToken(s_activeAuctionTokens, auctionsToEnd[tokenIndex]);
                if (auction.highestBidder != address(0)) {
                    INft(i_nftContractAddress).safeTransferFrom(
                        address(this),
                        auction.highestBidder,
                        auctionsToEnd[tokenIndex]
                    );
                    ILineToken(i_lineTokenAddress).transfer(
                        auction.seller,
                        auction.highestBid
                    );
                } else {
                    INft(i_nftContractAddress).safeTransferFrom(
                        address(this),
                        auction.seller,
                        auctionsToEnd[tokenIndex]
                    );
                }
                emit AuctionEnded(auctionsToEnd[tokenIndex]);
            }
        }
    }

    ///////////////////
    // Private Functions
    ///////////////////

    /**
     * @notice Retrieves ownership information for a token
     * @dev Uses try-catch to safely handle non-existent tokens
     * @param tokenId The ID of the token to query
     * @return owner The address of the token owner (address(0) if non-existent)
     * @return exists True if the token exists, false otherwise
     */
    function getTokenInfo(
        uint256 tokenId
    ) private view returns (address owner, bool exists) {
        try INft(i_nftContractAddress).ownerOf(tokenId) returns (
            address _owner
        ) {
            return (_owner, true);
        } catch {
            return (address(0), false);
        }
    }

    /**
     * @notice Removes a token from the listed tokens array efficiently
     * @dev Uses swap-and-pop pattern for O(1) removal. Updates index mapping accordingly.
     * @param _listedToken Storage reference to the listed tokens array
     * @param tokenId The ID of the token to remove
     */
    function removeToken(
        uint256[] storage _listedToken,
        uint256 tokenId
    ) private {
        uint256 lastIndex = _listedToken.length - 1;
        uint256 tokenIndex = s_tokenIdToIndex[tokenId];
        if (tokenIndex != lastIndex) {
            s_tokenIdToIndex[_listedToken[lastIndex]] = tokenIndex;
            _listedToken[tokenIndex] = _listedToken[lastIndex];
        }
        _listedToken.pop();
    }

    function getAdmin() external view returns (address) {
        return i_admin;
    }

    function getLineTokenAddress() external view returns (address) {
        return i_lineTokenAddress;
    }

    function getNftTokenAddress() external view returns (address) {
        return i_nftContractAddress;
    }

    function getAuction(
        uint256 tokenId
    ) external view returns (Auction memory) {
        return s_tokenIdToAuction[tokenId];
    }

    function checkRefundStatus() external view returns (uint256) {
        return s_bidderToRefundAmount[msg.sender];
    }
}
