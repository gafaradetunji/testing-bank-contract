// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBank {
    function getEthBalance(address user) external view returns (uint256);
    function getUSDTBalance(address user) external view returns (uint256);

    function createPlan(
        string calldata name, 
        uint256 endDate, 
        uint256 amount
    ) external payable;

    function updatePlan(
        uint8 planId,
        uint256 endDate,
        uint256 usdtAmount
    ) external payable;
}
