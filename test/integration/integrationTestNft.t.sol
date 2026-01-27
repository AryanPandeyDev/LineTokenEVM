//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Nft} from "../../src/nft/Nft.sol";
import {DeployNft} from "../../script/DeployNft.s.sol";

contract IntegrationTestNft is Test {
    Nft public nft;
    address public owner;

    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");

    string constant TOKEN_URI_1 = "ipfs://QmIntegration1";
    string constant TOKEN_URI_2 = "ipfs://QmIntegration2";
    string constant TOKEN_URI_3 = "ipfs://QmIntegration3";

    function setUp() public {
        DeployNft deployer = new DeployNft();
        nft = deployer.deployNft();
        owner = nft.getOwner();
    }

    function test_DeploymentSetsCorrectNameAndSymbol() public view {
        assertEq(nft.name(), "Line");
        assertEq(nft.symbol(), "Line");
    }

    function test_FullMintAndTransferFlow() public {
        // Owner mints an NFT
        vm.prank(owner);
        nft.mint(TOKEN_URI_1);

        assertEq(nft.ownerOf(0), owner);
        assertEq(nft.getTokenURI(0), TOKEN_URI_1);
        assertEq(nft.balanceOf(owner), 1);

        // Owner transfers to User1
        vm.prank(owner);
        nft.transferFrom(owner, user1, 0);

        assertEq(nft.ownerOf(0), user1);
        assertEq(nft.balanceOf(owner), 0);
        assertEq(nft.balanceOf(user1), 1);

        // User1 transfers to User2
        vm.prank(user1);
        nft.transferFrom(user1, user2, 0);

        assertEq(nft.ownerOf(0), user2);
        assertEq(nft.balanceOf(user1), 0);
        assertEq(nft.balanceOf(user2), 1);

        // Token URI remains the same after transfers
        assertEq(nft.getTokenURI(0), TOKEN_URI_1);
    }

    function test_OwnerMintingMultipleNfts() public {
        vm.startPrank(owner);
        nft.mint(TOKEN_URI_1);
        nft.mint(TOKEN_URI_2);
        nft.mint(TOKEN_URI_3);
        vm.stopPrank();

        // Verify ownership - all belong to owner
        assertEq(nft.ownerOf(0), owner);
        assertEq(nft.ownerOf(1), owner);
        assertEq(nft.ownerOf(2), owner);

        // Verify URIs
        assertEq(nft.getTokenURI(0), TOKEN_URI_1);
        assertEq(nft.getTokenURI(1), TOKEN_URI_2);
        assertEq(nft.getTokenURI(2), TOKEN_URI_3);

        // Verify balance
        assertEq(nft.balanceOf(owner), 3);
    }

    function test_ApprovalAndDelegatedTransferFlow() public {
        // Owner mints
        vm.prank(owner);
        nft.mint(TOKEN_URI_1);

        // Owner approves user1 to transfer token 0
        vm.prank(owner);
        nft.approve(user1, 0);

        assertEq(nft.getApproved(0), user1);

        // User1 transfers on behalf of owner to user2
        vm.prank(user1);
        nft.transferFrom(owner, user2, 0);

        assertEq(nft.ownerOf(0), user2);
        assertEq(nft.getApproved(0), address(0)); // Approval cleared after transfer
    }

    function test_SetApprovalForAllFlow() public {
        // Owner mints multiple NFTs
        vm.startPrank(owner);
        nft.mint(TOKEN_URI_1);
        nft.mint(TOKEN_URI_2);
        nft.mint(TOKEN_URI_3);
        vm.stopPrank();

        assertEq(nft.balanceOf(owner), 3);

        // Owner gives user1 approval for all
        vm.prank(owner);
        nft.setApprovalForAll(user1, true);

        assertTrue(nft.isApprovedForAll(owner, user1));

        // User1 can transfer any of owner's NFTs
        vm.startPrank(user1);
        nft.transferFrom(owner, user2, 0);
        nft.transferFrom(owner, user2, 1);
        nft.transferFrom(owner, user2, 2);
        vm.stopPrank();

        assertEq(nft.balanceOf(owner), 0);
        assertEq(nft.balanceOf(user2), 3);
    }

    function test_SafeTransferToEOA() public {
        vm.prank(owner);
        nft.mint(TOKEN_URI_1);

        vm.prank(owner);
        nft.safeTransferFrom(owner, user1, 0);

        assertEq(nft.ownerOf(0), user1);
    }

    function test_RevertWhen_TransferWithoutApproval() public {
        vm.prank(owner);
        nft.mint(TOKEN_URI_1);

        // User1 tries to transfer without approval - should fail
        vm.prank(user1);
        vm.expectRevert();
        nft.transferFrom(owner, user2, 0);
    }

    function test_RevertWhen_TransferNonexistentToken() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.transferFrom(user1, user2, 999);
    }

    function test_RevokeApprovalForAll() public {
        vm.prank(owner);
        nft.mint(TOKEN_URI_1);

        // Grant approval
        vm.prank(owner);
        nft.setApprovalForAll(user1, true);
        assertTrue(nft.isApprovedForAll(owner, user1));

        // Revoke approval
        vm.prank(owner);
        nft.setApprovalForAll(user1, false);
        assertFalse(nft.isApprovedForAll(owner, user1));
    }

    function test_RevertWhen_NonOwnerTriesToMint() public {
        vm.prank(user1);
        vm.expectRevert(Nft.Nft_OnlyOwnerCanCallMint.selector);
        nft.mint(TOKEN_URI_1);

        vm.prank(user2);
        vm.expectRevert(Nft.Nft_OnlyOwnerCanCallMint.selector);
        nft.mint(TOKEN_URI_2);
    }
}
