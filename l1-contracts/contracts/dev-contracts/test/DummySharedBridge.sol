// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {L2TransactionRequestTwoBridgesInner} from "../../bridgehub/IBridgehub.sol";
import {TWO_BRIDGES_MAGIC_VALUE} from "../../common/Config.sol";
import {IL1NativeTokenVault} from "../../bridge/L1NativeTokenVault.sol";
import {L2_NATIVE_TOKEN_VAULT_ADDRESS} from "../../common/L2ContractAddresses.sol";

contract DummySharedBridge {
    IL1NativeTokenVault public nativeTokenVault;

    event BridgehubDepositBaseTokenInitiated(
        uint256 indexed chainId,
        address indexed from,
        address l1Token,
        uint256 amount
    );

    bytes32 dummyL2DepositTxHash;

    /// @dev Maps token balances for each chain to prevent unauthorized spending across hyperchains.
    /// This serves as a security measure until hyperbridging is implemented.
    mapping(uint256 chainId => mapping(address l1Token => uint256 balance)) internal chainBalance;

    /// @dev Indicates whether the hyperbridging is enabled for a given chain.
    mapping(uint256 chainId => bool enabled) internal hyperbridgingEnabled;

    address l1ReceiverReturnInFinalizeWithdrawal;
    address l1TokenReturnInFinalizeWithdrawal;
    uint256 amountReturnInFinalizeWithdrawal;

    /// @dev A mapping assetId => assetHandlerAddress
    /// @dev Tracks the address of Asset Handler contracts, where bridged funds are locked for each asset
    /// @dev P.S. this liquidity was locked directly in SharedBridge before
    mapping(bytes32 assetId => address assetHandlerAddress) public assetHandlerAddress;

    constructor(bytes32 _dummyL2DepositTxHash) {
        dummyL2DepositTxHash = _dummyL2DepositTxHash;
    }

    function setDataToBeReturnedInFinalizeWithdrawal(address _l1Receiver, address _l1Token, uint256 _amount) external {
        l1ReceiverReturnInFinalizeWithdrawal = _l1Receiver;
        l1TokenReturnInFinalizeWithdrawal = _l1Token;
        amountReturnInFinalizeWithdrawal = _amount;
    }

    function depositLegacyErc20Bridge(
        address, //_msgSender,
        address, //_l2Receiver,
        address, //_l1Token,
        uint256, //_amount,
        uint256, //_l2TxGasLimit,
        uint256, //_l2TxGasPerPubdataByte,
        address //_refundRecipient
    ) external payable returns (bytes32 txHash) {
        txHash = dummyL2DepositTxHash;
    }

    function claimFailedDepositLegacyErc20Bridge(
        address, //_depositSender,
        address, //_l1Token,
        uint256, //_amount,
        bytes32, //_l2TxHash,
        uint256, //_l2BatchNumber,
        uint256, //_l2MessageIndex,
        uint16, //_l2TxNumberInBatch,
        bytes32[] calldata // _merkleProof
    ) external {}

    function finalizeWithdrawalLegacyErc20Bridge(
        uint256, //_l2BatchNumber,
        uint256, //_l2MessageIndex,
        uint16, //_l2TxNumberInBatch,
        bytes calldata, //_message,
        bytes32[] calldata //_merkleProof
    ) external view returns (address l1Receiver, address l1Token, uint256 amount) {
        l1Receiver = l1ReceiverReturnInFinalizeWithdrawal;
        l1Token = l1TokenReturnInFinalizeWithdrawal;
        amount = amountReturnInFinalizeWithdrawal;
    }

    event Debugger(uint256);

    function bridgehubDepositBaseToken(
        uint256 _chainId,
        address _prevMsgSender,
        address _l1Token,
        uint256 _amount
    ) external payable {
        if (_l1Token == address(1)) {
            require(msg.value == _amount, "L1AssetRouter: msg.value not equal to amount");
        } else {
            // The Bridgehub also checks this, but we want to be sure
            require(msg.value == 0, "ShB m.v > 0 b d.it");
            uint256 amount = _depositFunds(_prevMsgSender, IERC20(_l1Token), _amount); // note if _prevMsgSender is this contract, this will return 0. This does not happen.
            require(amount == _amount, "5T"); // The token has non-standard transfer logic
        }

        if (!hyperbridgingEnabled[_chainId]) {
            chainBalance[_chainId][_l1Token] += _amount;
        }

        emit Debugger(5);
        // Note that we don't save the deposited amount, as this is for the base token, which gets sent to the refundRecipient if the tx fails
        emit BridgehubDepositBaseTokenInitiated(_chainId, _prevMsgSender, _l1Token, _amount);
    }

    function _depositFunds(address _from, IERC20 _token, uint256 _amount) internal returns (uint256) {
        uint256 balanceBefore = _token.balanceOf(address(this));
        _token.transferFrom(_from, address(this), _amount);
        uint256 balanceAfter = _token.balanceOf(address(this));

        return balanceAfter - balanceBefore;
    }

    function bridgehubDeposit(
        uint256, //_chainId,
        address, //_prevMsgSender,
        uint256, // l2Value, needed for Weth deposits in the future
        bytes calldata //_data
    ) external payable returns (L2TransactionRequestTwoBridgesInner memory request) {
        // Request the finalization of the deposit on the L2 side
        bytes memory l2TxCalldata = bytes("0xabcd123");
        bytes32 txDataHash = bytes32("0x1212121212abf");

        request = L2TransactionRequestTwoBridgesInner({
            magicValue: TWO_BRIDGES_MAGIC_VALUE,
            l2Contract: address(0xCAFE),
            l2Calldata: l2TxCalldata,
            factoryDeps: new bytes[](0),
            txDataHash: txDataHash
        });
    }

    function bridgehubConfirmL2Transaction(uint256 _chainId, bytes32 _txDataHash, bytes32 _txHash) external {}

    /// @dev Sets the L1ERC20Bridge contract address. Should be called only once.
    function setNativeTokenVault(IL1NativeTokenVault _nativeTokenVault) external {
        require(address(nativeTokenVault) == address(0), "ShB: legacy bridge already set");
        require(address(_nativeTokenVault) != address(0), "ShB: legacy bridge 0");
        nativeTokenVault = _nativeTokenVault;
    }

    /// @dev Used to set the assedAddress for a given assetId.
    function setAssetHandlerAddressInitial(bytes32 _additionalData, address _assetHandlerAddress) external {
        address sender = msg.sender == address(nativeTokenVault) ? L2_NATIVE_TOKEN_VAULT_ADDRESS : msg.sender;
        bytes32 assetId = keccak256(abi.encode(uint256(block.chainid), sender, _additionalData));
        assetHandlerAddress[assetId] = _assetHandlerAddress;
        // assetDeploymentTracker[assetId] = sender;
        // emit AssetHandlerRegisteredInitial(assetId, _assetHandlerAddress, _additionalData, sender);
    }

    // add this to be excluded from coverage report
    function test() internal {}
}
