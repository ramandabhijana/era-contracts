// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {L2TransactionRequestTwoBridgesInner} from "../../bridgehub/IBridgehub.sol";

struct ConfirmL2TxStatus {
    uint256 batchNumber;
    uint256 messageIndex;
    uint16 numberInBatch;
    bytes32[] merkleProof;
    bool succeeded;
}

/// @title L1 Bridge contract interface
/// @author Matter Labs
/// @custom:security-contact security@matterlabs.dev
interface IL1Bridge {
    event DepositInitiatedSharedBridge(
        uint256 indexed chainId,
        bytes32 indexed l2DepositTxHash,
        address indexed from,
        address to,
        address l1Token,
        uint256 amount
    );

    event BridgehubDepositInitiatedSharedBridge(
        uint256 indexed chainId,
        bytes32 indexed txDataHash,
        address indexed from,
        address to,
        address l1Token,
        uint256 amount
    );

    event BridgehubDepositFinalized(
        uint256 indexed chainId,
        bytes32 indexed txDataHash,
        bytes32 indexed l2DepositTxHash
    );

    event WithdrawalFinalizedSharedBridge(
        uint256 indexed chainId,
        address indexed to,
        address indexed l1Token,
        uint256 amount
    );

    event ClaimedFailedDepositSharedBridge(
        uint256 indexed chainId,
        address indexed to,
        address indexed l1Token,
        uint256 amount
    );

    function isWithdrawalFinalizedShared(
        uint256 chainId,
        uint256 _l2BatchNumber,
        uint256 _l2MessageIndex
    ) external view returns (bool);

    function deposit(
        uint256 _chainId,
        address _l2Receiver,
        address _l1Token,
        uint256 _mintValue,
        uint256 _amount,
        uint256 _l2TxGasLimit,
        uint256 _l2TxGasPerPubdataByte,
        address _refundRecipient
    ) external payable returns (bytes32 txHash);

    function claimFailedDeposit(
        uint256 _chainId,
        address _depositSender,
        address _l1Token,
        uint256 _amount,
        bytes32 _l2TxHash,
        uint256 _l2BatchNumber,
        uint256 _l2MessageIndex,
        uint16 _l2TxNumberInBatch,
        bytes32[] calldata _merkleProof
    ) external;

    function finalizeWithdrawal(
        uint256 _chainId,
        uint256 _l2BatchNumber,
        uint256 _l2MessageIndex,
        uint16 _l2TxNumberInBatch,
        bytes calldata _message,
        bytes32[] calldata _merkleProof
    ) external;

    function bridgehubDeposit(
        uint256 _chainId,
        address _prevMsgSender,
        bytes calldata _data
    )
        external
        payable
        returns (
            // which is abi encoded :
            // address _l1Token,
            // uint256 _amount,
            // address _l2Receiver
            L2TransactionRequestTwoBridgesInner memory request
        );

    function bridgehubDepositBaseToken(
        uint256 _chainId,
        address _prevMsgSender,
        address _l1Token,
        uint256 _amount
    ) external payable;

    function bridgehubConfirmL2Transaction(uint256 chainId, bytes32 txDataHash, bytes32 txHash) external;

    function l2TokenAddress(address _l1Token) external view returns (address);

    function l2Bridge() external view returns (address);
}
