//SPDX-License-Identifier:MIT

pragma solidity ^0.8.24;

import {Script} from "../lib/forge-std/src/Script.sol";
import {Marketplace} from "../src/marketplace/Marketplace.sol";
import {HelperConfig, CodeConstants} from "./helperConfig.s.sol";
import {RegisterUpkeep} from "./Interactions.s.sol";
import {LineToken} from "../src/LineToken/LineToken.sol";
import {Nft} from "../src/nft/Nft.sol";

contract DeployMarketplace is Script, CodeConstants {
    function run() external {
        deploy();
    }

    function deploy() public returns (Marketplace, address, address, address) {
        HelperConfig helperConfig = new HelperConfig();
        RegisterUpkeep registrar = new RegisterUpkeep();
        HelperConfig.MarketplaceConfig memory config = helperConfig.getConfig();
        address PLAYER1 = makeAddr("player1");
        address PLAYER2 = makeAddr("player2");
        if (block.chainid != MAINET_ETH_CHAIN_ID) {
            vm.startPrank(config.account);
            if (config.lineTokenAddress == address(0)) {
                LineToken line = new LineToken();
                config.lineTokenAddress = address(line);
            }
            if (config.nftContractAddress == address(0)) {
                Nft nft = new Nft("LineNfts", "LINE");
                config.nftContractAddress = address(nft);
            }
            LineToken(config.lineTokenAddress).mint(config.account, 1000 ether);
            LineToken(config.lineTokenAddress).mint(PLAYER1, 1000 ether);
            LineToken(config.lineTokenAddress).mint(PLAYER2, 1000 ether);
            Nft(config.nftContractAddress).mint("testNft");
            vm.stopPrank();
        }
        vm.startBroadcast(config.account);
        Marketplace marketplace = new Marketplace(
            config.nftContractAddress,
            config.lineTokenAddress
        );
        vm.stopBroadcast();
        if (block.chainid != ANVIL_CHAIN_ID) {
            registrar.registerUpkeep(
                address(marketplace),
                config.registrarAddress,
                config.linkTokenAddress,
                config.account
            );
        }
        return (marketplace, PLAYER1, PLAYER2, config.account);
    }
}
