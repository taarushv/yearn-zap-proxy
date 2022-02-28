const hre = require("hardhat");
const { ethers } = hre;

async function takeSnapshot() {
  return await hre.network.provider.send("evm_snapshot");
}

async function revertToSnapshot(snapshotId) {
  await hre.network.provider.send("evm_revert", [snapshotId]);
}

async function setNetworkFork(blockNumber) {
  const jsonRpcUrl = hre.config.networks.hardhat.forking.url;
  await hre.network.provider.send("hardhat_reset", [
    {
      forking: {
        blockNumber,
        jsonRpcUrl,
      },
    },
  ]);
}

async function impersonateAccount(address) {
  await hre.network.provider.send("hardhat_impersonateAccount", [address]);
  const signer = await ethers.getSigner(address);
  return signer;
}

async function setBalance(address, amount) {
  await hre.network.provider.send("hardhat_setBalance", [
    address,
    ethers.utils.hexValue(amount),
  ]);
}

async function advanceBlocks(numBlocks) {
  for (let i = 0; i < numBlocks; i++) {
    await hre.network.provider.send("evm_mine");
  }
}

async function setTimestamp(timestamp) {
  await hre.network.provider.send("evm_setNextBlockTimestamp", [timestamp]);
  await hre.network.provider.send("evm_mine");
}

async function acquireTokens(address, tokenAddress, destAddress, amount) {
  const signer = await impersonateAccount(address);
  await setBalance(address, ethers.utils.parseEther("10"));
  const token = await ethers.getContractAt("IERC20", tokenAddress);
  await token.connect(signer).transfer(destAddress, amount);
}

module.exports = {
  advanceBlocks,
  takeSnapshot,
  revertToSnapshot,
  setNetworkFork,
  impersonateAccount,
  setBalance,
  setTimestamp,
  acquireTokens,
};
