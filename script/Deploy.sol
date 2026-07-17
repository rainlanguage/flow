// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Script} from "forge-std/Script.sol";
import {LibRainDeploy} from "rain-deploy-0.1.2/src/lib/LibRainDeploy.sol";
import {Flow} from "../src/concrete/Flow.sol";
import {
    DEPLOYED_ADDRESS as FLOW_DEPLOYED_ADDRESS,
    BYTECODE_HASH as FLOW_BYTECODE_HASH
} from "../src/generated/Flow.pointers.sol";

bytes32 constant DEPLOYMENT_SUITE_FLOW = keccak256("flow");

/// @title Deploy
/// @notice Deterministic deployment of the Flow implementation via the Zoltu
/// factory across all supported networks. Requires DEPLOYMENT_KEY +
/// DEPLOYMENT_SUITE=flow.
contract Deploy is Script {
    mapping(string => mapping(address => bytes32)) internal sDepCodeHashes;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYMENT_KEY");
        bytes32 suite = keccak256(bytes(vm.envString("DEPLOYMENT_SUITE")));

        if (suite == DEPLOYMENT_SUITE_FLOW) {
            LibRainDeploy.deployAndBroadcast(
                vm,
                LibRainDeploy.supportedNetworks(),
                deployerPrivateKey,
                type(Flow).creationCode,
                "src/concrete/Flow.sol:Flow",
                FLOW_DEPLOYED_ADDRESS,
                FLOW_BYTECODE_HASH,
                new address[](0),
                sDepCodeHashes
            );
        } else {
            revert("Unknown deployment suite");
        }
    }
}
