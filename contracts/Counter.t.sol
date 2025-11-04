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
    vm.deal(user, 10 ether);
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

  function testFuzz_Deposit(uint256 amount) public {
    vm.assume(amount > 0 && amount <= 1 ether);

    user = vm.addr(1);
    vm.deal(user, 1 ether);

    vm.startPrank(user);
    counter.deposit{value: amount}();
    vm.stopPrank();

    uint256 balance = counter.getBalance(user);
    assertEq(balance, amount);
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
  function testWithdrawFail() public {
    vm.startPrank(user);
    counter.deposit{value: 0.5 ether}();
    vm.expectRevert(abi.encodeWithSelector(MiniBank.InsufficientBalance.selector));
    counter.withdraw(0.6 ether);
    vm.expectRevert(abi.encodeWithSelector(MiniBank.WithdrawAmountMustBeGreaterThanZero.selector, 0));
    counter.withdraw(0);
    vm.stopPrank();
  }
  function testFuzz_Withdraw(uint256 amount) public {
    amount = bound(amount, 0.1 ether, type(uint256).max);

    user = vm.addr(1);
    vm.deal(user, type(uint256).max);

    vm.startPrank(user);
    counter.deposit{value: amount}();
    counter.withdraw(amount);
    vm.stopPrank();

    uint256 balance = counter.getBalance(user);
    assertEq(balance, 0);
  }

  function testGetBalance() public {
    vm.startPrank(user);
    counter.deposit{value: 0.7 ether}();
    vm.stopPrank();

    uint256 balance = counter.getBalance(user);
    assertEq(balance, 0.7 ether);
  }

  function invariant_alwaysWithdrawable() external {
    user = vm.addr(1);
    vm.deal(user, type(uint256).max);

    uint256 randomSeed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, address(this))));
    uint256 amount = bound(randomSeed, 0.1 ether, type(uint256).max);

    vm.startPrank(user);
    counter.deposit{value: amount}();
    uint256 balanceBefore = counter.getBalance(user);
    vm.stopPrank();

    assertEq(balanceBefore, amount, "Deposit balance mismatch");

    vm.startPrank(user);
    counter.withdraw(amount);
    uint256 balanceAfter = counter.getBalance(user);
    vm.stopPrank();

    assertGt(balanceBefore, balanceAfter, "Balance did not decrease after withdraw");
}


}
