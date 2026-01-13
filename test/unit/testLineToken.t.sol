//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {LineToken} from "../../src/LineToken/LineToken.sol";
import {Test} from "forge-std/Test.sol";
import {DeployLineToken} from "../../script/DeployLineToken.s.sol";

contract TestLineToken is Test {
    LineToken lineToken;
    address USER_1 = makeAddr("user1");
    address USER_2 = makeAddr("user2");
    uint256 constant SEND_VALUE = 1 * 1e18;

    function setUp() external {
        DeployLineToken deploy = new DeployLineToken();
        lineToken = deploy.run();
    }

    modifier runByOwner() {
        vm.prank(lineToken.getOwner());
        _;
    }

    modifier mintTokens() {
        vm.prank(lineToken.getOwner());
        lineToken.mint(USER_1, SEND_VALUE);
        _;
    }

    function testOnlyMinterCanMint() external {
        vm.expectRevert();
        lineToken.mint(USER_1, SEND_VALUE);
    }

    function testMintAddsFundsToReciever() external runByOwner {
        lineToken.mint(USER_1, SEND_VALUE);
        assertEq(lineToken.balanceOf(USER_1), SEND_VALUE);
    }

    function testTotalSupplyGetsIncreased() external {
        uint256 totalSupplyBefore = lineToken.totalSupply();
        vm.prank(lineToken.getOwner());
        lineToken.mint(USER_1, SEND_VALUE);
        assertEq(lineToken.totalSupply(), totalSupplyBefore + SEND_VALUE);
    }

    function testTransferMovesFundsBetweenWallets() external mintTokens {
        uint256 balanceOfUser1Before = lineToken.balanceOf(USER_1);
        uint256 balanceOfUser2Before = lineToken.balanceOf(USER_2);
        vm.prank(USER_1);
        lineToken.transfer(USER_2, SEND_VALUE);
        assertEq(
            lineToken.balanceOf(USER_1),
            balanceOfUser1Before - SEND_VALUE
        );
        assertEq(
            lineToken.balanceOf(USER_2),
            balanceOfUser2Before + SEND_VALUE
        );
    }

    function testApproveUpdatesApproval() external mintTokens {
        uint256 allowanceBefore = lineToken.allowance(USER_1, USER_2);
        vm.prank(USER_1);
        lineToken.approve(USER_2, SEND_VALUE);
        assertEq(
            lineToken.allowance(USER_1, USER_2),
            allowanceBefore + SEND_VALUE
        );
    }

    function testSpenderIsAbleToSpendApprovedAmount() external mintTokens {
        uint256 balanceOfUser1Before = lineToken.balanceOf(USER_1);
        uint256 balanceOfUser2Before = lineToken.balanceOf(USER_2);
        vm.prank(USER_1);
        lineToken.approve(USER_2, SEND_VALUE);
        vm.prank(USER_2);
        lineToken.transferFrom(USER_1, USER_2, SEND_VALUE);
        assertEq(
            lineToken.balanceOf(USER_1),
            balanceOfUser1Before - SEND_VALUE
        );
        assertEq(
            lineToken.balanceOf(USER_2),
            balanceOfUser2Before + SEND_VALUE
        );
    }

    function testOnlyApprovedSenderCanCallTransferFrom() external {
        vm.expectRevert();
        lineToken.transferFrom(USER_1, USER_2, SEND_VALUE);
    }

    function testAddAndRemoveMinter() external {
        vm.startPrank(lineToken.getOwner());
        lineToken.addMinter(USER_1);
        assertEq(lineToken.isMinter(USER_1), true);
        lineToken.removeMinter(USER_1);
        assertEq(lineToken.isMinter(USER_1), false);
        vm.stopPrank();
    }
}
