// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {MiniBank} from "./Bank.sol";
import {Test} from "forge-std/Test.sol";

contract CounterTest is Test {
  MiniBank counter;
  address user;

  function setUp() public {
    counter = new MiniBank();
    user = vm.addr(1);
    vm.deal(user, 1 ether);
  }

  function testDeposit() public {
    vm.startPrank(user);
    counter.deposit{value: 0.5 ether}();
    vm.stopPrank();

    uint256 balance = counter.getBalance(user);
    assertEq(balance, 0.5 ether);
  }

  function testDepositFail() public {
    vm.startPrank(user);
    vm.expectRevert(abi.encodeWithSelector(MiniBank.DepositMustBeGreaterThanZero.selector, 0));
    counter.deposit{value: 0 ether}();
    vm.stopPrank();
  }

  function testDepositMustEmitEvent() public {
    vm.startPrank(user);
    vm.expectEmit(true, false, false, true);
    emit MiniBank.Deposit(user, 0.5 ether);
    counter.deposit{value: 0.5 ether}();
    vm.stopPrank();
  }

  function testWithdraw() public {
    vm.startPrank(user);
    counter.deposit{value: 0.5 ether}();
    counter.withdraw(0.3 ether);
    vm.stopPrank();

    uint256 balance = counter.getBalance(user);
    assertEq(balance, 0.2 ether);
  }

  function testWithdrawMustEmitEvent() public {
    vm.startPrank(user);
    vm.expectEmit(true, false, false, true);
    emit MiniBank.Deposit(user, 0.5 ether);
    counter.deposit{value: 0.5 ether}();
    vm.expectEmit(true, false, false, true);
    emit MiniBank.Withdraw(user, 0.5 ether);
    counter.withdraw(0.5 ether);
    vm.stopPrank();
  }

}
