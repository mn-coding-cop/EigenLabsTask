const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");

describe("Marketplace Contract", function () {
  let Marketplace, marketplace, owner, addr1, addr2;

  beforeEach(async function () {
    // Deploy the contract before each test
    Marketplace = await ethers.getContractFactory("Marketplace");
    [owner, addr1, addr2] = await ethers.getSigners();
    marketplace = await Marketplace.deploy();
    // await marketplace.deployed();
  });

  describe("User Registration", function () {
    it("should allow a user to register with a unique username", async function () {
      await marketplace.connect(addr1).registerUser("Alice");
      const username = await marketplace.getUsernameByAddress(addr1.address);
      expect(username).to.equal("Alice");
    });

    it("should return true if the username is already taken", async function () {
      await marketplace.connect(addr1).registerUser("Alice");
      const isTaken = await marketplace.isUsernameTaken("Alice");
      expect(isTaken).to.be.true;
    });

    it("should not allow a user to register with an empty username", async function () {
      await expect(
        marketplace.connect(addr1).registerUser("")
      ).to.be.revertedWith("Username cannot be empty");
    });

    it("should not allow a user to register with an existing username", async function () {
      await marketplace.connect(addr1).registerUser("Alice");
      await expect(
        marketplace.connect(addr2).registerUser("Alice")
      ).to.be.revertedWith("Username is already taken");
    });

    it("should not allow a user to register if already registered", async function () {
      await marketplace.connect(addr1).registerUser("Alice");
      await expect(
        marketplace.connect(addr1).registerUser("AliceNew")
      ).to.be.revertedWith("User already registered");
    });
  });

  describe("Listing Items", function () {
    beforeEach(async function () {
      await marketplace.connect(addr1).registerUser("Alice");
    });

    it("should allow registered users to list an item", async function () {
      await marketplace
        .connect(addr1)
        .listItem("Item1", "Description1", ethers.parseEther("1"));
      const item = await marketplace.getItem(0);
      expect(item.name).to.equal("Item1");
      expect(item.price).to.equal(ethers.parseEther("1"));
      expect(item.owner).to.equal(addr1.address);
    });

    it("should not allow non-registered users to list an item", async function () {
      await expect(
        marketplace
          .connect(addr2)
          .listItem("Item1", "Description1", ethers.parseEther("1"))
      ).to.be.revertedWith("User not registered");
    });

    it("should not allow listing an item with zero price", async function () {
      await expect(
        marketplace
          .connect(addr1)
          .listItem("Item1", "Description1", ethers.parseEther("0"))
      ).to.be.revertedWith("Price must be greater than zero");
    });
  });

  describe("Purchasing Items", function () {
    beforeEach(async function () {
      await marketplace.connect(addr1).registerUser("Alice");
      await marketplace
        .connect(addr1)
        .listItem("Item1", "Description1", ethers.parseEther("1"));
    });

    it("should allow users to purchase listed items", async function () {
      await marketplace.connect(addr2).registerUser("Bob");
      await marketplace
        .connect(addr2)
        .purchaseItem(0, { value: ethers.parseEther("1") });

      const item = await marketplace.getItem(0);
      expect(item.isSold).to.be.true;
      expect(item.owner).to.equal(addr2.address);
    });

    it("should not allow purchasing an item with incorrect price", async function () {
      await marketplace.connect(addr2).registerUser("Bob");
      await expect(
        marketplace
          .connect(addr2)
          .purchaseItem(0, { value: ethers.parseEther("0.5") })
      ).to.be.revertedWith("Incorrect Ether value sent");
    });

    it("should not allow purchasing an already sold item", async function () {
      await marketplace.connect(addr2).registerUser("Bob");
      await marketplace
        .connect(addr2)
        .purchaseItem(0, { value: ethers.parseEther("1") });
      await expect(
        marketplace
          .connect(addr1)
          .purchaseItem(0, { value: ethers.parseEther("1") })
      ).to.be.revertedWith("Item already sold");
    });
  });

  describe("Withdrawing Funds", function () {
    beforeEach(async function () {
      await marketplace.connect(addr1).registerUser("Alice");
      await marketplace
        .connect(addr1)
        .listItem("Item1", "Description1", ethers.parseEther("1"));
      await marketplace.connect(addr2).registerUser("Bob");
      await marketplace
        .connect(addr2)
        .purchaseItem(0, { value: ethers.parseEther("1") });
    });

    it("should allow users to withdraw their funds", async function () {
      const balanceBefore = await ethers.provider.getBalance(addr1.address);
      await marketplace.connect(addr1).withdrawFunds();
      const balanceAfter = await ethers.provider.getBalance(addr1.address);

      expect(balanceAfter).to.be.above(balanceBefore);
    });

    it("should not allow users to withdraw if they have no funds", async function () {
      await expect(
        marketplace.connect(addr2).withdrawFunds()
      ).to.be.revertedWith("Insufficient funds to withdraw");
    });
  });

  describe("Updating Item Price", function () {
    beforeEach(async function () {
      await marketplace.connect(addr1).registerUser("Alice");
      await marketplace
        .connect(addr1)
        .listItem("Item1", "Description1", ethers.parseEther("1"));
    });

    it("should allow item owners to update the price", async function () {
      await marketplace
        .connect(addr1)
        .updateItemPrice(0, ethers.parseEther("2"));
      const item = await marketplace.getItem(0);
      expect(item.price).to.equal(ethers.parseEther("2"));
    });

    it("should not allow non-owners to update the price", async function () {
      await expect(
        marketplace.connect(addr2).updateItemPrice(0, ethers.parseEther("2"))
      ).to.be.revertedWith("Only the owner can update the price");
    });

    it("should not allow updating the price of a sold item", async function () {
      await marketplace.connect(addr2).registerUser("Bob");
      await marketplace
        .connect(addr2)
        .purchaseItem(0, { value: ethers.parseEther("1") });
      await expect(
        marketplace.connect(addr1).updateItemPrice(0, ethers.parseEther("2"))
      ).to.be.revertedWith("Item already sold");
    });

    it("should not allow updating the price to zero", async function () {
      await expect(
        marketplace.connect(addr1).updateItemPrice(0, ethers.parseEther("0"))
      ).to.be.revertedWith("Price must be greater than zero");
    });
  });

  describe("Relisting Items", function () {
    beforeEach(async function () {
      await marketplace.connect(addr1).registerUser("Alice");
      await marketplace
        .connect(addr1)
        .listItem("Item1", "Description1", ethers.parseEther("1"));
      await marketplace.connect(addr2).registerUser("Bob");
      await marketplace
        .connect(addr2)
        .purchaseItem(0, { value: ethers.parseEther("1") });
    });

    it("should allow item owners to relist a sold item", async function () {
      await marketplace.connect(addr2).relistItem(0, ethers.parseEther("2"));
      const item = await marketplace.getItem(0);
      expect(item.isSold).to.be.false;
      expect(item.price).to.equal(ethers.parseEther("2"));
    });

    it("should not allow non-owners to relist a sold item", async function () {
      await expect(
        marketplace.connect(addr1).relistItem(0, ethers.parseEther("2"))
      ).to.be.revertedWith("Only the owner can relist the item");
    });

    it("should not allow relisting an item with zero price", async function () {
      await expect(
        marketplace.connect(addr2).relistItem(0, ethers.parseEther("0"))
      ).to.be.revertedWith("Price must be greater than zero");
    });

    it("should not allow relisting an item that is not sold", async function () {
      await marketplace.connect(addr2).relistItem(0, ethers.parseEther("2"));
      await expect(
        marketplace.connect(addr2).relistItem(0, ethers.parseEther("2"))
      ).to.be.revertedWith("Item is not sold");
    });
  });
});
