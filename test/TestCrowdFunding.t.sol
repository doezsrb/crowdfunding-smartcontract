//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {console} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {CrowdFunding} from "../src/CrowdFunding.sol";

contract TestCrowdFunding is Test {
    address OWNER = makeAddr("owner");
    address FUNDER = makeAddr("funDER");
    address FUNDER2 = makeAddr("funDER2");
    CrowdFunding crowdFunding;

    function setUp() public {
        vm.startPrank(OWNER);
        crowdFunding = new CrowdFunding(OWNER);
        crowdFunding.start();
        vm.stopPrank();

        vm.deal(FUNDER, 1 ether);
        vm.deal(FUNDER2, 1 ether);
    }

    function testGetAllFunds() public {
        uint256 fundAmount1 = 0.4 ether;
        uint256 fundAmount2 = 0.3 ether;
        vm.startPrank(FUNDER);
        crowdFunding.fund{value: fundAmount1}();
        vm.stopPrank();
        vm.startPrank(FUNDER2);
        crowdFunding.fund{value: fundAmount2}();
        vm.stopPrank();
        (address[] memory s_allFunders, uint256[] memory amounts) = crowdFunding.getAllFunders();

        assertEq(s_allFunders[1], FUNDER2);
        assertEq(amounts[1], fundAmount2);
    }

    function testStartCrowdFunding() public view {
        CrowdFunding.CrowdFundingState state = crowdFunding.getState();
        assertEq(uint256(state), uint256(CrowdFunding.CrowdFundingState.OPEN));
    }

    function testDeadline() public {
        uint256 expected = 60400;
        vm.warp(block.timestamp + 10000);

        uint256 deadline = crowdFunding.DEADLINE();

        assertEq(expected, deadline);
    }

    function testFundFuncRevert() public {
        uint256 testFundAmount = 30 gwei;

        vm.expectRevert(CrowdFunding.CrowdFunding_LessThanMinimalAmount.selector);
        vm.startPrank(FUNDER);
        crowdFunding.fund{value: testFundAmount}();
        vm.stopPrank();
    }

    function testFundFunc() public {
        uint256 testFundAmount = 36 gwei;

        vm.startPrank(FUNDER);
        crowdFunding.fund{value: testFundAmount}();
        vm.stopPrank();

        uint256 allFunds = crowdFunding.s_allFunds();

        assertEq(allFunds, testFundAmount);
    }

    function testRefundAndDeleteFromArray() public {
        uint256 testFundAmount = 36 gwei;
        vm.startPrank(FUNDER);

        crowdFunding.fund{value: testFundAmount}();
        crowdFunding.refund();
        vm.stopPrank();
        uint256 balanceAfterActions = FUNDER.balance;
        uint256 lengthAllFunders = crowdFunding.getAllFundersLength();

        assertEq(lengthAllFunders, 0);
        assertEq(balanceAfterActions, 1 ether);
    }

    function testCheckFunderInArray() public {
        uint256 testFundAmount = 36 gwei;
        vm.startPrank(FUNDER);
        crowdFunding.fund{value: testFundAmount}();
        crowdFunding.fund{value: testFundAmount}();
        vm.stopPrank();

        assertEq(1, crowdFunding.getAllFundersLength());
    }

    function testCrowdStateClosed() public {
        uint256 testFundAmount = 36 gwei;
        vm.startPrank(FUNDER);
        crowdFunding.fund{value: testFundAmount}();
        vm.stopPrank();

        vm.warp(block.timestamp + (crowdFunding.DEADLINE() + 1));

        vm.startPrank(OWNER);
        crowdFunding.checkDeadline();
        vm.stopPrank();

        CrowdFunding.CrowdFundingState state = crowdFunding.s_state();

        assertEq(1, uint256(state));
    }

    function testCrowdStateOpen() public {
        uint256 testFundAmount = 36 gwei;
        vm.startPrank(FUNDER);
        crowdFunding.fund{value: testFundAmount}();
        vm.stopPrank();

        CrowdFunding.CrowdFundingState state = crowdFunding.s_state();

        assertEq(0, uint256(state));
    }

    function testRefundAll() public {
        uint256 testFundAmount = 36 gwei;
        vm.startPrank(FUNDER);
        crowdFunding.fund{value: testFundAmount}();
        vm.stopPrank();

        uint256 balanceAfterFund = FUNDER.balance;
        console.log("balanceAfterFund");
        console.log(balanceAfterFund);

        vm.startPrank(OWNER);
        crowdFunding.refundAll();
        vm.stopPrank();

        uint256 balanceAfterRefund = FUNDER.balance;

        console.log("balanceAfterRefund");
        console.log(balanceAfterRefund);
        assert(balanceAfterRefund != balanceAfterFund);
    }

    function testCrowdFundingSuccess() public {
        uint256 testFundAmount = 1 ether;
        vm.startPrank(FUNDER);
        crowdFunding.fund{value: testFundAmount}();
        vm.stopPrank();

        vm.startPrank(FUNDER2);
        crowdFunding.fund{value: testFundAmount}();
        vm.stopPrank();

        vm.warp(block.timestamp + (crowdFunding.DEADLINE() + 1));

        vm.startPrank(OWNER);
        crowdFunding.checkDeadline();
        vm.stopPrank();

        assertEq(OWNER.balance, 2 ether);
        assertEq(crowdFunding.getAllFundersLength(), 0);
        assertEq(crowdFunding.s_allFunds(), 0);
    }

    function testCrowdFundingFailed() public {
        uint256 testFundAmount = 36 gwei;
        vm.startPrank(FUNDER);
        crowdFunding.fund{value: testFundAmount}();
        vm.stopPrank();

        vm.startPrank(FUNDER2);
        crowdFunding.fund{value: testFundAmount}();
        vm.stopPrank();

        vm.warp(block.timestamp + (crowdFunding.DEADLINE() + 1));

        vm.startPrank(OWNER);
        crowdFunding.checkDeadline();
        vm.stopPrank();

        assertEq(FUNDER.balance, 1 ether);
        assertEq(FUNDER2.balance, 1 ether);
        assertEq(crowdFunding.getAllFundersLength(), 0);
        assertEq(crowdFunding.s_allFunds(), 0);
    }
}
