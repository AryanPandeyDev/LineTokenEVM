//SPDX-License-Identifier:MIT

pragma solidity ^0.8.24;

interface AutomationRegistrarInterface {
    // Registration parameters struct
    struct RegistrationParams {
        string name;
        bytes encryptedEmail;
        address upkeepContract;
        uint32 gasLimit;
        address adminAddress;
        uint8 triggerType; // 0 = conditional, 1 = log trigger
        bytes checkData;
        bytes triggerConfig;
        bytes offchainConfig;
        uint96 amount;
    }

    function registerUpkeep(
        RegistrationParams calldata requestParams
    ) external returns (uint256);
}
