# NFT Lending Smart Contract

This project is a decentralized NFT lending platform where users can lend and borrow NFTs. The smart contract manages items, borrowing, escrow, and interest payments. It includes admin-controlled escrow resolution and view helper functions for easier data retrieval.

---

## Features

- **Create NFT items** with metadata and lending terms (value, interest per day, min/max lending days).  
- **Borrow NFT items** with escrow payments.  
- **Resolve escrow** as admin (Completed, Cancelled, OwnerWins, BorrowerWins, Dispute).  
- **View helpers** for querying:  
  - Items owned by a user  
  - Borrowed items by a user  
  - Available items for borrowing  
  - Item status, escrow ID, and name  

- **Access control**: Only admin can resolve escrows. Only owner can update their items.

---

## Prerequisites

- Node.js v18+  
- npm or yarn  
- Hardhat v2+  
- Foundry (optional, for Solidity testing)  

---

## Installation

Clone the repository:

```bash
git clone <https://github.com/JaJoJi/hardhat-monad-leanding-nft/tree/JJ>
cd <hardhat-monad-leanding-nft>
```

Install npm dependencies:
```bash
npm install
```

## Running Tests
```bash
npx hardhat test
```