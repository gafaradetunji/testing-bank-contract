// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./interfaces/IBank.sol";
import "./BaseBank.sol";
import "./library/BankLibrary.sol";

contract MiniBank is IBank, BaseBank {
    using BankLibrary for uint256;
    error DepositMustBeGreaterThanZero(uint256 amount);
    error WithdrawAmountMustBeGreaterThanZero(uint256 amount);
    error InsufficientBalance();

    mapping(address => uint256) private balances;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    function deposit() external payable override {
        if (msg.value <= 0) revert DepositMustBeGreaterThanZero(msg.value);
        balances[msg.sender] = balances[msg.sender].safeAdd(msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external override {
        if (amount <= 0) revert WithdrawAmountMustBeGreaterThanZero(amount);
        if (balances[msg.sender] < amount) revert InsufficientBalance();

        balances[msg.sender] = balances[msg.sender].safeSub(amount);

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");

        emit Withdraw(msg.sender, amount);
    }

    function getBalance(address user) public view override returns (uint256) {
        return balances[user];
    }

    receive() external payable {} 
}
