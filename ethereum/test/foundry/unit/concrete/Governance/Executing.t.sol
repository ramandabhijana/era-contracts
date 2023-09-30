// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {GovernanceTest} from "./_Governance_Shared.t.sol";
import {Utils} from "../Utils/Utils.sol";
import {IGovernance} from "../../../../../cache/solpp-generated-contracts/governance/IGovernance.sol";

contract ExecutingTest is GovernanceTest {
    function test_ScheduleTransparentAndExecute() public {
        vm.startPrank(owner);

        IGovernance.Operation memory op = operationWithOneCallZeroSaltAndPredecessor(address(eventOnFallback), 0, "");
        governance.scheduleTransparent(op, 1000);
        vm.warp(block.timestamp + 1000);
        executeOpAndCheck(op);
    }

    function test_ScheduleTransparentAndExecuteInstant() public {
        IGovernance.Operation memory op = operationWithOneCallZeroSaltAndPredecessor(address(eventOnFallback), 0, "");
        vm.prank(owner);
        governance.scheduleTransparent(op, 1000000);
        vm.prank(securityCouncil);
        executeInstantOpAndCheck(op);
    }

    function test_ScheduleShadowAndExecute() public {
        IGovernance.Operation memory op = operationWithOneCallZeroSaltAndPredecessor(address(eventOnFallback), 0, "");
        bytes32 opId = governance.hashOperation(op);
        vm.startPrank(owner);
        governance.scheduleShadow(opId, 100000);
        vm.warp(block.timestamp + 100001);
        vm.startPrank(securityCouncil);
        executeOpAndCheck(op);
    }

    function test_ScheduleShadowAndExecuteInstant() public {
        IGovernance.Operation memory op = operationWithOneCallZeroSaltAndPredecessor(address(eventOnFallback), 0, "");
        bytes32 opId = governance.hashOperation(op);
        vm.startPrank(owner);
        governance.scheduleShadow(opId, 100000);
        vm.startPrank(securityCouncil);
        executeInstantOpAndCheck(op);
    }

    function test_RevertWhen_ExecutingOperationBeforeDeadline() public {
        vm.startPrank(owner);
        IGovernance.Operation memory op = operationWithOneCallZeroSaltAndPredecessor(address(eventOnFallback), 0, "");
        governance.scheduleTransparent(op, 10000);
        vm.expectRevert(bytes("Operation must be ready before execution"));
        governance.execute(op);
    }

    function test_RevertWhen_ExecutingOperationWithDifferentTarget() public {
        vm.startPrank(owner);
        IGovernance.Operation memory validOp = operationWithOneCallZeroSaltAndPredecessor(
            address(eventOnFallback),
            0,
            ""
        );
        governance.scheduleTransparent(validOp, 0);

        IGovernance.Operation memory invalidOp = operationWithOneCallZeroSaltAndPredecessor(address(0), 0, "");
        vm.expectRevert(bytes("Operation must be ready before execution"));
        governance.execute(invalidOp);
    }

    function test_RevertWhen_ExecutingOperationWithDifferentValue() public {
        vm.startPrank(owner);
        IGovernance.Operation memory validOp = operationWithOneCallZeroSaltAndPredecessor(
            address(eventOnFallback),
            0,
            ""
        );
        governance.scheduleTransparent(validOp, 0);

        IGovernance.Operation memory invalidOp = operationWithOneCallZeroSaltAndPredecessor(
            address(eventOnFallback),
            1,
            ""
        );
        vm.expectRevert(bytes("Operation must be ready before execution"));
        governance.execute(invalidOp);
    }

    function test_RevertWhen_ExecutingOperationWithDifferentData() public {
        vm.startPrank(owner);
        IGovernance.Operation memory validOp = operationWithOneCallZeroSaltAndPredecessor(
            address(eventOnFallback),
            0,
            ""
        );
        governance.scheduleTransparent(validOp, 0);

        IGovernance.Operation memory invalidOp = operationWithOneCallZeroSaltAndPredecessor(
            address(eventOnFallback),
            0,
            "00"
        );
        vm.expectRevert(bytes("Operation must be ready before execution"));
        governance.execute(invalidOp);
    }

    function test_RevertWhen_ExecutingOperationWithDifferentPredecessor() public {
        vm.startPrank(owner);
        // Executing one operation to get a valid executed predecessor
        IGovernance.Operation memory executedOp = operationWithOneCallZeroSaltAndPredecessor(
            address(eventOnFallback),
            0,
            "1122"
        );
        governance.scheduleTransparent(executedOp, 0);
        executeOpAndCheck(executedOp);

        // Schedule & execute operation with 0 predecessor
        IGovernance.Operation memory validOp = operationWithOneCallZeroSaltAndPredecessor(
            address(eventOnFallback),
            0,
            ""
        );
        governance.scheduleTransparent(validOp, 0);
        executeOpAndCheck(validOp);

        // Schedule operation with predecessor of `executedOp` operation
        IGovernance.Operation memory invalidOp = operationWithOneCallZeroSaltAndPredecessor(
            address(eventOnFallback),
            0,
            ""
        );
        invalidOp.predecessor = governance.hashOperation(executedOp);

        // Failed to execute operation that wasn't scheduled
        vm.expectRevert(bytes("Operation must be ready before execution"));
        governance.execute(invalidOp);
    }

    function test_RevertWhen_ExecutingOperationWithDifferentSalt() public {
        vm.startPrank(owner);
        IGovernance.Operation memory validOp = operationWithOneCallZeroSaltAndPredecessor(
            address(eventOnFallback),
            0,
            ""
        );
        governance.scheduleTransparent(validOp, 0);

        IGovernance.Operation memory invalidOp = operationWithOneCallZeroSaltAndPredecessor(
            address(eventOnFallback),
            0,
            ""
        );
        invalidOp.salt = Utils.randomBytes32("wrongSalt");
        vm.expectRevert(bytes("Operation must be ready before execution"));
        governance.execute(invalidOp);
    }

    function test_RevertWhen_ExecutingOperationWithNonExecutedPredecessor() public {
        vm.startPrank(owner);

        IGovernance.Operation memory invalidOp = operationWithOneCallZeroSaltAndPredecessor(
            address(eventOnFallback),
            0,
            "1122"
        );
        invalidOp.predecessor = Utils.randomBytes32("randomPredecessor");
        governance.scheduleTransparent(invalidOp, 0);
        vm.expectRevert(bytes("Predecessor operation not completed"));
        governance.execute(invalidOp);
    }

    function test_RevertWhen_ScheduleOperationOnceAndExecuteTwice() public {
        vm.startPrank(owner);

        IGovernance.Operation memory op = operationWithOneCallZeroSaltAndPredecessor(
            address(eventOnFallback),
            0,
            "1122"
        );
        governance.scheduleTransparent(op, 0);
        executeOpAndCheck(op);

        vm.expectRevert(bytes("Operation must be ready before execution"));
        governance.execute(op);
    }

    function test_RevertWhen_ExecutingOperationAfterCanceling() public {
        vm.startPrank(owner);

        IGovernance.Operation memory op = operationWithOneCallZeroSaltAndPredecessor(
            address(eventOnFallback),
            0,
            "1122"
        );
        governance.scheduleTransparent(op, 0);
        governance.cancel(governance.hashOperation(op));
        vm.expectRevert(bytes("Operation must be ready before execution"));
        governance.execute(op);
    }

    function test_ExecutingOperationAfterRescheduling() public {
        vm.startPrank(owner);

        IGovernance.Operation memory op = operationWithOneCallZeroSaltAndPredecessor(
            address(eventOnFallback),
            0,
            "1122"
        );
        governance.scheduleTransparent(op, 0);
        governance.cancel(governance.hashOperation(op));
        governance.scheduleTransparent(op, 0);
        executeOpAndCheck(op);
    }

    function test_RevertWhen_ExecutingOperationTwice() public {
        vm.startPrank(owner);

        IGovernance.Operation memory op = operationWithOneCallZeroSaltAndPredecessor(
            address(eventOnFallback),
            0,
            "1122"
        );
        governance.scheduleTransparent(op, 0);
        executeOpAndCheck(op);
        vm.expectRevert(bytes("Operation with this proposal id already exists"));
        governance.scheduleTransparent(op, 0);
    }
}
