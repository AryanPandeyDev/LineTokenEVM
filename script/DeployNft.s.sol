//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {Nft} from "../src/nft/Nft.sol";

contract DeployNft is Script {
    function run() external {
        deployNft();
    }

    function deployNft() public returns (Nft) {
        vm.startBroadcast();
        Nft nft = new Nft("Line", "Line");
        vm.stopBroadcast();
        return nft;
    }
}
