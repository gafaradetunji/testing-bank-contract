// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "./Bank.sol";
import "./library/BankLibrary.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDT is ERC20 {
    constructor() ERC20("Tether", "USDT") {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract MiniBankTest is Test {
    MiniBank bank;
    MockUSDT usdt;
    address treasury = address(0xBEEF);
    address user = address(0x123);
    address user2 = address(0x456);

    function setUp() public {
      usdt = new MockUSDT();

      bank = new MiniBank();
      bank.initialize(usdt, treasury);

      vm.deal(user, 10 ether);
      vm.deal(user2, 5 ether);

      usdt.transfer(user, 1000 ether);
      usdt.transfer(user2, 1000 ether);
    }

    // ---- Constructor ----
    function test_RevertWhenZeroAddress() public {
      // vm.expectRevert(MiniBank.zeroAddress.selector);
      MiniBank b = new MiniBank();
      vm.expectRevert(MiniBank.zeroAddress.selector);
      b.initialize(IERC20(address(0)), treasury);
    }

    // ---- Deposits ----
    function test_DepositETH() public {
        vm.startPrank(user);
        vm.expectEmit(true, false, false, true);
        emit MiniBank.DepositETH(user, 1 ether);
        bank.createPlan{value: 1 ether}("ETH Plan", block.timestamp + 1 days, 0);
        vm.stopPrank();

        assertEq(address(bank).balance, 1 ether);
    }

    function test_DepositUSDT() public {
        vm.startPrank(user);
        usdt.approve(address(bank), 100 ether);
        vm.expectEmit(true, false, false, true);
        emit MiniBank.DepositUSDT(user, 100 ether);
        bank.createPlan("USDT Plan", block.timestamp + 1 days, 100 ether);
        vm.stopPrank();

        assertEq(usdt.balanceOf(address(bank)), 100 ether);
    }

    // ---- Create Plan ----
    function test_ExpectEmitPlanCreated() public {
        vm.startPrank(user);
        usdt.approve(address(bank), 100 ether);
        vm.expectEmit(true, false, false, true);
        emit MiniBank.PlanCreated(user, 0, "My Plan");
        bank.createPlan("My Plan", block.timestamp + 1 days, 100 ether);
        vm.stopPrank();
    }

    function test_RevertExceedMaxPlans() public {
        vm.startPrank(user);
        usdt.approve(address(bank), 1000 ether);
        for (uint8 i = 0; i < 10; i++) {
            bank.createPlan("Plan", block.timestamp + 1 days, 100 ether);
        }
        vm.expectRevert(abi.encodeWithSelector(MiniBank.MaxPlansReached.selector));
        bank.createPlan("One Too Many", block.timestamp + 1 days, 100 ether);
        vm.stopPrank();
    }

    function test_RevertZeroDeposit() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(MiniBank.DepositMustBeGreaterThanZero.selector, 0));
        bank.createPlan("No Deposit", block.timestamp + 1 days, 0);
    }

    function test_RevertMixedDeposit() public {
        vm.startPrank(user);
        usdt.approve(address(bank), 10 ether);
        vm.expectRevert(MiniBank.MixedDepositNotAllowed.selector);
        bank.createPlan{value: 1 ether}("Invalid", block.timestamp + 1 days, 10 ether);
        vm.stopPrank();
    }

        // ---- Fuzz Tests for Deposits ----
    function testFuzz_DepositETH(uint256 amount) public {
        // Bound deposit between 0.01 and 20 ether
        amount = bound(amount, 0.01 ether, 20 ether);

        address user1 = vm.addr(1);
        vm.deal(user1, 50 ether);

        // Record initial state
        uint256 beforeBalance = address(bank).balance;
        uint256 beforeUserBalance = bank.getEthBalance(user1);

        // Execute deposit
        vm.startPrank(user1);
        bank.createPlan{value: amount}("ETH Deposit Fuzz", block.timestamp + 2 days, 0);
        vm.stopPrank();

        // Post-state assertions
        uint256 afterBalance = address(bank).balance;
        uint256 afterUserBalance = bank.getEthBalance(user1);

        assertEq(afterBalance, beforeBalance + amount, "Contract ETH balance mismatch");
        assertEq(afterUserBalance, beforeUserBalance + amount, "User ETH balance mismatch");
    }

    function testFuzz_DepositUSDT(uint256 amount) public {
        // Bound deposit between 10 and 10000 USDT
        amount = bound(amount, 10 ether, 10_000 ether);

        address user20 = vm.addr(2);
        usdt.transfer(user20, amount);
        vm.startPrank(user20);
        usdt.approve(address(bank), amount);

        uint256 beforeBankBalance = usdt.balanceOf(address(bank));
        uint256 beforeUserBalance = bank.getUSDTBalance(user20);

        // Execute deposit
        bank.createPlan("USDT Deposit Fuzz", block.timestamp + 3 days, amount);
        vm.stopPrank();

        uint256 afterBankBalance = usdt.balanceOf(address(bank));
        uint256 afterUserBalance = bank.getUSDTBalance(user20);

        assertEq(afterBankBalance, beforeBankBalance + amount, "Contract USDT balance mismatch");
        assertEq(afterUserBalance, beforeUserBalance + amount, "User USDT balance mismatch");
    }

        // ---- Invariant Tests for Deposits ----
    function invariant_depositETHConsistency() external {
        uint256 randomSeed = uint256(
            keccak256(abi.encodePacked(block.timestamp, block.prevrandao, address(this)))
        );
        uint256 amount = bound(randomSeed, 0.01 ether, 10 ether);

        address user3 = vm.addr(3);
        vm.deal(user3, 30 ether);

        uint256 beforeContractBalance = address(bank).balance;
        uint256 beforeUserBalance = bank.getEthBalance(user3);

        vm.startPrank(user3);
        bank.createPlan{value: amount}("Invariant ETH Deposit", block.timestamp + 1 days, 0);
        vm.stopPrank();

        uint256 afterContractBalance = address(bank).balance;
        uint256 afterUserBalance = bank.getEthBalance(user3);

        // Invariant: Total ETH change matches deposit amount
        assertEq(
            afterContractBalance - beforeContractBalance,
            amount,
            "ETH invariant failed: contract mismatch"
        );
        assertEq(
            afterUserBalance - beforeUserBalance,
            amount,
            "ETH invariant failed: user mismatch"
        );
    }

    function invariant_depositUSDTConsistency() external {
        uint256 randomSeed = uint256(
            keccak256(abi.encodePacked(block.timestamp, block.prevrandao, address(this)))
        );
        uint256 amount = bound(randomSeed, 10 ether, 10_000 ether);

        address user4 = vm.addr(4);
        usdt.transfer(user4, amount);
        vm.startPrank(user4);
        usdt.approve(address(bank), amount);

        uint256 beforeContractBalance = usdt.balanceOf(address(bank));
        uint256 beforeUserBalance = bank.getUSDTBalance(user4);

        bank.createPlan("Invariant USDT Deposit", block.timestamp + 2 days, amount);
        vm.stopPrank();

        uint256 afterContractBalance = usdt.balanceOf(address(bank));
        uint256 afterUserBalance = bank.getUSDTBalance(user4);

        // Invariant: Contract and internal balance must increase equally
        assertEq(
            afterContractBalance - beforeContractBalance,
            amount,
            "USDT invariant failed: contract mismatch"
        );
        assertEq(
            afterUserBalance - beforeUserBalance,
            amount,
            "USDT invariant failed: user mismatch"
        );
    }

    function test_RevertInvalidEndDate() public {
        vm.startPrank(user);
        usdt.approve(address(bank), 10 ether);
        uint256 invalidDate = block.timestamp - 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                MiniBank.InvalidEndDate.selector,
                invalidDate,
                block.timestamp
            )
        );
        bank.createPlan("BadDate", invalidDate, 10 ether);
        vm.stopPrank();
    }

    // ---- Update Plan ----
    function test_UpdatePlanEmitEvent() public {
        vm.startPrank(user);
        usdt.approve(address(bank), 200 ether);
        bank.createPlan("Plan", block.timestamp + 1 days, 100 ether);

        vm.expectEmit(true, false, false, true);
        emit MiniBank.PlanUpdated(user, 0, "Plan");
        bank.updatePlan(0, block.timestamp + 2 days, 100 ether);
        vm.stopPrank();
    }

    function test_RevertUpdateInvalidDate() public {
        vm.startPrank(user);
        usdt.approve(address(bank), 100 ether);
        bank.createPlan("Plan", block.timestamp + 2 days, 100 ether);
        uint256 invalidNewDate = block.timestamp + 1 days;
        uint256 invalidOldDate = block.timestamp + 2 days;
        vm.expectRevert(
            abi.encodeWithSelector(
                MiniBank.InvalidEndDate.selector,
                invalidNewDate,
                invalidOldDate
            )
        );
        bank.updatePlan(0, invalidNewDate, 0);
        vm.stopPrank();
    }

    // ---- Withdraw ETH ----
    function test_WithdrawETH_Normal_EmitEvent() public {
      vm.startPrank(user);
      bank.createPlan{value: 2 ether}("Plan", block.timestamp + 1, 0);
      vm.warp(block.timestamp + 2 days); // after endDate

      uint256 fee = BankLibrary.percentOf(2 ether, bank.platformFeeBps());
      uint256 withdrawAmount = 2 ether - fee;

      vm.expectEmit(true, false, false, true);
      emit MiniBank.WithdrawETH(user, withdrawAmount, fee);

      bank.WithdrawFromPlan(0);
      vm.stopPrank();
    }

    function test_WithdrawETH_EarlyPenalty_EmitEvent() public {
        vm.startPrank(user);
        bank.createPlan{value: 1 ether}("Early", block.timestamp + 1000, 0);
        vm.expectEmit(true, false, false, true);
        emit MiniBank.WithdrawETH(user, 0.945 ether, 0.055 ether); // approximate expected
        bank.WithdrawFromPlan(0);
        vm.stopPrank();
    }

    // ---- Withdraw USDT ----
    function test_WithdrawUSDT_EmitEvent() public {
        vm.startPrank(user);
        usdt.approve(address(bank), 100 ether);
        bank.createPlan("USDT Plan", block.timestamp + 1, 100 ether);
        vm.warp(block.timestamp + 2 days);
        vm.expectEmit(true, false, false, true);
        emit MiniBank.WithdrawUSDT(user, 99.5 ether, 0.5 ether); // 0.5% fee
        bank.WithdrawFromPlan(0);
        vm.stopPrank();
    }

    function testFuzz_WithdrawETH(uint256 amount) public {
      // Bound fuzz input
      amount = bound(amount, 0.01 ether, 10 ether);

      // Setup
      address user5 = vm.addr(1);
      vm.deal(user5, 20 ether);

      // User creates a plan
      vm.startPrank(user5);
      bank.createPlan{value: amount}("ETH Fuzz Plan", block.timestamp + 1 days, 0);

      // Warp forward to after plan end date
      vm.warp(block.timestamp + 2 days);

      // Perform withdraw
      bank.WithdrawFromPlan(0);
      vm.stopPrank();

      // Check plan count via getter
      uint256 planCount = bank.getUserPlanCount(user5);
      assertEq(planCount, 0);

      // Verify contract’s ETH balance reduced by roughly amount (minus fee)
      uint256 expectedFee = BankLibrary.percentOf(amount, bank.platformFeeBps());
      uint256 expectedTreasuryBalance = expectedFee;
      assertEq(treasury.balance, expectedTreasuryBalance);
    }

    function testFuzz_WithdrawUSDT(uint256 amount) public {
      // Bound fuzz input (10–10_000 ether)
      amount = bound(amount, 10 ether, 10_000 ether);

      address user6 = vm.addr(1);
      usdt.transfer(user6, amount);
      vm.startPrank(user6);

      // Approve and create plan
      usdt.approve(address(bank), amount);
      bank.createPlan("USDT Fuzz Plan", block.timestamp + 1 days, amount);

      // Warp after maturity
      vm.warp(block.timestamp + 2 days);

      // Get balances before
      uint256 userBefore = usdt.balanceOf(user6);
      uint256 treasuryBefore = usdt.balanceOf(treasury);

      // Withdraw
      bank.WithdrawFromPlan(0);
      vm.stopPrank();

      // Compute expected values
      uint256 fee = BankLibrary.percentOf(amount, bank.platformFeeBps());
      uint256 expectedUserBalance = userBefore + (amount - fee);
      uint256 expectedTreasuryBalance = treasuryBefore + fee;

      assertEq(usdt.balanceOf(user6), expectedUserBalance);
      assertEq(usdt.balanceOf(treasury), expectedTreasuryBalance);
    }

    // ---- Invariant Tests ----
    function invariant_alwaysWithdrawableETH() external {
      // Generate a pseudo-random amount
      uint256 randomSeed = uint256(
          keccak256(abi.encodePacked(block.timestamp, block.prevrandao, address(this)))
      );
      uint256 amount = bound(randomSeed, 0.01 ether, 10 ether);

      // Setup user and fund
      address user7 = vm.addr(1);
      vm.deal(user7, 20 ether);

      // Deposit into ETH plan
      vm.startPrank(user7);
      bank.createPlan{value: amount}("Invariant ETH Plan", block.timestamp + 1 days, 0);
      uint256 balanceBefore = bank.getEthBalance(user7);
      vm.stopPrank();

      assertEq(balanceBefore, amount, "Deposit mismatch for ETH");

      // Warp to after plan end
      vm.warp(block.timestamp + 2 days);

      // Withdraw full amount
      vm.startPrank(user7);
      bank.WithdrawFromPlan(0);
      uint256 balanceAfter = bank.getEthBalance(user7);
      vm.stopPrank();

      // Balance must decrease
      assertEq(balanceAfter, 0, "ETH balance should be zero after withdrawal");
    }

    function invariant_alwaysWithdrawableUSDT() external {
      // Generate a pseudo-random amount
      uint256 randomSeed = uint256(
          keccak256(abi.encodePacked(block.timestamp, block.prevrandao, address(this)))
      );
      uint256 amount = bound(randomSeed, 10 ether, 10_000 ether);

      // Setup user and fund
      address user8 = vm.addr(1);
      usdt.transfer(user8, amount);

      // Deposit into USDT plan
      vm.startPrank(user8);
      usdt.approve(address(bank), amount);
      bank.createPlan("Invariant USDT Plan", block.timestamp + 1 days, amount);
      uint256 balanceBefore = bank.getUSDTBalance(user8);
      vm.stopPrank();

      assertEq(balanceBefore, amount, "Deposit mismatch for USDT");

      // Warp to after plan end
      vm.warp(block.timestamp + 2 days);

      // Withdraw full amount
      vm.startPrank(user8);
      bank.WithdrawFromPlan(0);
      uint256 balanceAfter = bank.getUSDTBalance(user8);
      vm.stopPrank();

      // Balance must decrease
      assertEq(balanceAfter, 0, "USDT balance should be zero after withdrawal");
    }

    // ---- Plan Removal ----
    // function test_RemovePlanEmitEvent() public {
    //     vm.startPrank(user);
    //     usdt.approve(address(bank), 100 ether);
    //     bank.createPlan("Removable", block.timestamp + 1 days, 100 ether);
    //     vm.warp(block.timestamp + 2 days);
    //     bank.WithdrawFromPlan(0); // withdraw all first

    //     vm.expectEmit(true, false, false, true);
    //     emit MiniBank.PlanRemoved(user, 0);
    //     bank.WithdrawFromPlan(0);
    //     vm.stopPrank();
    // }

    // ---- Treasury ----
    function test_SetTreasuryOnlyOwner() public {
        address newTreasury = address(0xAAA);
        bank.setTreasury(newTreasury);
        assertEq(bank.treasury(), newTreasury);
    }

    function test_RevertSetTreasuryZeroAddress() public {
        vm.expectRevert("Invalid address");
        bank.setTreasury(address(0));
    }

    // ---- Getters ----
    function test_GetBalances() public {
        vm.startPrank(user);
        bank.createPlan{value: 1 ether}("Plan", block.timestamp + 1 days, 0);
        assertEq(bank.getEthBalance(user), 1 ether);
        vm.stopPrank();
    }
}
