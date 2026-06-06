// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

library LibConvertSlow {
    function toBytesSlow(uint256[] memory us) internal pure returns (bytes memory) {
        return abi.encodePacked(us);
    }

    function to16BitBytesSlow(uint256[] memory us) internal pure returns (bytes memory) {
        bytes memory ret = new bytes(0);
        for (uint256 i = 0; i < us.length; i++) {
            ret = bytes.concat(ret, bytes2(uint16(us[i])));
        }
        return ret;
    }
}
