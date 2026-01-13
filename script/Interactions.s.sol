//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {ILineToken} from "src/LineToken/LineTokenInterface.sol";

contract MintLineToken is Script {
    uint256 public constant SEND_VALUE = 0.1 * 1e18; // Added constant
    address public USER = makeAddr("user");

    function mintLineToken(
        address mostRecentDeployed,
        address to,
        uint256 amount
    ) public {
        vm.startBroadcast();
        ILineToken(mostRecentDeployed).mint(to, amount);
        vm.stopBroadcast();
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "LineToken",
            block.chainid
        );
        mintLineToken(mostRecentlyDeployed, USER, SEND_VALUE);
    }
}

contract TransferLineToken is Script {
    uint256 public constant SEND_VALUE = 0.1 * 1e18;
    address public USER = makeAddr("user");

    // Fix 1: Added 'amount' parameter so you can pass it from run()
    function transferLineToken(
        address mostRecentDeployed,
        address to,
        uint256 amount
    ) public {
        vm.startBroadcast();
        ILineToken(mostRecentDeployed).transfer(to, amount);
        vm.stopBroadcast();
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "LineToken",
            block.chainid
        );
        // Fix 2: Passed SEND_VALUE here
        transferLineToken(mostRecentlyDeployed, USER, SEND_VALUE);
    }
}

contract TransferLineTokenBySender is Script {
    uint256 public constant SEND_VALUE = 0.1 * 1e18;
    address public USER = makeAddr("user");
    address public USER2 = makeAddr("user2");

    // Fix 3: Added 'amount' parameter
    function transferFromLineToken(
        address mostRecentDeployed,
        address from,
        address to,
        uint256 amount
    ) public {
        ILineToken(mostRecentDeployed).transferFrom(from, to, amount);
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "LineToken",
            block.chainid
        );
        // Fix 4: Passed 3 arguments (from, to, amount)
        transferFromLineToken(mostRecentlyDeployed, USER, USER2, SEND_VALUE);
    }
}

contract ApproveLineToken is Script {
    uint256 public constant SEND_VALUE = 0.1 * 1e18;
    address public USER = makeAddr("user");
    address public SPENDER = makeAddr("spender");

    function approveSpender(
        address mostRecentDeployed,
        address spender,
        uint256 amount
    ) public {
        vm.startBroadcast();
        ILineToken(mostRecentDeployed).approve(spender, amount);
        vm.stopBroadcast();
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "LineToken",
            block.chainid
        );
        approveSpender(mostRecentlyDeployed, SPENDER, SEND_VALUE);
    }
}
