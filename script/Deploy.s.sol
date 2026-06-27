// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {StreamPay} from "../src/StreamPay.sol";

/// @notice StreamPay kontratını deploy eder, adresi console'a yazar ve
///         deployments.json dosyasına {"StreamPay": "0x..."} formatında kaydeder.
contract DeployScript is Script {
    function run() external returns (StreamPay streamPay) {
        // .env'deki PRIVATE_KEY ile imzalayıp yayınla.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        streamPay = new StreamPay();
        vm.stopBroadcast();

        console2.log("StreamPay deployed at:", address(streamPay));

        // deployments.json dosyasına kaydet.
        string memory json = string.concat('{"StreamPay": "', vm.toString(address(streamPay)), '"}');
        vm.writeFile("deployments.json", json);
        console2.log("Saved to deployments.json");
    }
}
