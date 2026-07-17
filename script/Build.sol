// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Script} from "forge-std/Script.sol";
import {LibRainDeploy} from "rain-deploy-0.1.2/src/lib/LibRainDeploy.sol";
import {LibCodeGen} from "rain-sol-codegen-0.1.0/src/lib/LibCodeGen.sol";
import {LibFs} from "rain-sol-codegen-0.1.0/src/lib/LibFs.sol";
import {Flow} from "../src/concrete/Flow.sol";

/// @title Build
/// @notice Deploys the Flow implementation via the Zoltu factory in a local
/// environment and generates `Flow.pointers.sol` with the deterministic deploy
/// address and bytecode hash.
contract Build is Script {
    function addressConstantString(address addr) internal pure returns (string memory) {
        return string.concat(
            "\n",
            "/// @dev The deterministic deploy address of the contract when deployed via\n",
            "/// the Zoltu factory.\n",
            "address constant DEPLOYED_ADDRESS = address(",
            vm.toString(addr),
            ");\n"
        );
    }

    function run() external {
        LibRainDeploy.etchZoltuFactory(vm);
        address deployed = LibRainDeploy.deployZoltu(type(Flow).creationCode);
        LibFs.buildFileForContract(
            vm,
            deployed,
            "Flow",
            string.concat(
                addressConstantString(deployed),
                LibCodeGen.bytesConstantString(
                    vm, "/// @dev The creation bytecode of the contract.", "CREATION_CODE", type(Flow).creationCode
                )
            )
        );
    }
}
