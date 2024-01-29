// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {AdminTest} from "./_Admin_Shared.t.sol";
import {ERROR_ONLY_STATE_TRANSITION_MANAGER} from "../ZkSyncStateTransitionBase/_ZkSyncStateTransitionBase_Shared.t.sol";

import {FeeParams, PubdataPricingMode} from "solpp/state-transition/chain-deps/ZkSyncStateTransitionStorage.sol";

contract ChangeFeeParamsTest is AdminTest {
    event NewFeeParams(FeeParams oldFeeParams, FeeParams newFeeParams);

    function setUp() public override {
        super.setUp();

        adminFacetWrapper.util_setFeeParams(
            FeeParams({
                pubdataPricingMode: PubdataPricingMode.Rollup,
                batchOverheadL1Gas: 1_000_000,
                maxPubdataPerBatch: 110_000,
                maxL2GasPerBatch: 80_000_000,
                priorityTxMaxPubdata: 99_000,
                minimalL2GasPrice: 250_000_000
            })
        );
    }

    function test_revertWhen_calledByNonStateTransitionManager() public {
        address nonStateTransitionManager = makeAddr("nonStateTransitionManager");
        FeeParams memory newFeeParams = FeeParams({
            pubdataPricingMode: PubdataPricingMode.Rollup,
            batchOverheadL1Gas: 1_000_000,
            maxPubdataPerBatch: 110_000,
            maxL2GasPerBatch: 80_000_000,
            priorityTxMaxPubdata: 99_000,
            minimalL2GasPrice: 250_000_000
        });

        vm.startPrank(nonStateTransitionManager);
        vm.expectRevert(ERROR_ONLY_STATE_TRANSITION_MANAGER);

        adminFacet.changeFeeParams(newFeeParams);
    }

    function test_revertWhen_newMaxPubdataPerBatchIsLessThanMaxPubdataPerTransaction() public {
        address stateTransitionManager = adminFacetWrapper.util_getStateTransitionManager();
        uint32 priorityTxMaxPubdata = 88_000;
        uint32 maxPubdataPerBatch = priorityTxMaxPubdata - 1;
        FeeParams memory newFeeParams = FeeParams({
            pubdataPricingMode: PubdataPricingMode.Rollup,
            batchOverheadL1Gas: 1_000_000,
            maxPubdataPerBatch: maxPubdataPerBatch,
            maxL2GasPerBatch: 80_000_000,
            priorityTxMaxPubdata: priorityTxMaxPubdata,
            minimalL2GasPrice: 250_000_000
        });

        vm.expectRevert(bytes.concat("n6"));

        vm.startPrank(stateTransitionManager);
        adminFacet.changeFeeParams(newFeeParams);
    }

    function test_successfulChange() public {
        address stateTransitionManager = adminFacetWrapper.util_getStateTransitionManager();
        FeeParams memory oldFeeParams = adminFacetWrapper.util_getFeeParams();
        FeeParams memory newFeeParams = FeeParams({
            pubdataPricingMode: PubdataPricingMode.Rollup,
            batchOverheadL1Gas: 2_000_000,
            maxPubdataPerBatch: 220_000,
            maxL2GasPerBatch: 100_000_000,
            priorityTxMaxPubdata: 100_000,
            minimalL2GasPrice: 450_000_000
        });

        vm.expectEmit(true, true, true, true, address(adminFacet));
        emit NewFeeParams(oldFeeParams, newFeeParams);

        vm.startPrank(stateTransitionManager);
        adminFacet.changeFeeParams(newFeeParams);

        bytes32 newFeeParamsHash = keccak256(abi.encode(newFeeParams));
        bytes32 currentFeeParamsHash = keccak256(abi.encode(adminFacetWrapper.util_getFeeParams()));
        require(currentFeeParamsHash == newFeeParamsHash, "Fee params were not changed correctly");
    }
}
