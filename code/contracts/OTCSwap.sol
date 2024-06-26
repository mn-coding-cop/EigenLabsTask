// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// OpenZeppelin Contracts (last updated v4.9.0) (security/ReentrancyGuard.sol)

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}

// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)
/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

contract OTCSwap is ReentrancyGuard {
    struct Swap {
        address initiator;
        address counterparty;
        address initiatorToken;
        address counterpartyToken;
        uint256 initiatorAmount;
        uint256 counterpartyAmount;
        uint256 expiry;
        bool exists;
    }

    mapping(bytes32 => Swap) public swapDetails;

    /**
     * @dev Emitted when a new swap is created.
     * @param swapId The unique identifier for the swap.
     * @param initiator The address of the swap initiator.
     * @param counterparty The address of the swap counterparty.
     * @param initiatorToken The address of the initiator's token.
     * @param counterpartyToken The address of the counterparty's token.
     * @param initiatorAmount The amount of the initiator's token.
     * @param counterpartyAmount The amount of the counterparty's token.
     * @param expiry The expiration time of the swap.
     */
    event swapCreated(
        bytes32 indexed swapId,
        address indexed initiator,
        address indexed counterparty,
        address initiatorToken,
        address counterpartyToken,
        uint256 initiatorAmount,
        uint256 counterpartyAmount,
        uint256 expiry
    );

    /**
     * @dev Emitted when a swap is successfully executed.
     * @param swapId The unique identifier for the swap.
     */
    event swapExecuted(bytes32 indexed swapId);

    /**
     * @dev Emitted when a swap is cancelled.
     * @param swapId The unique identifier for the swap.
     */
    event swapCancelled(bytes32 indexed swapId);

    /**
     * @notice Creates a new atomic swap.
     * @param _counterparty The address of the counterparty.
     * @param _initiatorToken The address of the initiator's token.
     * @param _counterpartyToken The address of the counterparty's token.
     * @param _initiatorAmount The amount of the initiator's token.
     * @param _counterpartyAmount The amount of the counterparty's token.
     * @param _expiry The expiration time of the swap.
     * @return swapId The unique identifier for the created swap.
     * @dev The swap ID is generated using a hash of the swap parameters.
     * @dev Emits a {swapCreated} event.
     * @dev Reverts if the expiry time is not in the future or if the swap already exists.
     */
    function createSwap(
        address _counterparty,
        address _initiatorToken,
        address _counterpartyToken,
        uint256 _initiatorAmount,
        uint256 _counterpartyAmount,
        uint256 _expiry
    ) external returns (bytes32) {
        require(
            _counterparty != address(0),
            "Counterparty address must not be zero"
        );
        require(
            _initiatorToken != address(0) && _counterpartyToken != address(0),
            "Initiator or Counterparty token address must not be zero"
        );
        require(
            _initiatorAmount > 0 && _counterpartyAmount > 0,
            "Amounts must be greater than zero"
        );
        require(_expiry > block.timestamp, "Expiry must be in the future");

        bytes32 swapId = keccak256(
            abi.encodePacked(
                msg.sender,
                _counterparty,
                _initiatorToken,
                _counterpartyToken,
                _initiatorAmount,
                _counterpartyAmount,
                _expiry
            )
        );
        require(!swapDetails[swapId].exists, "Swap already exists");

        swapDetails[swapId] = Swap({
            initiator: msg.sender,
            counterparty: _counterparty,
            initiatorToken: _initiatorToken,
            counterpartyToken: _counterpartyToken,
            initiatorAmount: _initiatorAmount,
            counterpartyAmount: _counterpartyAmount,
            expiry: _expiry,
            exists: true
        });

        emit swapCreated(
            swapId,
            msg.sender,
            _counterparty,
            _initiatorToken,
            _counterpartyToken,
            _initiatorAmount,
            _counterpartyAmount,
            _expiry
        );

        return swapId;
    }

    /**
     * @notice Executes an atomic swap.
     * @param _swapId The unique identifier for the swap.
     * @dev Transfers the tokens between the initiator and counterparty.
     * @dev Only the specified counterparty can execute the swap.
     * @dev Reverts if the swap does not exist or has expired.
     * @dev Reverts if ReentrancyGuard is triggered.
     * @dev Emits a {swapExecuted} event.
     */
    function executeSwap(bytes32 _swapId) external nonReentrant {
        Swap memory swap = swapDetails[_swapId];

        require(swap.exists, "Swap does not exist");
        require(block.timestamp <= swap.expiry, "Swap has expired");
        require(
            msg.sender == swap.counterparty,
            "Only the specified counterparty can execute this swap"
        );
        bool successInitiator = IERC20(swap.initiatorToken).transferFrom(
            swap.initiator,
            swap.counterparty,
            swap.initiatorAmount
        );

        require(successInitiator, "Token transfer from initiator failed");

        bool successCounterparty = IERC20(swap.counterpartyToken).transferFrom(
            swap.counterparty,
            swap.initiator,
            swap.counterpartyAmount
        );

        require(successCounterparty, "Token transfer from counterparty failed");

        delete swapDetails[_swapId];

        emit swapExecuted(_swapId);
    }

    /**
     * @notice Cancels an atomic swap.
     * @param _swapId The unique identifier for the swap.
     * @dev Only the initiator can cancel the swap.
     * @dev Reverts if the swap does not exist.
     * @dev Emits a {swapCancelled} event.
     */
    function cancelSwap(bytes32 _swapId) external {
        Swap memory swap = swapDetails[_swapId];
        require(swap.exists, "Swap does not exist");
        require(
            msg.sender == swap.initiator,
            "Only the initiator can cancel this swap"
        );

        delete swapDetails[_swapId];

        emit swapCancelled(_swapId);
    }

    /**
     * @notice Gets the swap details for an existing swap.
     * @param _swapId The unique identifier for the swap.
     * @return swap The details of the swap.
     */
    function getSwap(bytes32 _swapId) external view returns (Swap memory) {
        return swapDetails[_swapId];
    }

    /**
     *
     * @notice Gets the swap ID for already created swaps.
     * @param _initiator   The address of the initiator.
     * @param _counterparty The address of the counterparty.
     * @param _initiatorToken The address of the initiator's token.
     * @param _counterpartyToken The address of the counterparty's token.
     * @param _initiatorAmount The amount of the initiator's token.
     * @param _counterpartyAmount The amount of the counterparty's token.
     * @param _expiry The expiration time of the swap.
     * @return swapId The unique identifier for the existing swap or 0 if it does not exist.
     * @dev The swap ID is generated using a hash of the swap parameters.
     */
    function getSwapsId(
        address _initiator,
        address _counterparty,
        address _initiatorToken,
        address _counterpartyToken,
        uint256 _initiatorAmount,
        uint256 _counterpartyAmount,
        uint256 _expiry
    ) external view returns (bytes32) {
        bytes32 swapId = keccak256(
            abi.encodePacked(
                _initiator,
                _counterparty,
                _initiatorToken,
                _counterpartyToken,
                _initiatorAmount,
                _counterpartyAmount,
                _expiry
            )
        );
        if (swapDetails[swapId].counterparty != address(0)) {
            return swapId;
        } else {
            return bytes32(0);
        }
    }

    /**
     * @notice Generate generic swap ID
     * @param _initiator   The address of the initiator.
     * @param _counterparty The address of the counterparty.
     * @param _initiatorToken The address of the initiator's token.
     * @param _counterpartyToken The address of the counterparty's token.
     * @param _initiatorAmount The amount of the initiator's token.
     * @param _counterpartyAmount The amount of the counterparty's token.
     * @param _expiry The expiration time of the swap.
     * @return swapId genric for a swap
     * @dev The swap ID is generated using a hash of the swap parameters.
     */
    function generateSwapsId(
        address _initiator,
        address _counterparty,
        address _initiatorToken,
        address _counterpartyToken,
        uint256 _initiatorAmount,
        uint256 _counterpartyAmount,
        uint256 _expiry
    ) external pure returns (bytes32) {
        bytes32 swapId = keccak256(
            abi.encodePacked(
                _initiator,
                _counterparty,
                _initiatorToken,
                _counterpartyToken,
                _initiatorAmount,
                _counterpartyAmount,
                _expiry
            )
        );
        return swapId;
    }
}
