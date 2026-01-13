//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {LineToken} from "../src/LineToken/LineToken.sol";
import {Script} from "forge-std/Script.sol";

contract DeployLineToken is Script {
    function run() external returns (LineToken) {
        vm.startBroadcast();
        LineToken lineToken = new LineToken();
        vm.stopBroadcast();
        return lineToken;
    }
}
