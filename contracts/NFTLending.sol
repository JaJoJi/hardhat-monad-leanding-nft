// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract NFTLending {
    // --------------------------------------
    // Status codes (replacing enums to save gas)
    // --------------------------------------
    uint8 constant STATUS_IDLE = 0;
    uint8 constant STATUS_BORROWED = 1;

    uint8 constant ESCROW_PENDING = 0;
    uint8 constant ESCROW_COMPLETED = 1;
    uint8 constant ESCROW_CANCELLED = 2;
    uint8 constant ESCROW_DISPUTE = 3;
    uint8 constant ESCROW_OWNER_WINS = 4;
    uint8 constant ESCROW_BORROWER_WINS = 5;

    // --------------------------------------
    // Custom errors
    // --------------------------------------
    error OnlyAdmin();
    error NotOwner();
    error CannotUpdateBorrowed();
    error ItemNotAvailable();
    error OwnerCannotBorrow();
    error ItemIsPrivate();
    error InvalidDuration();
    error IncorrectEscrowAmount();
    error CannotResolveEscrow();

    // --------------------------------------
    // Structs optimized for storage
    // --------------------------------------
    struct NFTItem {
        bytes32 name;       // แทน string
        uint8 flags;        // bit0 = status, bit1 = isPrivate
        uint256 value;
        uint256 interestPerDay;
        uint256 minDays;
        uint256 maxDays;
        address borrower;
        uint256 escrowId;
        bytes32 imageHash;  // แทน string imageUrl
        address owner;
    }

    struct Escrow {
        uint256 itemId;
        address borrower;
        uint256 startTime;
        uint256 durationDays;
        uint256 amount;
        uint8 status;      // uint8 แทน EscrowStatus
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
    event EscrowResolved(uint256 indexed escrowId, uint8 status);

    // --------------------------------------
    // Modifiers
    // --------------------------------------
    modifier onlyAdmin() {
        if(msg.sender != admin) revert OnlyAdmin();
        _;
    }

    modifier onlyOwner(uint256 _itemId) {
        if(items[_itemId].owner != msg.sender) revert NotOwner();
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    // --------------------------------------
    // Internal helpers for bit-packed flags
    // --------------------------------------
    function _getStatus(uint8 flags) internal pure returns(uint8) {
        return flags & 0x1; // bit0
    }

    function _getIsPrivate(uint8 flags) internal pure returns(bool) {
        return (flags & 0x2) != 0; // bit1
    }

    function _setStatus(uint8 flags, uint8 status) internal pure returns(uint8) {
        return (flags & 0xFE) | (status & 0x1); // clear bit0 then set
    }

    function _setIsPrivate(uint8 flags, bool isPrivate) internal pure returns(uint8) {
        if(isPrivate) return flags | 0x2;
        else return flags & 0xFD;
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
            name: bytes32(bytes(_name)),
            flags: _setIsPrivate(STATUS_IDLE, _isPrivate),
            value: _value,
            interestPerDay: _interestPerDay,
            minDays: _minDays,
            maxDays: _maxDays,
            borrower: address(0),
            escrowId: 0,
            imageHash: bytes32(bytes(_imageUrl)),
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
        if(_getStatus(item.flags) != STATUS_IDLE) revert CannotUpdateBorrowed();

        item.name = bytes32(bytes(_name));
        item.flags = _setIsPrivate(_setStatus(item.flags, STATUS_IDLE), _isPrivate);
        item.value = _value;
        item.interestPerDay = _interestPerDay;
        item.minDays = _minDays;
        item.maxDays = _maxDays;
        item.imageHash = bytes32(bytes(_imageUrl));

        emit ItemUpdated(_itemId);
    }

    // --------------------------------------
    // Borrowing
    // --------------------------------------
    function borrowItem(uint256 _itemId, uint256 _days) external payable {
        NFTItem storage item = items[_itemId];
        if(_getStatus(item.flags) != STATUS_IDLE) revert ItemNotAvailable();
        if(msg.sender == item.owner) revert OwnerCannotBorrow();
        if(_getIsPrivate(item.flags)) revert ItemIsPrivate();
        if(_days < item.minDays || _days > item.maxDays) revert InvalidDuration();

        uint256 totalAmount = item.value + (item.interestPerDay * _days);
        if(msg.value != totalAmount) revert IncorrectEscrowAmount();

        uint256 escrowId = nextEscrowId++;
        escrows[escrowId] = Escrow({
            itemId: _itemId,
            borrower: msg.sender,
            startTime: block.timestamp,
            durationDays: _days,
            amount: msg.value,
            status: ESCROW_PENDING
        });

        item.flags = _setStatus(item.flags, STATUS_BORROWED);
        item.borrower = msg.sender;
        item.escrowId = escrowId;

        emit ItemBorrowed(_itemId, msg.sender, escrowId);
    }

    // --------------------------------------
    // Admin escrow resolution
    // --------------------------------------
    function resolveEscrow(uint256 _escrowId, uint8 result) external onlyAdmin {
        Escrow storage escrow = escrows[_escrowId];
        NFTItem storage item = items[escrow.itemId];

        if(escrow.status != ESCROW_PENDING && escrow.status != ESCROW_DISPUTE) revert CannotResolveEscrow();

        if(result == ESCROW_COMPLETED || result == ESCROW_OWNER_WINS) {
            payable(item.owner).transfer(escrow.amount);
        } else if(result == ESCROW_BORROWER_WINS || result == ESCROW_CANCELLED) {
            payable(escrow.borrower).transfer(escrow.amount);
        }

        escrow.status = result;
        item.flags = _setStatus(item.flags, STATUS_IDLE);
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

    function getItemStatus(uint256 _itemId) external view returns(uint8) {
        return _getStatus(items[_itemId].flags);
    }

    function getItemIsPrivate(uint256 _itemId) external view returns(bool) {
        return _getIsPrivate(items[_itemId].flags);
    }

    function getEscrowStatus(uint256 _escrowId) external view returns(uint8) {
        return escrows[_escrowId].status;
    }

    function getItemName(uint256 _itemId) external view returns(string memory) {
        return string(abi.encodePacked(items[_itemId].name));
    }

    function getItemImage(uint256 _itemId) external view returns(string memory) {
        return string(abi.encodePacked(items[_itemId].imageHash));
    }
}
