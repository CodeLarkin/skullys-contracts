// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

/**
   ▄████████    ▄█   ▄█▄ ███    █▄   ▄█        ▄█       ▄██   ▄      ▄████████
  ███    ███   ███ ▄███▀ ███    ███ ███       ███       ███   ██▄   ███    ███
  ███    █▀    ███▐██▀   ███    ███ ███       ███       ███▄▄▄███   ███    █▀
  ███         ▄█████▀    ███    ███ ███       ███       ▀▀▀▀▀▀███   ███
▀███████████ ▀▀█████▄    ███    ███ ███       ███       ▄██   ███ ▀███████████
         ███   ███▐██▄   ███    ███ ███       ███       ███   ███          ███
   ▄█    ███   ███ ▀███▄ ███    ███ ███▌    ▄ ███▌    ▄ ███   ███    ▄█    ███
 ▄████████▀    ███   ▀█▀ ████████▀  █████▄▄██ █████▄▄██  ▀█████▀   ▄████████▀
**/

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./ERC2981.sol";


contract Skullys is ERC721Enumerable, ERC2981 {

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

    uint constant public MAX_SKULLYS = 8888;
    uint constant public SKULLYS_PRICE = 25 ether;

    uint public presaleStartTime = 1630868400; // 12pm PST
    uint public publicSaleStartTime = presaleStartTime + 9 hours; // starts 9 hours after the presale

    mapping(address => uint) public  freeSkullysPerOwner;

    mapping(address => bool) private isTeam;
    mapping(address => bool) private isOnWhiteList;

    // Team Addresses
    address[] private _team = [
        0xC87bf1972Dd048404CBd3FbA300b69277552C472, // 75 - Art, generative art, social media
        0x14E8F54f35eE42Cdf436A19086659B34dA6D9D47  // 25 - Dev
    ];

    // team address payout shares
    uint256[] private _team_shares = [65, 25];  // 65, 25, 2*5

    // payout shares for holders of special tokenIds
    uint256[] private _specials        = [6, 66, 420, 666, 6666];
    uint256[] private _specials_shares = [2,  2,   2,   2,    2];

    // For EIP-2981
    uint256 constant private ROYALTIES_PERCENTAGE = 10;

    constructor()
        ERC721("Skullys... Join the cult and grab some of the 1000 Skullys", "SKULLY")
    {
        isTeam[msg.sender] = true;
        isTeam[0xC87bf1972Dd048404CBd3FbA300b69277552C472] = true;
        isTeam[0x14E8F54f35eE42Cdf436A19086659B34dA6D9D47] = true;

        _setReceiver(address(this));
        _setRoyaltyPercentage(ROYALTIES_PERCENTAGE);
    }

    modifier onlyTeam() {
        require(isTeam[msg.sender], "Can't do that, you are not part of the team");
        _;
    }

    modifier verifyFreeMint(address _to) {
        require(isOnWhiteList[_to] || isTeam[msg.sender], "Must be on the whitelist to mint for free");
        require(freeSkullysPerOwner[_to] == 0, "Can't mint more than one for free");
        require(getStatus() == Status.PresaleStart || getStatus() == Status.PublicSaleStart || isTeam[msg.sender], "Minting has not started");
        require(totalSupply() < MAX_SKULLYS, "Sold out");
        _;
    }

    modifier verifyMint(address _to) {
        require(getStatus() == Status.PublicSaleStart, "Public sale has not started");
        require(SKULLYS_PRICE <= msg.value, "Didn't send enough payment");
        require(totalSupply() < MAX_SKULLYS, "Sold out");
        require(totalSupply().add(1) <= MAX_SKULLYS, "Purchase would exceed max supply");
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

    function mintFreeSkully() external payable verifyFreeMint(msg.sender) {
        address _to = msg.sender;

        _tokenIds.increment();
        uint mintId = _tokenIds.current();

        _safeMint(_to, mintId);
        freeSkullysPerOwner[_to]++;
        emit SkullyMinted(mintId, _to);
    }

    function mintSkully() external payable verifyMint(msg.sender) {
        address _to = msg.sender;

        _tokenIds.increment();
        uint mintId = _tokenIds.current();

        _safeMint(_to, mintId);
        payable(_team[0]).transfer(msg.value);  // team member 0 gets 100% of mint revenue
        emit SkullyMinted(mintId, _to);
    }

    function totalSupply() public view override(ERC721Enumerable) returns (uint256) {
        return super.totalSupply();
    }


    function _getTotalPaymentShares() internal view returns (uint256) {
        uint256 totalShares = 0;
        for (uint i = 0; i < _team.length; i++) {
            totalShares += _team_shares[i];
        }
        for (uint i = 0; i < _specials.length; i++) {
            totalShares += _specials_shares[i];
        }
        return totalShares;
    }

    function withdrawAll() public onlyTeam {
        require(address(this).balance > 0, "Cannot withdraw, balance is empty");

        uint256 totalShares = _getTotalPaymentShares();

        uint256 totalReceived = address(this).balance;

        for (uint i = 0; i < _team.length; i++) {
            address payable wallet = payable(_team[i]);
            uint256 payment = (totalReceived * _team_shares[i]) / totalShares;
            Address.sendValue(wallet, payment);
        }
        for (uint i = 0; i < _specials.length; i++) {
            address payable wallet;
            if (totalSupply() < _specials[i]) {
                // if this special tokenId hasn't been minted yet, send to owner
                wallet = payable(_team[0]);
            } else {
                wallet = payable(ownerOf(_specials[i]));
            }
            uint256 payment = (totalReceived * _specials_shares[i]) / totalShares;
            Address.sendValue(wallet, payment);
        }
    }

    // ensure this contract can receive payments (royalties)
    receive () external payable {}

    event SkullyMinted(uint _id, address _address);
}
/**

 Art:       @yolofinancial
 Code:      @CodeLarkin    :  codelarkin.eth
 Community: @farmgoddao

   ██╗      █████╗ ██████╗ ██╗  ██╗██╗███╗   ██╗
   ██║     ██╔══██╗██╔══██╗██║ ██╔╝██║████╗  ██║
   ██║     ███████║██████╔╝█████╔╝ ██║██╔██╗ ██║
   ██║     ██╔══██║██╔══██╗██╔═██╗ ██║██║╚██╗██║
   ███████╗██║  ██║██║  ██║██║  ██╗██║██║ ╚████║
   ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝

**/
