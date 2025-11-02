// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library BankLibrary {
    function safeAdd(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "Underflow error");
        return a - b;
    }
}
