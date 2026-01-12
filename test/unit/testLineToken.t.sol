//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {LineToken} from "../../src/LineToken/LineToken.sol";
import {Test} from "forge-std/Test.sol";
import {DeployLineToken} from "../../script/DeployLineToken.t.sol";

contract TestLineToken is Test {
    LineToken lineToken;
    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 0.1 ether;
    uint256 constant STARTING_BALANCE = 10 ether;

    function setup() external {
        DeployLineToken deploy = new DeployLineToken();
        lineToken = deploy.run();
        vm.deal(USER, STARTING_BALANCE);
    }

    modifier runByOwner() {
        vm.prank(lineToken.getOwner());
        _;
    }

    function testOnlyMinterCanMint() external {
        vm.expectRevert();
        lineToken.mint(USER, SEND_VALUE);
    }
}
