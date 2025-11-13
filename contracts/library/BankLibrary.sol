// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
// a library for performing overflow-safe math, courtesy of DappHub (https://github.com/dapphub/ds-math)

library BankLibrary {
    function safeAdd(uint256 a, uint256 b) internal pure returns (uint c) {
        require((c = a + b) >= a, 'ds-math-add-overflow');
    }

    function safeSub(uint256 a, uint256 b) internal pure returns (uint c) {
        require((c = a - b) <= a, 'ds-math-sub-underflow');
    }
    // percent expressed in basis points (bps) where 10000 == 100%
    function percentOf(uint256 amount, uint256 bps) internal pure returns (uint256) {
        // safe division order: amount * bps / 10000
        return (amount * bps) / 10000;
    }
}
