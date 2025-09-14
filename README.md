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

1. Clone the repository:

```bash
git clone <your-repo-url>
cd <your-repo-folder>
Install npm dependencies:

bash
Copy code
npm install
Install Hardhat if not installed globally:

bash
Copy code
npm install --save-dev hardhat
Install Foundry (for testing with forge-std):

bash
Copy code
curl -L https://foundry.paradigm.xyz | bash
foundryup
Setup
Create a .env file in the project root:

bash
Copy code
touch .env
Add environment variables if needed (e.g., for network URL or private keys):

env
Copy code
PRIVATE_KEY=your_private_key_here
RPC_URL=http://127.0.0.1:8545
Note: For local Hardhat testing, .env is optional.

Compile Smart Contracts
bash
Copy code
npx hardhat compile
This will compile all Solidity contracts under contracts/.

Running Tests
The project uses Hardhat + Foundry style tests (forge-std/Test.sol):

bash
Copy code
npx hardhat test
This command will:

Launch a local Hardhat network

Deploy the NFTLending contract

Run all Solidity test functions in test/NFTLendingTest.sol

Show the results in the console

License

MIT License