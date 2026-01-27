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

contract Marketplace is AutomationCompatibleInterface {
    /*Error*/
    error Marketplace_NonExistentTokenId();
    error Marketplace_CallerNotAdmin();
    error Marketplace_MarketplaceNotApprovedForTokenId(uint256 tokenId);
    error Marketplace_AuctionDoesntExistForTokenId(uint256 tokenId);
    error Maketplace_InsufficientBalanceForBid();
    error MarketPlace_InsufficientApprovalForBid();

    /*Structs*/
    struct Auction {
        address seller;
        address highestBidder;
        uint256 endTime;
        uint256 highestBid;
        bool active;
    }

    /*State*/
    address immutable i_vrfCoordinator;
    address immutable i_nftContractAddress;
    address immutable i_admin;
    address immutable i_lineTokenAddress;
    uint256[] listedNfts;
    mapping(uint256 tokenId => Auction) tokenIdToAuction;

    /*Events*/
    event AuctionCreated(uint256 indexed tokenId);

    /*Constructor*/
    constructor(
        address vrfCoordinator,
        address nftContractAddress,
        address lineTokenAddress
    ) {
        i_vrfCoordinator = vrfCoordinator;
        i_nftContractAddress = nftContractAddress;
        i_lineTokenAddress = lineTokenAddress;
    }

    function getTokenInfo(
        uint256 tokenId
    ) internal view returns (address owner, bool exists) {
        try INft(i_nftContractAddress).ownerOf(tokenId) returns (
            address _owner
        ) {
            return (_owner, true);
        } catch {
            return (address(0), false);
        }
    }

    modifier tokenExists(uint256 tokenId) {
        (, bool validToken) = getTokenInfo(tokenId);
        if (!validToken) {
            revert Marketplace_NonExistentTokenId();
        }
        _;
    }

    function createAuction(
        uint256 tokenId,
        uint256 startingBid,
        uint256 auctionDurationInSeconds
    ) external {
        //checks
        (address _owner, bool validToken) = getTokenInfo(tokenId);
        if (msg.sender != _owner) {
            revert Marketplace_CallerNotAdmin();
        }
        if (!validToken) {
            revert Marketplace_NonExistentTokenId();
        }
        if (INft(i_nftContractAddress).getApproved(tokenId) != address(this)) {
            revert Marketplace_MarketplaceNotApprovedForTokenId(tokenId);
        }

        //effects
        listedNfts.push(tokenId);
        tokenIdToAuction[tokenId] = Auction({
            seller: msg.sender,
            highestBidder: address(this),
            endTime: auctionDurationInSeconds,
            highestBid: startingBid,
            active: true
        });

        //interactions
        INft(i_nftContractAddress).transferFrom(
            msg.sender,
            address(this),
            tokenId
        );

        emit AuctionCreated(tokenId);
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {}

    function performUpkeep(
        bytes calldata /* performData */
    ) external override {}
}
