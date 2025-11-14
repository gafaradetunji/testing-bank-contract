// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Bank.sol";

contract MiniBankFactory is Ownable {
    using Clones for address;

    address public immutable implementation;
    address public immutable mainTreasury;
    IERC20 public immutable usdt;

    mapping(address => address[]) public userBanks;

    event BankCreated(address indexed owner, address bankAddress);

    constructor(IERC20 _usdt, address _mainTreasury) Ownable(msg.sender) {
        require(address(_usdt) != address(0) && _mainTreasury != address(0), "Invalid addresses");
        usdt = _usdt;
        mainTreasury = _mainTreasury;

        MiniBank bank = new MiniBank();
        implementation = address(bank);
    }

    function createBank() external returns (address newBank) {
        newBank = implementation.clone();

        MiniBank(payable(newBank)).initialize(usdt, mainTreasury);

        userBanks[msg.sender].push(newBank);
        emit BankCreated(msg.sender, newBank);
    }

    function getUserBanks(address owner) external view returns (address[] memory) {
        return userBanks[owner];
    }
}
