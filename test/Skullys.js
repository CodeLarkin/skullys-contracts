const { expect } = require("chai");

const { ethers, waffle } = hre;
const { BigNumber, utils } = ethers;
const { constants, expectRevert } = require('@openzeppelin/test-helpers')

describe("Test harness for Skullys", function () {
    let artist = "0xC87bf1972Dd048404CBd3FbA300b69277552C472"
    let dev    = "0x14E8F54f35eE42Cdf436A19086659B34dA6D9D47"

    // start helpers
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
    // end helpers

    before(async function () {
        this.provider = ethers.provider;
        this.Skullys   = await ethers.getContractFactory("Skullys")
    });

    beforeEach(async function () {
        // Create some wallets with non-zero balance
        [this.alice, this.bobby, this.carly, this.dobby, this.erkle] = await ethers.getSigners()
        this.wallets = [this.alice, this.bobby, this.carly, this.dobby, this.erkle];

        // Create two wallets with 0 balance
        this.provider = ethers.provider;
        this.owner0 = ethers.Wallet.createRandom()
        this.owner0.connect(this.provider)
        this.owner1 = ethers.Wallet.createRandom()
        this.owner1.connect(this.provider)

        // Deploy Skullys
        this.skullys = await this.Skullys.connect(this.alice).deploy()
        await this.skullys.deployed()
    });

    it("Check some constants", async function () {
        let maxSupply = await this.skullys.MAX_SKULLYS()
        expect(maxSupply).to.equal(BigNumber.from(8888))

        let price = await this.skullys.SKULLYS_PRICE()
        expect(price).to.equal(BigNumber.from(ethers.utils.parseEther("25.0")))
    });

    it("Starting supply and balances are 0", async function () {
        let supply = await this.skullys.totalSupply()
        expect(supply).to.equal(BigNumber.from(0))

        let bobbyBal = await this.skullys.balanceOf(this.bobby.address)
        expect(bobbyBal).to.equal(BigNumber.from(0))
    });

    it("Can't withdraw earnings (royalties) when there are none", async function () {
        await expectRevert(
            this.skullys.connect(this.alice).withdrawAll(),
            "Cannot withdraw, balance is empty"
        )
    });

    it("Can't withdraw earnings (royalties) if you aren't on the team", async function () {
        await expectRevert(
            this.skullys.connect(this.carly).withdrawAll(),
             "Can't do that, you are not part of the team"
        )
    });

    it("Can withdraw earnings (royalties) from contract", async function () {
        // alice sends some ether to the skullys contract (emulate a marketplace paying royalties to the contract address)
        await this.alice.sendTransaction({ to: this.skullys.address, value: ethers.utils.parseEther("100.0") })
        let skullysBal = await this.provider.getBalance(this.skullys.address)
        expect(skullysBal).to.equal(BigNumber.from(ethers.utils.parseEther("100")))

        // alice triggers the withrawAll function which distributes the contract balance back to the team, etc
        await this.skullys.connect(this.alice).withdrawAll()
        skullysBal = await this.provider.getBalance(this.skullys.address)

        // Make sure the contract has approximately 0 balance left
        expect(skullysBal).to.equal(BigNumber.from(ethers.utils.parseEther("0")))

        // make sure artist and dev have appropriate amounts
        let artBal = await this.provider.getBalance(artist)
        let devBal = await this.provider.getBalance(dev)
        expect(artBal).to.equal(BigNumber.from(ethers.utils.parseEther("75")))
        expect(devBal).to.equal(BigNumber.from(ethers.utils.parseEther("25")))
    });

    it("Team can mint before pre-sale", async function () {
        await startPreSaleLater(this.provider, this.skullys)
        let status = await this.skullys.getStatus()
        expect(status).to.equal(0)  // 0 is the enum Status.Closed

        await this.skullys.connect(this.alice).mintFreeSkully()
        let aliceBal = await this.skullys.balanceOf(this.alice.address)
        expect(aliceBal).to.equal(BigNumber.from(1))
    });

    it("In pre-sale, can't mint if not whitelisted", async function () {
        await startPreSaleNow(this.provider, this.skullys)
        let status = await this.skullys.getStatus()
        expect(status).to.equal(1)  // 1 is the enum Status.PresaleStart

        await expectRevert(
            this.skullys.connect(this.bobby).mintFreeSkully(),
             "Must be on the whitelist to mint for free"
        )

        let bobbyBal = await this.skullys.balanceOf(this.bobby.address)
        expect(bobbyBal).to.equal(BigNumber.from(0))
    });

    it("In pre-sale, can mint a Skully if whitelisted", async function () {
        await startPreSaleNow(this.provider, this.skullys)
        await this.skullys.connect(this.alice).setManyWhiteList([this.bobby.address, this.carly.address])

        await this.skullys.connect(this.bobby).mintFreeSkully()
        let bobbyBal = await this.skullys.balanceOf(this.bobby.address)
        expect(bobbyBal).to.equal(BigNumber.from(1))
    });

    it("In pre-sale, can't mint >1 Skullys", async function () {
        await startPreSaleNow(this.provider, this.skullys)
        await this.skullys.connect(this.alice).setManyWhiteList([this.bobby.address, this.carly.address])

        await this.skullys.connect(this.bobby).mintFreeSkully()
        await expectRevert(
            this.skullys.connect(this.bobby).mintFreeSkully(),
            "Can't mint more than one for free"
        )
        let bobbyBal = await this.skullys.balanceOf(this.bobby.address)
        expect(bobbyBal).to.equal(BigNumber.from(1))
    });

    it("In public-sale, can mint Skullys (multiple) whether whitelisted or not", async function () {
        await startPublicSaleNow(this.provider, this.skullys)
        await this.skullys.connect(this.alice).setManyWhiteList([this.bobby.address, this.carly.address])

        // mint some
        await this.skullys.connect(this.bobby).mintFreeSkully()
        await this.skullys.connect(this.bobby).mintSkully({ value: ethers.utils.parseEther("25.0") })
        await this.skullys.connect(this.dobby).mintSkully({ value: ethers.utils.parseEther("25.0") })
        await this.skullys.connect(this.dobby).mintSkully({ value: ethers.utils.parseEther("25.0") })
        await this.skullys.connect(this.erkle).mintSkully({ value: ethers.utils.parseEther("25.0") })

        // check balances
        let bobbyBal = await this.skullys.balanceOf(this.bobby.address)
        let dobbyBal = await this.skullys.balanceOf(this.dobby.address)
        let erkleBal = await this.skullys.balanceOf(this.erkle.address)
        expect(bobbyBal).to.equal(BigNumber.from(2))
        expect(dobbyBal).to.equal(BigNumber.from(2))
        expect(erkleBal).to.equal(BigNumber.from(1))
    });

    // TODO
    //    can't mint in presale unless whitelisted
    //    can't mint >1 in presale
    //    royalties work
    //    special owners get royalties

});
