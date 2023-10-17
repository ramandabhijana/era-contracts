// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IStateTransitionBase} from "./IStateTransitionBase.sol";
import {Diamond} from "../../common/libraries/Diamond.sol";

interface IStateTransitionAdmin is IStateTransitionBase {
    function setPendingGovernor(address _newPendingGovernor) external;

    function acceptGovernor() external;

    function executeUpgrade(Diamond.DiamondCutData calldata _diamondCut) external;

    function freezeDiamond() external;

    function unfreezeDiamond() external;

    /// @notice pendingGovernor is changed
    /// @dev Also emitted when new governor is accepted and in this case, `newPendingGovernor` would be zero address
    event NewPendingGovernor(address indexed oldPendingGovernor, address indexed newPendingGovernor);

    /// @notice Governor changed
    event NewGovernor(address indexed oldGovernor, address indexed newGovernor);

    /// @notice pendingAdmin is changed
    /// @dev Also emitted when new admin is accepted and in this case, `newPendingAdmin` would be zero address
    event NewPendingAdmin(address indexed oldPendingAdmin, address indexed newPendingAdmin);

    /// @notice Admin changed
    event NewAdmin(address indexed oldAdmin, address indexed newAdmin);

    /// @notice Emitted when an upgrade is executed.
    event ExecuteUpgrade(Diamond.DiamondCutData diamondCut);

    /// @notice Emitted when the contract is frozen.
    event Freeze();

    /// @notice Emitted when the contract is unfrozen.
    event Unfreeze();
}
