const { expect } = require("chai");
const { ethers } = require("hardhat");
const { acquireTokens } = require("../scripts/utils");

describe("YieldDonator", function () {
  let yieldDonator;
  let addr1;
  const USDCAddress = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";
  const zeroProxyAddress = "0xDef1C0ded9bec7F1a1670819833240f027b25EfF";

  before(async () => {
    const YieldDonatorFactory = await ethers.getContractFactory("YieldDonator");
    [addr1] = await ethers.getSigners();

    yieldDonator = await YieldDonatorFactory.deploy(
      "0xe5eA7096f40D2598a7c74961B65288FC4d655bB2", // Debugger metamask address
      // "0xdCD90C7f6324cfa40d7169ef80b12031770B4325" // Yearn yVault: Curve stETH
      "0xa354F35829Ae975e850e23e9615b11Da1B3dC4DE" // Yearn USDC Vault
    );
    await yieldDonator.deployed();
    console.log("Yield donator deployed to:", yieldDonator.address);
    
    // acquire USDC tokens to deposit into Yearn USDC vault
    await acquireTokens(
      "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7",
      USDCAddress,
      addr1.address,
      ethers.utils.parseUnits("10000", 6)
    );
  });

  describe("Basic Deposit", function () {
    describe("Check USDC Balane", function () {
      it("check balance is equal to acquire tokens", async function () {
        const token = await ethers.getContractAt("IERC20", USDCAddress);
        const balance = await token.balanceOf(addr1.address);
        expect(balance.toNumber()).to.eq(ethers.utils.parseUnits("10000", 6));
      });
    });
    describe("Providing Liquidity", function () {
      it("can't buy invalid buyToken", async function () {
        const sellToken = "0x6b175474e89094c44da98b954eedeac495271d0f"; // DAI
        const sellAmount = 10000;
        const buyToken = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"; // USDC
        const target = zeroProxyAddress;
        const data = 0;
        const mintYTokens = 10000;

        await expect(
          yieldDonator.deposit(
            sellToken,
            sellAmount,
            buyToken,
            target,
            data,
            mintYTokens
          )
        ).to.be.revertedWith("Invalid buyToken");
      });
    });
  });
});
