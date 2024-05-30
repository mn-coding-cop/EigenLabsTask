const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");

describe("OTCSwap", function () {
  // We define a fixture to reuse the same setup in every test.
  async function deployOTCSwapFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, counterparty, otherAccount] = await ethers.getSigners();

    const OTCSwap = await ethers.getContractFactory("OTCSwap");
    const otcSwap = await OTCSwap.deploy();
    const TokenX = await ethers.getContractFactory("ERC20Token");
    const tokenX = await TokenX.deploy(10000);
    const TokenY = await ethers.getContractFactory("ERC20Token");
    const tokenY = await TokenY.connect(counterparty).deploy(20000);

    return { otcSwap, tokenX, tokenY, owner, counterparty, otherAccount };
  }

  describe("Create Swap", function () {
    it("Should create a new swap and store its details", async function () {
      const { otcSwap, tokenX, tokenY, owner, counterparty } =
        await loadFixture(deployOTCSwapFixture);

      const initiatorAmount = 100;
      const counterpartyAmount = 200;
      const expiry = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now

      const swapId = await otcSwap.generateSwapsId(
        owner.address,
        counterparty.address,
        tokenX.target,
        tokenY.target,
        initiatorAmount,
        counterpartyAmount,
        expiry
      );

      await expect(
        otcSwap.createSwap(
          counterparty.address,
          tokenX.target,
          tokenY.target,
          initiatorAmount,
          counterpartyAmount,
          expiry
        )
      )
        .to.emit(otcSwap, "swapCreated")
        .withArgs(
          swapId,
          owner.address,
          counterparty.address,
          tokenX.target,
          tokenY.target,
          initiatorAmount,
          counterpartyAmount,
          expiry
        );
    });
  });

  describe("Execute Swap", function () {
    it("Should execute a swap and transfer tokens", async function () {
      const { otcSwap, tokenX, tokenY, owner, counterparty, otherAccount } =
        await loadFixture(deployOTCSwapFixture);

      const initiatorAmount = 100;
      const counterpartyAmount = 200;
      const expiry = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now

      const swapId = await otcSwap.generateSwapsId(
        owner.address,
        counterparty.address,
        tokenX.target,
        tokenY.target,
        initiatorAmount,
        counterpartyAmount,
        expiry
      );

      await tokenX.approve(otcSwap.target, initiatorAmount);

      await otcSwap.createSwap(
        counterparty.address,
        tokenX.target,
        tokenY.target,
        initiatorAmount,
        counterpartyAmount,
        expiry
      );

      await tokenY
        .connect(counterparty)
        .approve(otcSwap.target, counterpartyAmount);

      // otheraccounnt should not be able to execute the swap
      await expect(
        otcSwap.connect(otherAccount).executeSwap(swapId)
      ).to.be.revertedWith(
        "Only the specified counterparty can execute this swap"
      );

      const tx = otcSwap.connect(counterparty).executeSwap(swapId);
      await expect(tx).to.changeTokenBalances(
        tokenX,
        [owner.address, counterparty.address],
        [-initiatorAmount, initiatorAmount]
      );
      await expect(tx).to.changeTokenBalances(
        tokenY,
        [owner.address, counterparty.address],
        [counterpartyAmount, -counterpartyAmount]
      );

      await expect(
        otcSwap.connect(counterparty).executeSwap(swapId)
      ).to.be.revertedWith("Swap does not exist");
    });
  });
  describe("Cancel Swap", function () {
    it("Should cancel a swap if initiated by the initiator", async function () {
      const { otcSwap, tokenX, tokenY, owner, counterparty } =
        await loadFixture(deployOTCSwapFixture);

      const initiatorAmount = 100;
      const counterpartyAmount = 200;
      const expiry = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now

      const swapId = await otcSwap.generateSwapsId(
        owner.address,
        counterparty.address,
        tokenX.target,
        tokenY.target,
        initiatorAmount,
        counterpartyAmount,
        expiry
      );

      await tokenX.approve(otcSwap.target, initiatorAmount);

      await otcSwap.createSwap(
        counterparty.address,
        tokenX.target,
        tokenY.target,
        initiatorAmount,
        counterpartyAmount,
        expiry
      );

      await expect(otcSwap.cancelSwap(swapId))
        .to.emit(otcSwap, "swapCancelled")
        .withArgs(swapId);

      const swap = await otcSwap.swapDetails(swapId);
      expect(swap.exists).to.be.false;
    });
  });

  describe("Expired Swap", function () {
    it("Should not allow executing an expired swap", async function () {
      const {
        otcSwap: otcSwap,
        tokenX,
        tokenY,
        owner,
        counterparty,
      } = await loadFixture(deployOTCSwapFixture);

      const initiatorAmount = 100;
      const counterpartyAmount = 200;
      const expiry = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now

      const swapId = await otcSwap.generateSwapsId(
        owner.address,
        counterparty.address,
        tokenX.target,
        tokenY.target,
        initiatorAmount,
        counterpartyAmount,
        expiry
      );

      await otcSwap.createSwap(
        counterparty.address,
        tokenX.target,
        tokenY.target,
        initiatorAmount,
        counterpartyAmount,
        expiry
      );

      await tokenX.approve(otcSwap.target, initiatorAmount);
      await tokenY
        .connect(counterparty)
        .approve(otcSwap.target, counterpartyAmount);

      // Fast forward time to after the expiry
      await ethers.provider.send("evm_increaseTime", [3600 * 2]); // 2 hours
      await ethers.provider.send("evm_mine");

      await expect(
        otcSwap.connect(counterparty).executeSwap(swapId)
      ).to.be.revertedWith("Swap has expired");
    });
  });
});
