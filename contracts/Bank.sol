// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./interfaces/IBank.sol";
import "./BaseBank.sol";
import "./library/BankLibrary.sol";

/**
 * @title MiniBank
 * @notice A minimal banking contract allowing users to deposit ETH or USDT, 
 *         create savings plans, and manage them (update or remove).
 * @dev Uses SafeERC20 for USDT transfers and ReentrancyGuard for safety.
 */
contract MiniBank is IBank, BaseBank, ReentrancyGuard {
    using BankLibrary for uint;
    using SafeERC20 for IERC20;

    // ----------- Custom Errors ----------- //
    error DepositMustBeGreaterThanZero(uint amount);
    error WithdrawAmountMustBeGreaterThanZero(uint amount);
    error InsufficientBalance();
    error PlanNotFound(uint256 planId);
    error MaxPlansReached();
    error MixedDepositNotAllowed();
    error InvalidEndDate(uint256 newDate, uint256 currentDate);
    error PlanHasActiveFunds(uint256 ethAmount, uint256 usdtAmount);
    error NoFundsToWithdraw();
    error zeroAddress();

    // ----------- Constants & State Variables ----------- //
    uint256 public constant MAX_PLANS = 10;
    uint256 public constant platformFeeBps = 50; // 0.5%
    uint256 public constant earlyWithdrawalPenaltyBps = 500; // 5%
    IERC20 public immutable usdt;
    address public treasury;

    mapping(address => uint256) private ethBalances;
    mapping(address => uint256) private usdtBalances;

    struct Plan {
        uint256 id;
        string name;
        uint256 startDate;
        uint256 endDate;
        uint256 totalUsdtDeposited;
        uint256 totalEthDeposited;
        bool active;
    }

    mapping(address => Plan[]) public userPlans;

    // ----------- Events ----------- //
    event Deposit(address indexed user, uint amount);
    event Withdraw(address indexed user, uint amount);
    event DepositETH(address indexed user, uint256 amount);
    event DepositUSDT(address indexed user, uint256 amount);
    event EnterPlan(address indexed user, uint8 planIndex, uint256 amount);
    event WithdrawETH(address indexed user, uint256 amount, uint256 fee);
    event WithdrawUSDT(address indexed user, uint256 amount, uint256 fee);
    event PlanWithdrawn(address indexed user, uint8 planIndex, uint256 principal, uint256 fee, uint256 penalty);
    event PlanRemoved(address indexed user, uint8 planIndex);
    event PlanCreated(address indexed user, uint8 planIndex, string name);
    event PlanUpdated(address indexed user, uint8 planIndex, string name);

    /**
     * @notice Initializes the MiniBank contract with a USDT token reference.
     * @param _usdt The address of the USDT token contract.
     */
    constructor(IERC20 _usdt, address _treasury) BaseBank() {
        if(address(_usdt) == address(0)) revert zeroAddress();
        if(_treasury == address(0)) revert zeroAddress();
        usdt = _usdt;
        treasury = _treasury;
    }

    /// @notice Allows contract to receive plain ETH transfers.
    receive() external payable {}

    // ----------- View Functions ----------- //

    /**
     * @notice Returns the ETH balance of a given user.
     * @param user The address of the user.
     * @return The total ETH balance of the user in wei.
     */
    function getEthBalance(address user) external view returns (uint256) {
        return ethBalances[user];
    }
    function getUserPlanCount(address user) external view returns (uint256) {
        return userPlans[user].length;
    }

    /**
     * @notice Returns the USDT balance of a given user.
     * @param user The address of the user.
     * @return The total USDT balance of the user.
     */
    function getUSDTBalance(address user) external view returns (uint256) {
        return usdtBalances[user];
    }

    // ----------- External Functions ----------- //

    function setTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Invalid address");
        treasury = newTreasury;
    }

    /**
     * @notice Creates a new savings plan for the caller.
     * @dev Users can deposit either ETH or USDT (not both) and must not exceed MAX_PLANS.
     * @param name The name of the savings plan.
     * @param endDate The timestamp when the plan ends. Must be in the future.
     * @param amount The USDT amount to deposit (set to 0 if depositing ETH).
     */
    function createPlan(
        string calldata name,
        uint256 endDate,
        uint256 amount
    ) external payable nonReentrant {
        if (userPlans[msg.sender].length >= MAX_PLANS) revert MaxPlansReached();
        if (amount == 0 && msg.value == 0) revert DepositMustBeGreaterThanZero(0);
        if (amount > 0 && msg.value > 0) revert MixedDepositNotAllowed();
        if (endDate <= block.timestamp) revert InvalidEndDate(endDate, block.timestamp);

        if (msg.value > 0) {
            depositETH();
        } else {
            depositUSDT(amount);
        }

        uint256 planId = userPlans[msg.sender].length + 1;

        userPlans[msg.sender].push(Plan({
            id: planId,
            name: name,
            startDate: block.timestamp,
            endDate: endDate,
            totalUsdtDeposited: amount,
            totalEthDeposited: msg.value,
            active: true
        }));

        emit PlanCreated(msg.sender, uint8(planId - 1), name);
    }

    /**
     * @notice Updates an existing plan by extending its end date or adding more funds.
     * @dev The end date cannot be reduced; it must always increase or remain the same.
     * @param planIndex The index of the plan to update in the user's plan array.
     * @param newEndDate The new end date (must be >= current end date).
     * @param usdtAmount The USDT amount to deposit (set to 0 if depositing ETH).
     */
    function updatePlan(
        uint8 planIndex,
        uint256 newEndDate,
        uint256 usdtAmount
    ) external payable nonReentrant {
        Plan[] storage plans = userPlans[msg.sender];
        if (planIndex >= plans.length) revert PlanNotFound(planIndex);

        Plan storage plan = plans[planIndex];
        if (newEndDate < plan.endDate) revert InvalidEndDate(newEndDate, plan.endDate);
        if (msg.value > 0 && usdtAmount > 0) revert MixedDepositNotAllowed();

        if (msg.value > 0) {
            depositETH();
            plan.totalEthDeposited += msg.value;
        }

        if (usdtAmount > 0) {
            depositUSDT(usdtAmount);
            plan.totalUsdtDeposited += usdtAmount;
        }

        if (newEndDate > plan.endDate) {
            plan.endDate = newEndDate;
        }

        emit PlanUpdated(msg.sender, planIndex, plan.name);
    }

    /**
     * @notice Withdraws funds from a savings plan, apply fees and penalties if applicable.
     * @dev Handles both ETH and USDT plans. Applies early withdrawal penalty if before endDate.
     * @param planIndex The index of the plan to withdraw from.
     */
    function WithdrawFromPlan(uint8 planIndex) external nonReentrant {
        Plan[] storage plans = userPlans[msg.sender];
        if (planIndex >= plans.length) revert PlanNotFound(planIndex);

        Plan storage plan = plans[planIndex];
        uint256 ethBalance = plan.totalEthDeposited;
        uint256 usdtBalance = plan.totalUsdtDeposited;

        if (ethBalance == 0 && usdtBalance == 0) revert NoFundsToWithdraw();

        bool isEarly = block.timestamp < plan.endDate;

        uint256 ethFee = 0;
        uint256 usdtFee = 0;
        uint256 ethPenalty = 0;
        uint256 usdtPenalty = 0;

        if (ethBalance > 0) {
            ethFee = BankLibrary.percentOf(ethBalance, platformFeeBps);

            if (isEarly) {
                ethPenalty = BankLibrary.percentOf(ethBalance, earlyWithdrawalPenaltyBps);
            }

            uint256 totalFee = ethFee.safeAdd(ethPenalty);
            uint256 withdrawAmount = ethBalance.safeSub(totalFee);

            plan.totalEthDeposited = 0;
            ethBalances[msg.sender] = ethBalances[msg.sender].safeSub(ethBalance);

            (bool sentFee, ) = payable(treasury).call{value: totalFee}("");
            require(sentFee, "ETH fee transfer failed");

            (bool success, ) = payable(msg.sender).call{value: withdrawAmount}("");
            require(success, "ETH transfer failed");

            emit WithdrawETH(msg.sender, withdrawAmount, totalFee);
        }

        if (usdtBalance > 0) {
            usdtFee = BankLibrary.percentOf(usdtBalance, platformFeeBps);

            if (isEarly) {
                usdtPenalty = BankLibrary.percentOf(usdtBalance, earlyWithdrawalPenaltyBps);
            }

            uint256 totalFee = usdtFee.safeAdd(usdtPenalty);
            uint256 withdrawAmount = usdtBalance.safeSub(totalFee);

            plan.totalUsdtDeposited = 0;
            usdtBalances[msg.sender] = usdtBalances[msg.sender].safeSub(usdtBalance);

            usdt.safeTransfer(treasury, totalFee);
            usdt.safeTransfer(msg.sender, withdrawAmount);

            emit WithdrawUSDT(msg.sender, withdrawAmount, totalFee);
        }

        removePlan(planIndex);

        emit PlanWithdrawn(
            msg.sender,
            planIndex,
            ethBalance + usdtBalance,
            ethFee + usdtFee,
            ethPenalty + usdtPenalty
        );
    }
    
    /**
     * @notice Removes a plan from the user's list if it contains no funds.
     * @dev Uses swap-and-pop to efficiently remove from array.
     * @param index The index of the plan to remove.
     */
    function removePlan(uint8 index) private {
        Plan[] storage plans = userPlans[msg.sender];
        if (index >= plans.length) revert PlanNotFound(index);

        Plan storage plan = plans[index];
        if (plan.totalEthDeposited > 0 || plan.totalUsdtDeposited > 0)
            revert PlanHasActiveFunds(plan.totalEthDeposited, plan.totalUsdtDeposited);

        uint256 lastIndex = plans.length - 1;

        if (index != lastIndex) {
            plans[index] = plans[lastIndex];
        }

        plans.pop();
        emit PlanRemoved(msg.sender, index);
    }

    // ----------- Internal Deposit Functions ----------- //

    /**
     * @notice Handles ETH deposits into the user's account.
     * @dev Adds the sent value to the user's ETH balance.
     */
    function depositETH() internal {
        if (msg.value <= 0) revert DepositMustBeGreaterThanZero(msg.value);
        ethBalances[msg.sender] = ethBalances[msg.sender].safeAdd(msg.value);
        emit DepositETH(msg.sender, msg.value);
    }

    /**
     * @notice Handles USDT deposits into the user's account.
     * @dev Uses SafeERC20 to ensure safe transfer from the user.
     * @param amount The amount of USDT to deposit.
     */
    function depositUSDT(uint256 amount) internal {
        if (amount <= 0) revert DepositMustBeGreaterThanZero(amount);
        usdt.safeTransferFrom(msg.sender, address(this), amount);
        usdtBalances[msg.sender] = usdtBalances[msg.sender].safeAdd(amount);
        emit DepositUSDT(msg.sender, amount);
    }
}
