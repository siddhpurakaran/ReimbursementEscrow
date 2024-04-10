// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract ReimbursementEscrow is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;

    IERC20 public usdt;
    uint256 immutable lockTime = 24 * 60 * 60 * 365 * 3; // 3 years
    mapping(address => uint256) emplyeeQuotas;
    mapping(address => uint256) cancellationAllowedFrom;

    error ZeroAddress();
    error InvalidAmt();
    error QuotaIsZero();
    error WaitForCoolingPeriod();
    error AlreadySet();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _usdt) public initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();
        if (_usdt == address(0)) {
            revert ZeroAddress();
        }
        usdt = IERC20(_usdt);
    }

    function lockAmtInEscrow(address employee, uint256 amount) external onlyOwner whenNotPaused nonReentrant {
        if (address(usdt) == address(0)) {
            revert ZeroAddress();
        }
        if (employee == address(0)) {
            revert ZeroAddress();
        }
        if (amount == 0) {
            revert InvalidAmt();
        }
        if (emplyeeQuotas[employee] != 0 || cancellationAllowedFrom[employee] != 0) {
            revert AlreadySet();
        }
        emplyeeQuotas[employee] += amount;
        cancellationAllowedFrom[employee] += block.timestamp + lockTime;
        usdt.safeTransferFrom(msg.sender, address(this), amount);
    }

    function sendReimbursement(address employee) external onlyOwner whenNotPaused nonReentrant {
        if (emplyeeQuotas[employee] == 0) {
            revert QuotaIsZero();
        }
        uint256 amount = emplyeeQuotas[employee];
        emplyeeQuotas[employee] = 0;
        cancellationAllowedFrom[employee] = 0;
        usdt.safeTransfer(employee, amount);
    }

    function cancleReimbursement(address employee) external onlyOwner whenNotPaused nonReentrant {
        if (emplyeeQuotas[employee] == 0) {
            revert QuotaIsZero();
        }
        if (cancellationAllowedFrom[employee] > block.timestamp) {
            revert WaitForCoolingPeriod();
        }
        uint256 amount = emplyeeQuotas[employee];
        emplyeeQuotas[employee] = 0;
        cancellationAllowedFrom[employee] = 0;
        usdt.safeTransfer(msg.sender, amount);
    }
}
