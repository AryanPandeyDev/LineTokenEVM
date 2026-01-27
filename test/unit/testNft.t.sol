//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {DeployNft} from "../../script/DeployNft.s.sol";
import {Nft} from "../../src/nft/Nft.sol";

contract TestNft is Test {
    Nft public nft;
    address public owner;
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    string constant TOKEN_URI = "ipfs://QmTest123";
    string constant TOKEN_URI_2 = "ipfs://QmTest456";

    function setUp() public {
        DeployNft deployer = new DeployNft();
        nft = deployer.deployNft();
        owner = nft.getOwner();
    }

    function test_ConstructorSetsNameAndSymbol() public view {
        assertEq(nft.name(), "Line");
        assertEq(nft.symbol(), "Line");
    }

    function test_MintIncrementsTokenId() public {
        vm.startPrank(owner);
        nft.mint(TOKEN_URI);
        nft.mint(TOKEN_URI_2);
        vm.stopPrank();

        assertEq(nft.ownerOf(0), owner);
        assertEq(nft.ownerOf(1), owner);
    }

    function test_MintSetsTokenURI() public {
        vm.prank(owner);
        nft.mint(TOKEN_URI);

        assertEq(nft.getTokenURI(0), TOKEN_URI);
    }

    function test_MintAssignsOwnership() public {
        vm.prank(owner);
        nft.mint(TOKEN_URI);

        assertEq(nft.ownerOf(0), owner);
        assertEq(nft.balanceOf(owner), 1);
    }

    function test_OwnerCanMintMultipleNfts() public {
        vm.startPrank(owner);
        nft.mint(TOKEN_URI);
        nft.mint(TOKEN_URI_2);
        vm.stopPrank();

        assertEq(nft.balanceOf(owner), 2);
        assertEq(nft.ownerOf(0), owner);
        assertEq(nft.ownerOf(1), owner);
    }

    function test_GetTokenURIReturnsCorrectUri() public {
        vm.startPrank(owner);
        nft.mint(TOKEN_URI);
        nft.mint(TOKEN_URI_2);
        vm.stopPrank();

        assertEq(nft.getTokenURI(0), TOKEN_URI);
        assertEq(nft.getTokenURI(1), TOKEN_URI_2);
    }

    function test_GetTokenURIReturnsEmptyForNonexistentToken() public view {
        assertEq(nft.getTokenURI(999), "");
    }

    function test_TransferNft() public {
        vm.prank(owner);
        nft.mint(TOKEN_URI);

        vm.prank(owner);
        nft.transferFrom(owner, user2, 0);

        assertEq(nft.ownerOf(0), user2);
        assertEq(nft.balanceOf(owner), 0);
        assertEq(nft.balanceOf(user2), 1);
    }

    function test_ApproveAndTransfer() public {
        vm.prank(owner);
        nft.mint(TOKEN_URI);

        vm.prank(owner);
        nft.approve(user2, 0);

        vm.prank(user2);
        nft.transferFrom(owner, user2, 0);

        assertEq(nft.ownerOf(0), user2);
    }

    function test_RevertWhen_NonOwnerTriesToMint() public {
        vm.prank(user1);
        vm.expectRevert(Nft.Nft_OnlyOwnerCanCallMint.selector);
        nft.mint(TOKEN_URI);
    }
}
