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

        await this.skullys.connect(this.alice).mintFreeSkully()
        let aliceBal = await this.skullys.balanceOf(this.alice.address)
        expect(aliceBal).to.equal(BigNumber.from(1))
    });

    it("In pre-sale, can mint a Skullys if whitelisted", async function () {
        await this.skullys.connect(this.alice).setManyWhiteList([this.bobby.address, this.carly.address])

        await this.skullys.connect(this.bobby).mintFreeSkully()
        let bobbyBal = await this.skullys.balanceOf(this.bobby.address)
        expect(bobbyBal).to.equal(BigNumber.from(1))
    });

});
