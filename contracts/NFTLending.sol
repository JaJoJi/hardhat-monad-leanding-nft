// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract NFTLending {
    // --------------------------------------
    // Enums & Structs
    // --------------------------------------
    enum Status { Idle, Borrowed }
    enum EscrowStatus { Pending, Completed, Cancelled, Dispute, OwnerWins, BorrowerWins }

    struct NFTItem {
        string name;
        bool isPrivate;
        Status status;
        uint256 value;           
        uint256 interestPerDay; 
        uint256 minDays;
        uint256 maxDays;
        address borrower;
        uint256 escrowId;
        string imageUrl;
        address owner;
    }

    struct Escrow {
        uint256 itemId;
        address borrower;
        uint256 startTime;
        uint256 durationDays;
        uint256 amount;          
        EscrowStatus status;
    }

    // --------------------------------------
    // Storage
    // --------------------------------------
    mapping(uint256 => NFTItem) public items;
    mapping(uint256 => Escrow) public escrows;
    mapping(address => uint256[]) public ownerItems;

    uint256 public nextItemId;
    uint256 public nextEscrowId;

    address public admin;

    // --------------------------------------
    // Events
    // --------------------------------------
    event ItemCreated(uint256 indexed itemId, address indexed owner);
    event ItemUpdated(uint256 indexed itemId);
    event ItemBorrowed(uint256 indexed itemId, address indexed borrower, uint256 escrowId);
    event EscrowResolved(uint256 indexed escrowId, EscrowStatus status);

    // --------------------------------------
    // Modifiers
    // --------------------------------------
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier onlyOwner(uint256 _itemId) {
        require(items[_itemId].owner == msg.sender, "Not owner");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    // --------------------------------------
    // CRUD Functions
    // --------------------------------------
    function createItem(
        string memory _name,
        bool _isPrivate,
        uint256 _value,
        uint256 _interestPerDay,
        uint256 _minDays,
        uint256 _maxDays,
        string memory _imageUrl
    ) external {
        uint256 itemId = nextItemId++;

        items[itemId] = NFTItem({
            name: _name,
            isPrivate: _isPrivate,
            status: Status.Idle,
            value: _value,
            interestPerDay: _interestPerDay,
            minDays: _minDays,
            maxDays: _maxDays,
            borrower: address(0),
            escrowId: 0,
            imageUrl: _imageUrl,
            owner: msg.sender
        });

        ownerItems[msg.sender].push(itemId);

        emit ItemCreated(itemId, msg.sender);
    }

    function updateItem(
        uint256 _itemId,
        string memory _name,
        bool _isPrivate,
        uint256 _value,
        uint256 _interestPerDay,
        uint256 _minDays,
        uint256 _maxDays,
        string memory _imageUrl
    ) external onlyOwner(_itemId) {
        NFTItem storage item = items[_itemId];
        require(item.status == Status.Idle, "Cannot update borrowed item");

        item.name = _name;
        item.isPrivate = _isPrivate;
        item.value = _value;
        item.interestPerDay = _interestPerDay;
        item.minDays = _minDays;
        item.maxDays = _maxDays;
        item.imageUrl = _imageUrl;

        emit ItemUpdated(_itemId);
    }

    // --------------------------------------
    // Borrowing
    // --------------------------------------
    function borrowItem(uint256 _itemId, uint256 _days) external payable {
        NFTItem storage item = items[_itemId];
        require(item.status == Status.Idle, "Item not available");
        require(msg.sender != item.owner, "Owner cannot borrow");
        require(!item.isPrivate, "Item is private");
        require(_days >= item.minDays && _days <= item.maxDays, "Invalid duration");

        uint256 totalAmount = item.value + (item.interestPerDay * _days);
        require(msg.value == totalAmount, "Incorrect escrow amount");

        uint256 escrowId = nextEscrowId++;
        escrows[escrowId] = Escrow({
            itemId: _itemId,
            borrower: msg.sender,
            startTime: block.timestamp,
            durationDays: _days,
            amount: msg.value,
            status: EscrowStatus.Pending
        });

        item.status = Status.Borrowed;
        item.borrower = msg.sender;
        item.escrowId = escrowId;

        emit ItemBorrowed(_itemId, msg.sender, escrowId);
    }

    // --------------------------------------
    // Admin escrow resolution
    // --------------------------------------
    function resolveEscrow(uint256 _escrowId, EscrowStatus result) external onlyAdmin {
        Escrow storage escrow = escrows[_escrowId];
        NFTItem storage item = items[escrow.itemId];

        require(
            escrow.status == EscrowStatus.Pending || escrow.status == EscrowStatus.Dispute,
            "Cannot resolve"
        );

        if(result == EscrowStatus.Completed || result == EscrowStatus.OwnerWins) {
            payable(item.owner).transfer(escrow.amount);
        } else if(result == EscrowStatus.BorrowerWins) {
            payable(escrow.borrower).transfer(escrow.amount);
        } else if(result == EscrowStatus.Cancelled) {
            payable(escrow.borrower).transfer(escrow.amount);
        }

        escrow.status = result;
        item.status = Status.Idle;
        item.borrower = address(0);
        item.escrowId = 0;

        emit EscrowResolved(_escrowId, result);
    }

    // --------------------------------------
    // View helpers
    // --------------------------------------
    function ownerOfItem(uint256 _itemId) external view returns(address) {
        return items[_itemId].owner;
    }

    function getOwnerItems(address _owner) external view returns(uint256[] memory) {
        return ownerItems[_owner];
    }

    function getEscrowStatus(uint256 _escrowId) external view returns(EscrowStatus) {
        return escrows[_escrowId].status;
    }

    function getItemName(uint256 _itemId) external view returns (string memory) {
        return items[_itemId].name;
    }

    function getItemEscrowId(uint256 _itemId) external view returns(uint256) {
        return items[_itemId].escrowId;
    }

    function getItemStatus(uint256 _itemId) external view returns(Status) {
        return items[_itemId].status;
    }

    // --------------------------------------
    // Additional view helpers
    // --------------------------------------

    /// @notice Return items currently borrowed by a user
    function getBorrowerItems(address _borrower) external view returns(uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < nextItemId; i++) {
            if (items[i].borrower == _borrower && items[i].status == Status.Borrowed) {
                count++;
            }
        }

        uint256[] memory borrowed = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < nextItemId; i++) {
            if (items[i].borrower == _borrower && items[i].status == Status.Borrowed) {
                borrowed[index] = i;
                index++;
            }
        }
        return borrowed;
    }

    /// @notice Return items available for borrowing (public and idle)
    function getAvailableItems() external view returns(uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < nextItemId; i++) {
            if (!items[i].isPrivate && items[i].status == Status.Idle) {
                count++;
            }
        }

        uint256[] memory available = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < nextItemId; i++) {
            if (!items[i].isPrivate && items[i].status == Status.Idle) {
                available[index] = i;
                index++;
            }
        }
        return available;
    }
}
