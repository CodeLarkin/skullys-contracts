// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;


import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "./ERC2981.sol";

// TODO confirm need for Pausable
contract Skullys is ERC721Enumerable, ERC2981, Pausable, PaymentSplitter {

    using SafeMath for uint;
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    enum Status {
        Closed,
        PresaleStart,
        PublicSaleStart
    }

    Counters.Counter private _tokenIds;

    string public PROVENANCE = "";
    string private _baseURIextended = "";

    uint constant public MAX_SKULLYS = 1000;
    uint constant public SKULLYS_PRICE = 25 ether;

    uint public maxPerTx = 5;
    uint public maxPerWallet = 5;

    uint public presaleStartTime = 1630868400; // 12pm PST
    uint public publicSaleStartTime = presaleStartTime + 9 hours; // starts 9 hours after the presale

    mapping(address => uint) public  skullysPerOwner;
    mapping(address => uint) public  freeSkullysPerOwner;

    mapping(address => bool) private isTeam;
    mapping(address => bool) private isOnWhiteList;

    // Team Addresses
    address[] private _team = [
        0xC87bf1972Dd048404CBd3FbA300b69277552C472, // 75 - Art, generative art, social media
        0x14E8F54f35eE42Cdf436A19086659B34dA6D9D47  // 25 - Dev
    ];

    // team address payout shares
    uint256[] private _team_shares = [75, 25];
    uint256 constant private ROYALTIES_PERCENTAGE = 10;

    constructor()
        ERC721("Skullys... Join the cult and grab some of the 1000 Skullys", "SKULLY")
        PaymentSplitter(_team, _team_shares)
    {
        isTeam[msg.sender] = true;
        isTeam[0xC87bf1972Dd048404CBd3FbA300b69277552C472] = true;
        isTeam[0x14E8F54f35eE42Cdf436A19086659B34dA6D9D47] = true;

        _setReceiver(address(this));
        _setRoyaltyPercentage(ROYALTIES_PERCENTAGE);
    }

    modifier onlyTeam() {
        require(isTeam[msg.sender], "Sneaky sneaky! You are not part of the team");
        _;
    }

    modifier checkRules(address _to, uint _amount) {
        require(totalSupply() < MAX_SKULLYS, "Sold out! See you on the next drop!");
        require(totalSupply().add(_amount) <= MAX_SKULLYS, "Purchase would exceed max supply of SKULLYS");
        require(_amount <= maxPerTx, "Mint exceeds max quantity");
        _;
    }

    modifier verifyFreeMint(address _to) {
        require(isOnWhiteList[_to] || isTeam[msg.sender], "Must be on the whitelist to mint for free");
        require(freeSkullysPerOwner[_to] == 0, "Can't mint more than one for free");
        require(getStatus() == Status.PresaleStart || getStatus() == Status.PublicSaleStart || isTeam[msg.sender], "Minting has not started");
        require(totalSupply() < MAX_SKULLYS, "Sold Out");
        require(skullysPerOwner[_to].add(1) <= maxPerWallet, "This mint would make your wallet exceed the maximum Skullys minted");
        _;
    }

    modifier verifyMint(address _to, uint _amount) {
        require(_amount <= maxPerTx, "Mint quantity to large");
        require(getStatus() == Status.PublicSaleStart, "Public sale has not started");
        require(SKULLYS_PRICE.mul(_amount) <= msg.value, "Didn't send enough payment");
        require(totalSupply() < MAX_SKULLYS, "Sold Out");
        require(totalSupply().add(_amount) <= MAX_SKULLYS, "Purchase would exceed max supply. Try a lower amount");
        require(skullysPerOwner[_to].add(_amount) <= maxPerWallet, "This mint would make your wallet exceed the maximum Skullys minted");
        _;
    }

    function setProvenanceHash(string memory _provenanceHash) external onlyTeam {
        PROVENANCE = _provenanceHash;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseURIextended;
    }

    function setBaseURI(string memory baseURI_) external onlyTeam {
        _baseURIextended = baseURI_;
    }

    function setMaxTx(uint _amount) external onlyTeam {
        maxPerTx = _amount;
    }
    function setMaxPerWallet(uint _amount) external onlyTeam {
        maxPerWallet = _amount;
    }

    function setManyWhiteList(address[] memory _addr) external onlyTeam {
        for(uint i = 0; i < _addr.length; i++){
            isOnWhiteList[_addr[i]] = true;
        }
    }

    function getStatus() public view returns (Status) {
        if(block.timestamp >= publicSaleStartTime) {
            return Status.PublicSaleStart;
        } else if (block.timestamp >= presaleStartTime) {
            return Status.PresaleStart;
        }
        return Status.Closed;
    }

    function setPreSaleTime(uint _newTime) public onlyTeam {
        presaleStartTime = _newTime;
        publicSaleStartTime = _newTime + 9 hours;
    }

    // TODO special check
    function mintFreeSkully() external payable verifyFreeMint(msg.sender) {
        address _to = msg.sender;

        _tokenIds.increment();
        // TODO random id?
        uint mintId = _tokenIds.current();

        _safeMint(_to, mintId);
        skullysPerOwner[_to]++;
        freeSkullysPerOwner[_to]++;
        emit SkullyMinted(mintId, _to);
    }

    function mintSkullys(uint _amount) external payable verifyMint(msg.sender, _amount) {
        address _to = msg.sender;
        for (uint i = 0; i < _amount; i++) {
            _tokenIds.increment();
            // TODO random id?
            uint mintId = _tokenIds.current();

            _safeMint(_to, mintId);
            skullysPerOwner[_to]++;
            payable(_team[0]).transfer(msg.value);  // team member 0 gets 100% of mint revenue
            emit SkullyMinted(mintId, _to);
        }
    }
    function totalSupply() public view override(ERC721Enumerable) returns (uint256) {
        return super.totalSupply();
    }

    function withdrawAll() public onlyTeam {
        for (uint i = 0; i < _team.length; i++) {
            address payable wallet = payable(_team[i]);
            release(wallet);
        }
    }

    event SkullyMinted(uint _id, address _address);
}
/**

 Art:       @yolofinancial
 Code:      @CodeLarkin    :  codelarkin.eth
 Community: @farmgoddao

**/
