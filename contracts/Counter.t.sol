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
        bank = new MiniBank(IERC20(address(usdt)), treasury);
        vm.deal(user, 10 ether);
        vm.deal(user2, 5 ether);
        usdt.transfer(user, 1000 ether);
        usdt.transfer(user2, 1000 ether);
    }

    // ---- Constructor ----
    function test_RevertWhenZeroAddress() public {
        vm.expectRevert(MiniBank.zeroAddress.selector);
        new MiniBank(IERC20(address(0)), treasury);
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
      address user = vm.addr(1);
      vm.deal(user, 20 ether);

      // User creates a plan
      vm.startPrank(user);
      bank.createPlan{value: amount}("ETH Fuzz Plan", block.timestamp + 1 days, 0);

      // Warp forward to after plan end date
      vm.warp(block.timestamp + 2 days);

      // Perform withdraw
      bank.WithdrawFromPlan(0);
      vm.stopPrank();

      // Check plan count via getter
      uint256 planCount = bank.getUserPlanCount(user);
      assertEq(planCount, 0);

      // Verify contract’s ETH balance reduced by roughly amount (minus fee)
      uint256 expectedFee = BankLibrary.percentOf(amount, bank.platformFeeBps());
      uint256 expectedTreasuryBalance = expectedFee;
      assertEq(treasury.balance, expectedTreasuryBalance);
    }

    function testFuzz_WithdrawUSDT(uint256 amount) public {
      // Bound fuzz input (10–10_000 ether)
      amount = bound(amount, 10 ether, 10_000 ether);

      address user = vm.addr(1);
      usdt.transfer(user, amount);
      vm.startPrank(user);

      // Approve and create plan
      usdt.approve(address(bank), amount);
      bank.createPlan("USDT Fuzz Plan", block.timestamp + 1 days, amount);

      // Warp after maturity
      vm.warp(block.timestamp + 2 days);

      // Get balances before
      uint256 userBefore = usdt.balanceOf(user);
      uint256 treasuryBefore = usdt.balanceOf(treasury);

      // Withdraw
      bank.WithdrawFromPlan(0);
      vm.stopPrank();

      // Compute expected values
      uint256 fee = BankLibrary.percentOf(amount, bank.platformFeeBps());
      uint256 expectedUserBalance = userBefore + (amount - fee);
      uint256 expectedTreasuryBalance = treasuryBefore + fee;

      assertEq(usdt.balanceOf(user), expectedUserBalance);
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
      address user = vm.addr(1);
      vm.deal(user, 20 ether);

      // Deposit into ETH plan
      vm.startPrank(user);
      bank.createPlan{value: amount}("Invariant ETH Plan", block.timestamp + 1 days, 0);
      uint256 balanceBefore = bank.getEthBalance(user);
      vm.stopPrank();

      assertEq(balanceBefore, amount, "Deposit mismatch for ETH");

      // Warp to after plan end
      vm.warp(block.timestamp + 2 days);

      // Withdraw full amount
      vm.startPrank(user);
      bank.WithdrawFromPlan(0);
      uint256 balanceAfter = bank.getEthBalance(user);
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
      address user = vm.addr(1);
      usdt.transfer(user, amount);

      // Deposit into USDT plan
      vm.startPrank(user);
      usdt.approve(address(bank), amount);
      bank.createPlan("Invariant USDT Plan", block.timestamp + 1 days, amount);
      uint256 balanceBefore = bank.getUSDTBalance(user);
      vm.stopPrank();

      assertEq(balanceBefore, amount, "Deposit mismatch for USDT");

      // Warp to after plan end
      vm.warp(block.timestamp + 2 days);

      // Withdraw full amount
      vm.startPrank(user);
      bank.WithdrawFromPlan(0);
      uint256 balanceAfter = bank.getUSDTBalance(user);
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
