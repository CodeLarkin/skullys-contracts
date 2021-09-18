const { expect } = require("chai");

const { ethers, waffle } = hre;
const { BigNumber, utils } = ethers;
const { constants, expectRevert } = require('@openzeppelin/test-helpers')

describe("Test harness for Skullys", function () {
    async function startPreSaleNow (provider, skullys) {
        // Get the current block time and set the PreSale time to now
        // this ensures that the test starts in PreSale and not PublicSale
        let blockNum = await provider.getBlockNumber()
        let initTime = (await provider.getBlock(blockNum)).timestamp
        await skullys.setPreSaleTime(BigNumber.from(initTime))
    }
    async function startPreSaleLater (provider, skullys) {
        let blockNum = await provider.getBlockNumber()
        let initTime = (await provider.getBlock(blockNum)).timestamp
        await skullys.setPreSaleTime(BigNumber.from(initTime + 100000))
    }
    async function startPublicSaleNow (provider, skullys) {
        // set presale to 9 hours ago so public sale is live now
        let blockNum = await provider.getBlockNumber()
        let initTime = (await provider.getBlock(blockNum)).timestamp
        let initDate = new Date(initTime)
        initDate.setHours(initDate.getHours() - 9)
        await skullys.setPreSaleTime(BigNumber.from(initDate.valueOf()))
    }

    before(async function () {
        this.provider = ethers.provider;

        this.Skullys   = await ethers.getContractFactory("Skullys")
    });

    beforeEach(async function () {
        // Create some wallets with non-zero balance
        [this.alice, this.bobby, this.carly, this.dobby, this.erkle] = await ethers.getSigners()
        this.wallets = [this.alice, this.bobby, this.carly, this.dobby, this.erkle];

        // Deploy Skullys
        this.skullys = await this.Skullys.connect(this.alice).deploy()
        await this.skullys.deployed()
    });

    it("Starting balances are 0", async function () {
        let bobbyBal = await this.skullys.balanceOf(this.bobby.address)
        expect(bobbyBal).to.equal(BigNumber.from(0))
    });

    it("Team can mint before pre-sale", async function () {
        await startPreSaleLater(this.provider, this.skullys)
        let status = await this.skullys.getStatus()
        expect(status).to.equal(0)  // 0 is the enum Status.Closed

        await this.skullys.connect(this.alice).mintFreeSkully()
        let aliceBal = await this.skullys.balanceOf(this.alice.address)
        expect(aliceBal).to.equal(BigNumber.from(1))
    });

    it("In pre-sale, can mint a Skullys if whitelisted", async function () {
        await startPreSaleNow(this.provider, this.skullys)
        let status = await this.skullys.getStatus()
        expect(status).to.equal(1)  // 1 is the enum Status.PresaleStart
        await this.skullys.connect(this.alice).setManyWhiteList([this.bobby.address, this.carly.address])

        await this.skullys.connect(this.bobby).mintFreeSkully()
        let bobbyBal = await this.skullys.balanceOf(this.bobby.address)
        expect(bobbyBal).to.equal(BigNumber.from(1))
    });
    it("In public-sale, can mint a Skullys whether whitelisted or not", async function () {
        await startPublicSaleNow(this.provider, this.skullys)
        await this.skullys.connect(this.alice).setManyWhiteList([this.bobby.address, this.carly.address])

        await this.skullys.connect(this.bobby).mintFreeSkully()
        await this.skullys.connect(this.bobby).mintSkullys(1, { value: ethers.utils.parseEther("25.0") })
        await this.skullys.connect(this.dobby).mintSkullys(1, { value: ethers.utils.parseEther("25.0") })
        await this.skullys.connect(this.erkle).mintSkullys(1, { value: ethers.utils.parseEther("25.0") })
        let bobbyBal = await this.skullys.balanceOf(this.bobby.address)
        let dobbyBal = await this.skullys.balanceOf(this.dobby.address)
        let erkleBal = await this.skullys.balanceOf(this.erkle.address)
        expect(bobbyBal).to.equal(BigNumber.from(2))
        expect(dobbyBal).to.equal(BigNumber.from(1))
        expect(erkleBal).to.equal(BigNumber.from(1))
    });

});
