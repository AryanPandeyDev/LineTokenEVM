// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {LineToken} from "../../src/LineToken/LineToken.sol";
import {Test} from "forge-std/Test.sol";
import "../../script/Interactions.s.sol";
import {DeployLineToken} from "../../script/DeployLineToken.s.sol";

contract TestLineTokenIntegration is Test {
    LineToken lineToken;
    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 1 * 1e18;

    function setUp() external {
        DeployLineToken deploy = new DeployLineToken();
        lineToken = deploy.run();
    }

    modifier mintTokens(address to) {
        MintLineToken mintLineTokens = new MintLineToken();
        mintLineTokens.mintLineToken(address(lineToken), to, SEND_VALUE);
        _;
    }

    function testTransferMovesFundsBetweenWallets()
        external
        mintTokens(msg.sender)
    {
        TransferLineToken transferLineToken = new TransferLineToken();
        uint256 balanceOfUser1Before = lineToken.balanceOf(msg.sender);
        uint256 balanceOfUser2Before = lineToken.balanceOf(USER);
        transferLineToken.transferLineToken(
            address(lineToken),
            USER,
            SEND_VALUE
        );
        assertEq(
            lineToken.balanceOf(msg.sender),
            balanceOfUser1Before - SEND_VALUE
        );
        assertEq(lineToken.balanceOf(USER), balanceOfUser2Before + SEND_VALUE);
    }

    function testTransferFromDoesTransferFunds()
        external
        mintTokens(msg.sender)
    {
        uint256 balanceOfUser1Before = lineToken.balanceOf(msg.sender);
        uint256 balanceOfUser2Before = lineToken.balanceOf(USER);

        ApproveLineToken approveLineToken = new ApproveLineToken();
        approveLineToken.approveSpender(address(lineToken), USER, SEND_VALUE);

        vm.prank(USER);
        lineToken.transferFrom(msg.sender, USER, SEND_VALUE);
        assertEq(
            lineToken.balanceOf(msg.sender),
            balanceOfUser1Before - SEND_VALUE
        );
        assertEq(lineToken.balanceOf(USER), balanceOfUser2Before + SEND_VALUE);
    }
}
