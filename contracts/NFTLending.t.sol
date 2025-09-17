// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../contracts/NFTLending.sol";

contract NFTLendingTest is Test {
    NFTLending lending;
    address admin = address(0xABCD);
    address user1 = address(0x1111);
    address user2 = address(0x2222);
    address user3 = address(0x3333);

    function setUp() public {
        vm.prank(admin);
        lending = new NFTLending();
    }

    // ------------------------------
    // Item creation tests
    // ------------------------------
    function testCreateItem() public {
        vm.prank(user1);
        lending.createItem("Sword", false, 1 ether, 0.01 ether, 1, 10, "url_sword");

        string memory name = lending.getItemName(0);
        assertEq(name, "Sword");

        uint256[] memory itemsOfUser1 = lending.getOwnerItems(user1);
        assertEq(itemsOfUser1.length, 1);
        assertEq(itemsOfUser1[0], 0);
    }

    function testOwnerItemsMultiple() public {
        vm.startPrank(user1);
        lending.createItem("Item1", false, 1 ether, 0.01 ether, 1, 10, "url1");
        lending.createItem("Item2", false, 1 ether, 0.01 ether, 1, 10, "url2");
        vm.stopPrank();

        uint256[] memory items = lending.getOwnerItems(user1);
        assertEq(items.length, 2);
        assertEq(items[0], 0);
        assertEq(items[1], 1);
    }

    // ------------------------------
    // Borrowing tests
    // ------------------------------
    function testBorrowItem() public {
        vm.prank(user1);
        lending.createItem("Shield", false, 1 ether, 0.01 ether, 1, 10, "url_shield");

        uint256 totalAmount = 1 ether + 0.01 ether * 5;
        vm.deal(user2, totalAmount);

        vm.prank(user2);
        lending.borrowItem{value: totalAmount}(0, 5);

        uint8 status = lending.getEscrowStatus(0);
        assertEq(status, 0); // ESCROW_PENDING

        uint8 itemStatus = lending.getItemStatus(0);
        assertEq(itemStatus, 1); // STATUS_BORROWED
    }

    function testCannotBorrowIfNotIdle() public {
        vm.prank(user1);
        lending.createItem("Helmet", false, 1 ether, 0.01 ether, 1, 10, "url_helmet");

        uint256 totalAmount = 1 ether + 0.01 ether * 3;
        vm.deal(user2, totalAmount);
        vm.prank(user2);
        lending.borrowItem{value: totalAmount}(0, 3);

        vm.deal(user3, totalAmount);
        vm.prank(user3);
        vm.expectRevert(NFTLending.ItemNotAvailable.selector);
        lending.borrowItem{value: totalAmount}(0, 2);
    }

    function testBorrowPrivateItemFails() public {
        vm.prank(user1);
        lending.createItem("SecretHammer", true, 1 ether, 0.01 ether, 1, 10, "url_hammer");

        uint256 totalAmount = 1 ether + 0.01 ether * 2;
        vm.deal(user2, totalAmount);

        vm.prank(user2);
        vm.expectRevert(NFTLending.ItemIsPrivate.selector);
        lending.borrowItem{value: totalAmount}(0, 2);
    }

    function testBorrowFailsIfInsufficientValue() public {
        vm.prank(user1);
        lending.createItem("Bow", false, 1 ether, 0.01 ether, 1, 10, "url_bow");

        vm.deal(user2, 1 ether);
        vm.prank(user2);
        vm.expectRevert(NFTLending.IncorrectEscrowAmount.selector);
        lending.borrowItem{value: 1 ether}(0, 5);
    }

    // ------------------------------
    // Update item tests
    // ------------------------------
    function testCannotEditItemWhileRenting() public {
        vm.prank(user1);
        lending.createItem("Axe", false, 1 ether, 0.01 ether, 1, 10, "url_axe");

        uint256 totalAmount = 1 ether + 0.01 ether * 2;
        vm.deal(user2, totalAmount);
        vm.prank(user2);
        lending.borrowItem{value: totalAmount}(0, 2);

        vm.prank(user1);
        vm.expectRevert(NFTLending.CannotUpdateBorrowed.selector);
        lending.updateItem(0, "Axe+", true, 2 ether, 0.02 ether, 1, 10, "url_axe2");
    }

    function testUpdateItemSuccessWhenIdle() public {
        vm.prank(user1);
        lending.createItem("Axe", false, 1 ether, 0.01 ether, 1, 10, "url_axe");

        vm.prank(user1);
        lending.updateItem(0, "Axe+", false, 2 ether, 0.02 ether, 1, 10, "url_axe2");

        string memory name = lending.getItemName(0);
        assertEq(name, "Axe+");
    }

    // ------------------------------
    // Escrow resolution tests
    // ------------------------------
    function testResolveEscrow() public {
        vm.prank(user1);
        lending.createItem("Bow", false, 1 ether, 0.01 ether, 1, 10, "url_bow");

        uint256 totalAmount = 1 ether + 0.01 ether * 3;
        vm.deal(user2, totalAmount);
        vm.prank(user2);
        lending.borrowItem{value: totalAmount}(0, 3);

        uint256 escrowId = lending.getItemEscrowId(0);

        vm.prank(admin);
        lending.resolveEscrow(escrowId, 1); // ESCROW_COMPLETED

        uint8 newStatus = lending.getEscrowStatus(escrowId);
        assertEq(newStatus, 1);

        uint8 itemStatus = lending.getItemStatus(0);
        assertEq(itemStatus, 0); // STATUS_IDLE
    }

    function testCannotResolveEscrowNonAdmin() public {
        vm.prank(user1);
        lending.createItem("Spear", false, 1 ether, 0.01 ether, 1, 10, "url_spear");

        uint256 totalAmount = 1 ether + 0.01 ether * 1;
        vm.deal(user2, totalAmount);
        vm.prank(user2);
        lending.borrowItem{value: totalAmount}(0, 1);

        uint256 escrowId = lending.getItemEscrowId(0);

        vm.prank(user2);
        vm.expectRevert(NFTLending.OnlyAdmin.selector);
        lending.resolveEscrow(escrowId, 1);
    }

    function testCancelEscrow() public {
        vm.prank(user1);
        lending.createItem("Hammer", false, 1 ether, 0.01 ether, 1, 10, "url_hammer");

        uint256 totalAmount = 1 ether + 0.01 ether * 2;
        vm.deal(user2, totalAmount);
        vm.prank(user2);
        lending.borrowItem{value: totalAmount}(0, 2);

        uint256 escrowId = lending.getItemEscrowId(0);

        vm.prank(admin);
        lending.resolveEscrow(escrowId, 2); // ESCROW_CANCELLED

        uint8 status = lending.getEscrowStatus(escrowId);
        assertEq(status, 2);
    }

    function testResolveEscrowTransfersFundsToOwner() public {
        vm.prank(user1);
        lending.createItem("Mace", false, 1 ether, 0.01 ether, 1, 10, "url_mace");

        uint256 totalAmount = 1 ether + 0.01 ether * 2;
        vm.deal(user2, totalAmount);
        vm.prank(user2);
        lending.borrowItem{value: totalAmount}(0, 2);

        uint256 escrowId = lending.getItemEscrowId(0);

        uint256 balanceBefore = user1.balance;

        vm.prank(admin);
        lending.resolveEscrow(escrowId, 1); // ESCROW_COMPLETED

        uint256 balanceAfter = user1.balance;
        assertGt(balanceAfter, balanceBefore, "Owner should receive funds");
    }

    // ------------------------------
    // View helper tests
    // ------------------------------
    function testGetAvailableItems() public {
        vm.prank(user1);
        lending.createItem("Sword", false, 1 ether, 0.01 ether, 1, 10, "url_sword");

        vm.prank(user1);
        lending.createItem("PrivateShield", true, 1 ether, 0.01 ether, 1, 10, "url_shield");

        uint256[] memory available = lending.getAvailableItems();
        assertEq(available.length, 1);
        assertEq(available[0], 0);
    }

    function testViewHelpers() public {
        vm.prank(user1);
        lending.createItem("Item1", false, 1 ether, 0.01 ether, 1, 5, "url1");
        vm.prank(user1);
        lending.createItem("Item2", true, 2 ether, 0.02 ether, 1, 5, "url2");
        vm.prank(user1);
        lending.createItem("Item3", false, 1.5 ether, 0.015 ether, 1, 5, "url3");

        uint256 totalAmount1 = 1 ether + 0.01 ether * 3;
        vm.deal(user2, totalAmount1);
        vm.prank(user2);
        lending.borrowItem{value: totalAmount1}(0, 3);

        uint256[] memory borrowedByUser2 = lending.getBorrowerItems(user2);
        assertEq(borrowedByUser2.length, 1);
        assertEq(borrowedByUser2[0], 0);

        uint256[] memory available = lending.getAvailableItems();
        assertEq(available.length, 1);
        assertEq(available[0], 2);

        uint256[] memory ownerItems = lending.getOwnerItems(user1);
        assertEq(ownerItems.length, 3);
        assertEq(ownerItems[0], 0);
        assertEq(ownerItems[1], 1);
        assertEq(ownerItems[2], 2);

        assertEq(lending.getItemName(0), "Item1");
        assertEq(lending.getItemName(1), "Item2");
        assertEq(lending.getItemName(2), "Item3");

        assertEq(lending.getItemStatus(0), 1); // borrowed
        assertEq(lending.getItemStatus(1), 0);
        assertEq(lending.getItemStatus(2), 0);

        assertEq(lending.getItemEscrowId(0), 0);
        assertEq(lending.getItemEscrowId(1), 0);
        assertEq(lending.getItemEscrowId(2), 0);
    }
}
