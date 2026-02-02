//SPDX-License-Identifier:MIT

pragma solidity ^0.8.24;

import {Script} from "../lib/forge-std/src/Script.sol";

contract CodeConstants {
    uint256 constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant ANVIL_CHAIN_ID = 31337;
    uint256 constant MAINET_ETH_CHAIN_ID = 1;
}

contract HelperConfig is Script, CodeConstants {
    struct MarketplaceConfig {
        address lineTokenAddress;
        address nftContractAddress;
        address linkTokenAddress;
        address registrarAddress;
        address account;
    }

    mapping(uint256 chainId => MarketplaceConfig) private chainIdToConfig;

    function getConfig() external view returns (MarketplaceConfig memory) {
        if (block.chainid == SEPOLIA_CHAIN_ID) {
            return getConfigForSepolia();
        } else {
            return getConfigForAnvil();
        }
    }

    function getConfigForSepolia()
        internal
        pure
        returns (MarketplaceConfig memory)
    {
        return
            MarketplaceConfig({
                lineTokenAddress: 0xb09CA4C105fBAd8970dbebf36760203a3801387D, //update after deploying
                nftContractAddress: 0xDcDC4A8431391524B993a229482E0C27b68fCE8C,
                linkTokenAddress: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                registrarAddress: 0xb0E49c5D0d05cbc241d68c05BC5BA1d1B7B72976,
                account: 0x302215abf60746F5c71fD8563c1AC40A314B5d23
            });
    }

    function getConfigForAnvil()
        internal
        pure
        returns (MarketplaceConfig memory)
    {
        return
            MarketplaceConfig({
                lineTokenAddress: address(0),
                nftContractAddress: address(0),
                linkTokenAddress: address(0),
                registrarAddress: address(0),
                account: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
            });
    }
}
