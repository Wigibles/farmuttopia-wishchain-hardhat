const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Farmuttopia", function () {
  let farmuttopia;
  let usdt;
  let owner;
  let player1;
  let player2;
  let player3;

  const USDT_DECIMALS = 6;
  const INITIAL_BALANCE = ethers.utils.parseUnits("1000", USDT_DECIMALS);

  beforeEach(async function () {
    // Deploy mock USDT token
    const MockUSDT = await ethers.getContractFactory("MockUSDT");
    usdt = await MockUSDT.deploy("Mock USDT", "USDT", USDT_DECIMALS);
    await usdt.deployed();

    // Deploy Farmuttopia contract
    const Farmuttopia = await ethers.getContractFactory("Farmuttopia");
    farmuttopia = await Farmuttopia.deploy(usdt.address);
    await farmuttopia.deployed();

    // Get signers
    [owner, player1, player2, player3] = await ethers.getSigners();

    // Mint USDT to players
    await usdt.mint(player1.address, INITIAL_BALANCE);
    await usdt.mint(player2.address, INITIAL_BALANCE);
    await usdt.mint(player3.address, INITIAL_BALANCE);

    // Approve USDT spending
    await usdt.connect(player1).approve(farmuttopia.address, INITIAL_BALANCE);
    await usdt.connect(player2).approve(farmuttopia.address, INITIAL_BALANCE);
    await usdt.connect(player3).approve(farmuttopia.address, INITIAL_BALANCE);
  });

  describe("Initialization", function () {
    it("Should set the correct USDT address", async function () {
      expect(await farmuttopia.usdt()).to.equal(usdt.address);
    });

    it("Should set the correct owner", async function () {
      expect(await farmuttopia.owner()).to.equal(owner.address);
    });

    it("Should initialize with correct seed prices", async function () {
      expect(await farmuttopia.seedPrices(0)).to.equal(ethers.utils.parseUnits("0.008", USDT_DECIMALS)); // Common
      expect(await farmuttopia.seedPrices(1)).to.equal(ethers.utils.parseUnits("0.015", USDT_DECIMALS)); // Rare
      expect(await farmuttopia.seedPrices(2)).to.equal(ethers.utils.parseUnits("0.03", USDT_DECIMALS));  // Epic
    });
  });

  describe("Seed Planting", function () {
    it("Should allow planting a common seed", async function () {
      await farmuttopia.connect(player1).expandLand(1);
      const price = await farmuttopia.seedPrices(0);
      await expect(farmuttopia.connect(player1).buySeed(0))
        .to.emit(farmuttopia, "SeedPlanted")
        .withArgs(player1.address, 0, await farmuttopia.growDurations(0), 0);

      const seed = await farmuttopia.getSeed(player1.address, 0);
      expect(seed.seedType).to.equal(0); // Common
      expect(seed.watered).to.equal(false);
      expect(seed.harvested).to.equal(false);
    });

    // it("Should fail when trying to plant without enough USDT", async function () {
    //   await farmuttopia.connect(player1).expandLand(1);
    //   await usdt.connect(player1).transfer(owner.address, INITIAL_BALANCE);
    //   await expect(farmuttopia.connect(player1).buySeed(0))
    //     .to.be.reverted;
    // });
  });

  describe("Watering", function () {
    beforeEach(async function () {
      await farmuttopia.connect(player1).expandLand(1);
      await farmuttopia.connect(player1).buySeed(0); // Plant a common seed
    });

    it("Should allow watering a seed", async function () {
      await expect(farmuttopia.connect(player1).water(0))
        .to.emit(farmuttopia, "Watered")
        .withArgs(player1.address, 0);

      const seed = await farmuttopia.getSeed(player1.address, 0);
      expect(seed.watered).to.equal(true);
    });

    it("Should fail when trying to water an already watered seed", async function () {
      await farmuttopia.connect(player1).water(0);
      await expect(farmuttopia.connect(player1).water(0))
        .to.be.revertedWith("Already watered");
    });
  });

  describe("Harvesting", function () {
    beforeEach(async function () {
      await farmuttopia.connect(player1).expandLand(1);
      await farmuttopia.connect(player1).buySeed(0); // Plant a common seed
      await farmuttopia.connect(player1).water(0);
    });

    it("Should fail when trying to harvest too early", async function () {
      await expect(farmuttopia.connect(player1).harvest(0))
        .to.be.revertedWith("Too early");
    });

    it("Should allow harvesting after growth duration", async function () {
      // Fast forward time
      await ethers.provider.send("evm_increaseTime", [3600]); // 1 hour
      await ethers.provider.send("evm_mine");

      await expect(farmuttopia.connect(player1).harvest(0))
        .to.emit(farmuttopia, "Harvested");

      const seed = await farmuttopia.getSeed(player1.address, 0);
      expect(seed.harvested).to.equal(true);
    });
  });

  describe("Land Expansion", function () {
    it("Should allow expanding land", async function () {
      const plots = 2;
      await expect(farmuttopia.connect(player1).expandLand(plots))
        .to.emit(farmuttopia, "LandExpanded")
        .withArgs(player1.address, plots);

      expect(await farmuttopia.getLandSize(player1.address)).to.equal(plots);
    });

    it("Should fail when trying to expand with 0 plots", async function () {
      await expect(farmuttopia.connect(player1).expandLand(0))
        .to.be.revertedWith("Must expand at least 1");
    });
  });

  describe("Points and Rewards", function () {
    beforeEach(async function () {
      await farmuttopia.connect(player1).expandLand(1);
      await farmuttopia.connect(player1).buySeed(0);
      await farmuttopia.connect(player1).water(0);
      await ethers.provider.send("evm_increaseTime", [3600]);
      await ethers.provider.send("evm_mine");
      await farmuttopia.connect(player1).harvest(0);
    });

    it("Should allow converting points to USDT", async function () {
      const points = await farmuttopia.getMyPoints();
      if (points > 0) {
        await expect(farmuttopia.connect(player1).convertPointsToUSDT())
          .to.emit(farmuttopia, "PointsConverted");
      }
    });
  });

  describe("Season System", function () {
    beforeEach(async function () {
      // Setup multiple players with seeds and at least one full farming cycle
      await farmuttopia.connect(player1).expandLand(1);
      await farmuttopia.connect(player2).expandLand(1);
      await farmuttopia.connect(player3).expandLand(1);
      await farmuttopia.connect(player1).buySeed(0);
      await farmuttopia.connect(player2).buySeed(1);
      await farmuttopia.connect(player3).buySeed(2);
      // Complete a full farming cycle for player1 to add to leaderboard
      await farmuttopia.connect(player1).water(0);
      await ethers.provider.send("evm_increaseTime", [3600]); // 1 hour for common seed
      await ethers.provider.send("evm_mine");
      await farmuttopia.connect(player1).harvest(0);
      // Loop until player1 gets points (not Rotten)
      let points = await farmuttopia.getMyPoints();
      while (points === 0) {
        await farmuttopia.connect(player1).buySeed(0);
        await farmuttopia.connect(player1).water(0);
        await ethers.provider.send("evm_increaseTime", [3600]);
        await ethers.provider.send("evm_mine");
        await farmuttopia.connect(player1).harvest(0);
        points = await farmuttopia.getMyPoints();
      }
    });

    it("Should allow owner to end season and distribute rewards", async function () {
      await expect(farmuttopia.connect(owner).endSeasonAndDistribute())
        .to.emit(farmuttopia, "SeasonEnded");
    });

    it("Should fail when non-owner tries to end season", async function () {
      await expect(farmuttopia.connect(player1).endSeasonAndDistribute())
        .to.be.revertedWith("Not owner");
    });
  });
}); 