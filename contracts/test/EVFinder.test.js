const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("EVFinder Security Tests", function () {
  let evfinder;
  let owner, user1, user2, attacker;

  beforeEach(async function () {
    [owner, user1, user2, attacker] = await ethers.getSigners();
    const EVFinder = await ethers.getContractFactory("EVFinder");
    evfinder = await EVFinder.deploy();
    await evfinder.waitForDeployment();
  });

  // ==================== USER REGISTRATION ====================

  describe("User Registration", function () {
    it("should register a new user", async function () {
      await evfinder.connect(user1).registerUser("Alice");
      const isRegistered = await evfinder.isUserRegistered(user1.address);
      expect(isRegistered).to.be.true;
    });

    it("should prevent duplicate registration", async function () {
      await evfinder.connect(user1).registerUser("Alice");
      await expect(
        evfinder.connect(user1).registerUser("Alice2")
      ).to.be.revertedWith("User already registered");
    });

    it("should reject empty name", async function () {
      await expect(
        evfinder.connect(user1).registerUser("")
      ).to.be.revertedWith("Name cannot be empty");
    });
  });

  // ==================== BOOKING SECURITY ====================

  describe("Booking Security", function () {
    beforeEach(async function () {
      await evfinder.connect(user1).registerUser("Alice");
      await evfinder.connect(user2).registerUser("Bob");
    });

    it("should prevent unregistered user from booking", async function () {
      const now = Math.floor(Date.now() / 1000);
      await expect(
        evfinder.connect(attacker).createBooking("station1", "CCS2", now + 3600, now + 7200, 15000, 1200)
      ).to.be.revertedWith("User not registered");
    });

    it("should prevent double booking (time conflict)", async function () {
      const now = Math.floor(Date.now() / 1000);
      const start = now + 3600;
      const end = now + 7200;

      await evfinder.connect(user1).createBooking("station1", "CCS2", start, end, 15000, 1200);

      // Overlapping booking should fail
      await expect(
        evfinder.connect(user2).createBooking("station1", "CCS2", start + 1800, end + 1800, 15000, 1200)
      ).to.be.revertedWith("Time conflict with existing booking");
    });

    it("should allow non-overlapping bookings at same station", async function () {
      const now = Math.floor(Date.now() / 1000);
      await evfinder.connect(user1).createBooking("station1", "CCS2", now + 3600, now + 7200, 15000, 1200);
      // Non-overlapping booking should succeed
      await evfinder.connect(user2).createBooking("station1", "CCS2", now + 7200, now + 10800, 15000, 1200);
    });

    it("should reject end time before start time", async function () {
      const now = Math.floor(Date.now() / 1000);
      await expect(
        evfinder.connect(user1).createBooking("station1", "CCS2", now + 7200, now + 3600, 15000, 1200)
      ).to.be.revertedWith("End time must be after start time");
    });
  });

  // ==================== ESCROW PAYMENT SECURITY ====================

  describe("Escrow Payment Security", function () {
    let bookingId;

    beforeEach(async function () {
      await evfinder.connect(user1).registerUser("Alice");
      const now = Math.floor(Date.now() / 1000);
      const tx = await evfinder.connect(user1).createBooking("station1", "CCS2", now + 3600, now + 7200, 15000, 1200);
      await tx.wait();
      bookingId = await evfinder.bookingCounter();
    });

    it("should only allow booking owner to pay", async function () {
      await expect(
        evfinder.connect(attacker).payBooking(bookingId, owner.address, { value: ethers.parseEther("0.01") })
      ).to.be.revertedWith("Not booking owner");
    });

    it("should prevent double payment", async function () {
      await evfinder.connect(user1).payBooking(bookingId, owner.address, { value: ethers.parseEther("0.01") });
      await expect(
        evfinder.connect(user1).payBooking(bookingId, owner.address, { value: ethers.parseEther("0.01") })
      ).to.be.revertedWith("Already paid");
    });

    it("should release payment to beneficiary on complete", async function () {
      await evfinder.connect(user1).payBooking(bookingId, user2.address, { value: ethers.parseEther("0.1") });

      const balanceBefore = await ethers.provider.getBalance(user2.address);
      await evfinder.connect(user1).completeBooking(bookingId, "0xabc123");
      const balanceAfter = await ethers.provider.getBalance(user2.address);

      expect(balanceAfter - balanceBefore).to.equal(ethers.parseEther("0.1"));
    });

    it("should refund user on cancel", async function () {
      await evfinder.connect(user1).payBooking(bookingId, user2.address, { value: ethers.parseEther("0.1") });

      const balanceBefore = await ethers.provider.getBalance(user1.address);
      const tx = await evfinder.connect(user1).cancelBooking(bookingId);
      const receipt = await tx.wait();
      const gasCost = receipt.gasUsed * receipt.gasPrice;
      const balanceAfter = await ethers.provider.getBalance(user1.address);

      // Balance should increase by payment amount minus gas
      expect(balanceAfter + gasCost - balanceBefore).to.equal(ethers.parseEther("0.1"));
    });

    it("should prevent attacker from cancelling another user's booking", async function () {
      await expect(
        evfinder.connect(attacker).cancelBooking(bookingId)
      ).to.be.revertedWith("Not booking owner");
    });

    it("should prevent completing already cancelled booking", async function () {
      await evfinder.connect(user1).cancelBooking(bookingId);
      await expect(
        evfinder.connect(user1).completeBooking(bookingId, "0xabc")
      ).to.be.revertedWith("Booking cannot be completed");
    });
  });

  // ==================== P2P STATION SECURITY ====================

  describe("P2P Station Security", function () {
    beforeEach(async function () {
      await evfinder.connect(user1).registerUser("Alice");
      await evfinder.connect(user1).registerStation(
        "Alice's Charger", "123 Main St", 6927100, 79861200, "Type2", 7000, 25, true
      );
    });

    it("should prevent non-owner from updating station", async function () {
      await evfinder.connect(attacker).registerUser("Attacker");
      await expect(
        evfinder.connect(attacker).updateStation(1, 50, true)
      ).to.be.revertedWith("Not station owner");
    });

    it("should prevent non-owner from deactivating station", async function () {
      await evfinder.connect(attacker).registerUser("Attacker");
      await expect(
        evfinder.connect(attacker).deactivateStation(1)
      ).to.be.revertedWith("Not station owner");
    });

    it("should award green energy reward points", async function () {
      const points = await evfinder.getRewardPoints(user1.address);
      expect(points).to.equal(5); // 5 points for green energy station
    });
  });

  // ==================== ENERGY TRADING SECURITY ====================

  describe("Energy Trading Security", function () {
    beforeEach(async function () {
      await evfinder.connect(user1).registerUser("Alice");
      await evfinder.connect(user2).registerUser("Bob");
      await evfinder.connect(user1).addEnergyCredits(50000); // 50 kWh
    });

    it("should prevent listing more energy than balance", async function () {
      await expect(
        evfinder.connect(user1).listEnergy(100000, 15) // 100 kWh > 50 kWh
      ).to.be.revertedWith("Insufficient energy credits");
    });

    it("should escrow credits when listing", async function () {
      await evfinder.connect(user1).listEnergy(30000, 15); // 30 kWh
      const credits = await evfinder.getEnergyCredits(user1.address);
      expect(credits).to.equal(20000); // 50 - 30 = 20 kWh remaining
    });

    it("should prevent buying own listing", async function () {
      await evfinder.connect(user1).listEnergy(30000, 15);
      await expect(
        evfinder.connect(user1).purchaseEnergy(1, "0xtx")
      ).to.be.revertedWith("Cannot buy own listing");
    });

    it("should transfer credits to buyer on purchase", async function () {
      await evfinder.connect(user1).listEnergy(30000, 15);
      await evfinder.connect(user2).purchaseEnergy(1, "0xtx");
      const buyerCredits = await evfinder.getEnergyCredits(user2.address);
      expect(buyerCredits).to.equal(30000);
    });

    it("should return credits on cancel", async function () {
      await evfinder.connect(user1).listEnergy(30000, 15);
      await evfinder.connect(user1).cancelEnergyListing(1);
      const credits = await evfinder.getEnergyCredits(user1.address);
      expect(credits).to.equal(50000); // All returned
    });

    it("should prevent non-owner from cancelling listing", async function () {
      await evfinder.connect(user1).listEnergy(30000, 15);
      await expect(
        evfinder.connect(attacker).cancelEnergyListing(1)
      ).to.be.revertedWith("Not listing owner");
    });
  });

  // ==================== REVIEW SECURITY ====================

  describe("Review Security", function () {
    beforeEach(async function () {
      await evfinder.connect(user1).registerUser("Alice");
      // Register station and create + complete a booking
      await evfinder.connect(user1).registerStation(
        "Test Station", "123 St", 6927100, 79861200, "Type2", 7000, 25, false
      );
      const now = Math.floor(Date.now() / 1000);
      await evfinder.connect(user1).createBooking("1", "Type2", now + 100, now + 200, 15000, 1200);
      const bookingId = await evfinder.bookingCounter();
      await evfinder.connect(user1).completeBooking(bookingId, "0xtx");
    });

    it("should prevent duplicate review for same booking", async function () {
      const bookingId = await evfinder.bookingCounter();
      await evfinder.connect(user1).submitReview(1, bookingId, 5, "Great!");
      await expect(
        evfinder.connect(user1).submitReview(1, bookingId, 4, "Changed mind")
      ).to.be.revertedWith("Booking already reviewed");
    });

    it("should reject invalid rating (0 or 6)", async function () {
      const bookingId = await evfinder.bookingCounter();
      await expect(
        evfinder.connect(user1).submitReview(1, bookingId, 0, "Bad")
      ).to.be.revertedWith("Rating must be 1-5");
    });
  });

  // ==================== ACCESS CONTROL ====================

  describe("Access Control", function () {
    it("should only allow owner to set payment receiver", async function () {
      await expect(
        evfinder.connect(attacker).setDefaultPaymentReceiver(attacker.address)
      ).to.be.revertedWith("Not owner");
    });

    it("should reject zero address as payment receiver", async function () {
      await expect(
        evfinder.connect(owner).setDefaultPaymentReceiver(ethers.ZeroAddress)
      ).to.be.revertedWith("Invalid address");
    });
  });
});
