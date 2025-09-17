import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("NFTLendingModule", (m) => {
  const NFTLending = m.contract("NFTLending"); 

  return { NFTLending };
});
