// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/NFTMarketplace.sol";

contract DeployMarketplace is Script {
    function run() external {
        uint96 fee = 250; // 2.5%
        address feeRecipient = msg.sender;

        vm.startBroadcast();

        NFTMarketplace market = new NFTMarketplace(fee, feeRecipient);

        vm.stopBroadcast();

        console.log("Marketplace deployed at:", address(market));
    }
}
