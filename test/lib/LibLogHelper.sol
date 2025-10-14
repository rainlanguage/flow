// SPDX-License-Identifier: CAL
pragma solidity=0.8.25;

import {Vm} from "forge-std/Test.sol";

library LibLogHelper {
    /// @dev Finds the first log with the specified event signature in the logs array.
    /// @param logs The array of logs to search through.
    /// @param eventSignature The event signature to find.
    /// @return foundLogs first log that matches the event signature.
    function findEvent(Vm.Log[] memory logs, bytes32 eventSignature) internal pure returns (Vm.Log memory) {
        Vm.Log[] memory foundLogs = findEvents(logs, eventSignature);
        require(foundLogs.length >= 1, "Event not found!");
        return (foundLogs[0]);
    }

    /// @dev Finds all logs with the specified event signature in the logs array.
    /// @param logs The array of logs to search through.
    /// @param eventSignature The event signature to find.
    /// @return foundLogs array of logs that match the event signature.
    function findEvents(Vm.Log[] memory logs, bytes32 eventSignature)
        internal
        pure
        returns (Vm.Log[] memory foundLogs)
    {
        foundLogs = new Vm.Log[](logs.length);
        uint256 foundCount = 0;

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == eventSignature) {
                foundLogs[foundCount] = logs[i];
                foundCount++;
            }
        }

        assembly ("memory-safe") {
            mstore(foundLogs, foundCount)
        }
    }
}
