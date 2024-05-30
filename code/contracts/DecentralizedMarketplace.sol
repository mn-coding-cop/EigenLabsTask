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

contract Marketplace is ReentrancyGuard {
    struct Item {
        string name;
        string description;
        uint256 price;
        address payable owner;
        bool isSold;
    }

    struct Transaction {
        uint256 itemId;
        uint256 price;
        address buyer;
        uint256 timestamp;
    }

    // Mappings for user registration
    mapping(address => string) private addressToUsername;
    mapping(string => bool) private usernameExists;

    mapping(uint256 => Item) private items;
    mapping(address => Transaction[]) public purchaseHistory;
    mapping(address => Transaction[]) public salesHistory;
    mapping(address => uint256) public userBalances;

    event UserRegistered(address user, string username);
    event ItemListed(uint256 itemId, string name, uint256 price, address owner);
    event ItemPurchased(
        uint256 itemId,
        address buyer,
        address seller,
        uint256 price
    );
    event FundsWithdrawn(address user, uint256 amount);
    event ItemRelisted(uint256 itemId, uint256 price, address owner);
    event ItemPriceUpdated(uint256 itemId, uint256 newPrice);

    uint256 private itemIdCounter;

    /**
     * @notice Registers a user with a unique username.
     * @param _username The username chosen by the user.
     */
    function registerUser(string memory _username) external {
        require(bytes(_username).length > 0, "Username cannot be empty");
        require(!usernameExists[_username], "Username is already taken");
        require(
            bytes(addressToUsername[msg.sender]).length == 0,
            "User already registered"
        );

        // Register the user
        addressToUsername[msg.sender] = _username;
        usernameExists[_username] = true;

        // Emit the registration event
        emit UserRegistered(msg.sender, _username);
    }

    /**
     * @notice Returns the username associated with an address.
     * @param user The address of the user.
     * @return The username associated with the user.
     * @dev Throws an error if the user is not registered.
     */
    function getUsernameByAddress(
        address user
    ) external view returns (string memory) {
        require(
            bytes(addressToUsername[user]).length > 0,
            "User not registered"
        );
        return addressToUsername[user];
    }

    /**
     * @notice Checks if a username is already taken.
     * @param username The username to check.
     * @return True if the username is taken, false otherwise.
     */
    function isUsernameTaken(
        string calldata username
    ) external view returns (bool) {
        return usernameExists[username];
    }

    /**
     * @notice Lists an item for sale.
     * @param _name The name of the item.
     * @param _description The description of the item.
     * @param _price The price of the item in Ether.
     */
    function listItem(
        string memory _name,
        string memory _description,
        uint256 _price
    ) public {
        require(
            bytes(addressToUsername[msg.sender]).length > 0,
            "User not registered"
        );
        require(_price > 0, "Price must be greater than zero");

        uint256 newItemId = itemIdCounter;
        items[newItemId] = Item({
            name: _name,
            description: _description,
            price: _price,
            owner: payable(msg.sender),
            isSold: false
        });

        itemIdCounter++;
        emit ItemListed(newItemId, _name, _price, msg.sender);
    }

    /**
     * @notice Updates the price of a listed item.
     * @param _itemId The ID of the item.
     * @param _newPrice The new price of the item.
     */
    function updateItemPrice(uint256 _itemId, uint256 _newPrice) public {
        Item storage item = items[_itemId];
        require(!item.isSold, "Item already sold");
        require(
            item.owner == msg.sender,
            "Only the owner can update the price"
        );
        require(_newPrice > 0, "Price must be greater than zero");

        item.price = _newPrice;

        emit ItemPriceUpdated(_itemId, _newPrice);
    }

    /**
     * @notice Relists a sold item for sale.
     * @param _itemId The ID of the item.
     * @param _price The new price of the item.
     */
    function relistItem(uint256 _itemId, uint256 _price) public {
        Item storage item = items[_itemId];
        require(item.isSold, "Item is not sold");
        require(item.owner == msg.sender, "Only the owner can relist the item");
        require(_price > 0, "Price must be greater than zero");

        item.price = _price;
        item.isSold = false;

        emit ItemRelisted(_itemId, _price, msg.sender);
    }

    /**
     * @notice Purchases an available item.
     * @param _itemId The ID of the item to be purchased.
     */
    function purchaseItem(uint256 _itemId) public payable nonReentrant {
        Item storage item = items[_itemId];
        require(!item.isSold, "Item already sold");
        require(msg.value == item.price, "Incorrect Ether value sent");

        userBalances[item.owner] += msg.value;

        purchaseHistory[msg.sender].push(
            Transaction({
                itemId: _itemId,
                price: msg.value,
                buyer: msg.sender,
                timestamp: block.timestamp
            })
        );

        salesHistory[item.owner].push(
            Transaction({
                itemId: _itemId,
                price: msg.value,
                buyer: msg.sender,
                timestamp: block.timestamp
            })
        );

        address previousOwner = item.owner;
        item.owner = payable(msg.sender);
        item.isSold = true;

        emit ItemPurchased(_itemId, msg.sender, previousOwner, msg.value);
    }

    /**
     * @notice Retrieves details of an item.
     * @param _itemId The ID of the item.
     * @return name The name of the item.
     * @return description The description of the item.
     * @return price The price of the item.
     * @return owner The address of the item's owner.
     * @return isSold The sale status of the item.
     */
    function getItem(
        uint256 _itemId
    )
        public
        view
        returns (
            string memory name,
            string memory description,
            uint256 price,
            address owner,
            bool isSold
        )
    {
        Item memory item = items[_itemId];
        return (
            item.name,
            item.description,
            item.price,
            item.owner,
            item.isSold
        );
    }

    /**
     * @notice Withdraws funds from sales.
     */
    function withdrawFunds() public nonReentrant {
        uint256 balance = userBalances[msg.sender];
        require(balance > 0, "Insufficient funds to withdraw");

        userBalances[msg.sender] -= balance;
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "Failed to withdraw funds");

        emit FundsWithdrawn(msg.sender, balance);
    }
}
