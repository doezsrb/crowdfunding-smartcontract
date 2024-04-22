//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {console} from "forge-std/Script.sol";

contract CrowdFunding {
    error CrowdFunding_LessThanMinimalAmount();
    error CrowdFunding_IncorrectAddress();
    error CrowdFunding_OnlyOwnerAllowed();
    error CrowdFunding_AmountIsZero();
    error CrowdFunding_FailedRefund();
    error CrowdFunding_FailedTransferFundsToOwner();
    error CrowdFunding_FundingIsClosed();
    error CrowdFunding_FailedStart();

    uint256 public constant GOAL = 1 ether;

    uint256 public DEADLINE = 0;
    uint256 public constant TIMER = 50400; // 1 week
    address public immutable OWNER;
    uint256 public constant MINIMAL_FUND_AMOUNT = 35 gwei;

    mapping(address funder => uint256 amount) private s_funds;
    address[] public s_allFunders;
    address[] private failedTransaction;

    uint256 public s_allFunds;
    CrowdFundingState public s_state;

    enum CrowdFundingState {
        OPEN,
        CLOSED,
        FAILED,
        SUCCESS
    }

    event ReceivedFund(address indexed funder, uint256 amount);
    event RefundedFund(address indexed funder, uint256 amount);
    event CrowdFundingPassed(uint256 indexed amount);
    event CrowdFundingFailed(uint256 indexed amount);
    event CrowdFundingStarted();

    //TODO: refundAll set to be private
    constructor(address owner) {
        OWNER = owner;
        s_state = CrowdFundingState.CLOSED;
    }

    modifier onlyOwner() {
        if (msg.sender != OWNER) {
            revert CrowdFunding_OnlyOwnerAllowed();
        }
        _;
    }

    function start() public onlyOwner {
        if (s_state == CrowdFundingState.CLOSED) {
            s_state = CrowdFundingState.OPEN;
            DEADLINE = block.timestamp + TIMER;
            emit CrowdFundingStarted();
        } else {
            revert CrowdFunding_FailedStart();
        }
    }

    function refundAll() public {
        uint256 length = s_allFunders.length;

        for (uint256 i = 0; i < length; i++) {
            address funder = s_allFunders[i];
            uint256 amount = s_funds[s_allFunders[i]];
            (bool success,) = payable(funder).call{value: amount}("");
            if (success) {
                s_allFunds -= amount;
                s_funds[s_allFunders[i]] -= amount;
            } else {
                failedTransaction.push(funder);
            }
        }
        _clearAllFunders();
    }

    function fund() public payable {
        uint256 amount = msg.value;
        address funder = msg.sender;

        if (s_state != CrowdFundingState.OPEN) {
            revert CrowdFunding_FundingIsClosed();
        }
        if (funder == address(0)) {
            revert CrowdFunding_IncorrectAddress();
        }

        if (amount < MINIMAL_FUND_AMOUNT) {
            revert CrowdFunding_LessThanMinimalAmount();
        }

        s_allFunds += amount;
        s_funds[funder] += amount;
        if (!_checkFunderInAllFunders(funder)) {
            s_allFunders.push(funder);
        }
        emit ReceivedFund(funder, amount);
    }

    function checkDeadline() public {
        if (block.timestamp >= DEADLINE) {
            if (s_allFunds >= GOAL) {
                s_state = CrowdFundingState.SUCCESS;
                (bool success,) = payable(OWNER).call{value: address(this).balance}("");
                if (success) {
                    _resetStore();
                    emit CrowdFundingPassed(s_allFunds);
                } else {
                    revert CrowdFunding_FailedTransferFundsToOwner();
                }
            } else {
                s_state = CrowdFundingState.FAILED;
                refundAll();
                emit CrowdFundingFailed(s_allFunds);
            }
        }
    }

    function refund() public {
        uint256 amount = s_funds[msg.sender];
        if (amount == 0) revert CrowdFunding_AmountIsZero();

        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) revert CrowdFunding_FailedRefund();
        s_allFunds -= amount;
        s_funds[msg.sender] -= amount;
        _deleteFromAllFunders(msg.sender);
        emit RefundedFund(msg.sender, amount);
    }

    function _resetStore() public {
        uint256 length = s_allFunders.length;
        for (uint256 i = 0; i < length; i++) {
            address funder = s_allFunders[i];
            s_funds[funder] = 0;
        }
        s_allFunders = new address[](0);
        s_allFunds = 0;
    }

    function _checkFunderInAllFunders(address funder) private view returns (bool) {
        uint256 length = s_allFunders.length;
        for (uint256 i = 0; i < length; i++) {
            if (funder == s_allFunders[i]) {
                return true;
            }
        }

        return false;
    }

    function _clearAllFunders() private {
        s_allFunders = failedTransaction;
        failedTransaction = new address[](0);
    }

    function _deleteFromAllFunders(address funder) private {
        uint256 length = s_allFunders.length;
        for (uint256 i = 0; i < length; i++) {
            if (funder == s_allFunders[i]) {
                s_allFunders[i] = s_allFunders[length - 1];
                s_allFunders.pop();
            }
        }
    }

    function _removeFromAllFunders(uint256 _index) public {
        require(_index < s_allFunders.length, "index out of bound");

        for (uint256 i = _index; i < s_allFunders.length - 1; i++) {
            s_allFunders[i] = s_allFunders[i + 1];
        }
        s_allFunders.pop();
    }

    function getAllFundersLength() public view returns (uint256) {
        return s_allFunders.length;
    }

    function getAllFunders() public view returns (address[] memory, uint256[] memory) {
        uint256[] memory amounts = new uint256[](s_allFunders.length);
        for (uint256 i = 0; i < s_allFunders.length; i++) {
            amounts[i] = s_funds[s_allFunders[i]];
        }
        return (s_allFunders, amounts);
    }

    function getMinimalFundAmount() public pure returns (uint256) {
        return MINIMAL_FUND_AMOUNT;
    }

    function getAllFunds() public view returns (uint256) {
        return s_allFunds;
    }

    function getState() public view returns (CrowdFundingState) {
        return s_state;
    }

    function getGoal() public pure returns (uint256) {
        return GOAL;
    }

    function getTimerToGo() public view returns (uint256) {
        return DEADLINE - block.timestamp;
    }
}
