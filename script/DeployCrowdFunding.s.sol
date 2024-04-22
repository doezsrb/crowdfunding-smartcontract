//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {CrowdFunding} from "../src/CrowdFunding.sol";

contract DeployCrowdFunding is Script {
    function run() external {
        vm.startBroadcast();
        new CrowdFunding(msg.sender);
        vm.stopBroadcast();
    }
}
