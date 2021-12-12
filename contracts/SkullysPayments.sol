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

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

contract SkullysPayments is Ownable, ReentrancyGuard {

    IERC721Enumerable _skullys;

    address constant FUNERAL = 0xC87bf1972Dd048404CBd3FbA300b69277552C472;
    address constant LARKIN  = 0x14E8F54f35eE42Cdf436A19086659B34dA6D9D47;

    address[] private _team = [
        0xC87bf1972Dd048404CBd3FbA300b69277552C472, // 65 - Art, generative art, social media
        0x14E8F54f35eE42Cdf436A19086659B34dA6D9D47  // 25 - Dev
    ];

    // team address payout shares
    uint256[] private _team_shares = [65, 25];  // 65 and 25 for team, and then 2*5 for specials

    // payout shares for holders of special tokenIds
    uint256[] private _specials        = [6, 66, 69, 420, 666];
    uint256[] private _specials_shares = [2,  2,  2,   2,   2];

    constructor(address skullys_) {
        _skullys = IERC721Enumerable(skullys_);
    }

    function withdrawAll() external nonReentrant {
        require(msg.sender == owner() || msg.sender == LARKIN || msg.sender == FUNERAL, "Not part of the team");
        require(address(this).balance > 0, "Cannot withdraw, balance is empty");

        uint256 totalReceived = address(this).balance;

        for (uint i = 0; i < _team.length; i++) {
            address payable wallet = payable(_team[i]);
            uint256 payment = (totalReceived * _team_shares[i]) / 100;
            Address.sendValue(wallet, payment);
        }

        for (uint i = 0; i < _specials.length; i++) {
            address payable wallet;
            if (_skullys.totalSupply() < _specials[i]) {
                // if this special tokenId hasn't been minted yet, send payment shares to artist
                wallet = payable(_team[0]);
            } else {
                // payout holder of this special tokenId
                wallet = payable(_skullys.ownerOf(_specials[i]));
            }
            uint256 payment = (totalReceived * _specials_shares[i]) / 100;

            (bool success, ) = wallet.call{value: payment}("");
            if (!success) {
                payable(FUNERAL).call{value: payment}("");
            }
        }
    }

    function emergencyWithdraw() external nonReentrant {
        require(msg.sender == owner() || msg.sender == LARKIN || msg.sender == FUNERAL, "Not part of the team");
        require(address(this).balance > 0, "Cannot withdraw, balance is empty");

        Address.sendValue(payable(FUNERAL), (address(this).balance * 75) / 100); // 75% to Funeral
        Address.sendValue(payable(LARKIN ), address(this).balance);      // remaining to Larkin
    }

    // ensure this contract can receive payments (royalties)
    receive () external payable {}
}
/**

 Art:       @yolofinancial
 Code:      @CodeLarkin    :  codelarkin.eth
 Community: @farmgoddao
  █████▒█    ██  ███▄    █ ▓█████  ██▀███   ▄▄▄       ██▓
▓██   ▒ ██  ▓██▒ ██ ▀█   █ ▓█   ▀ ▓██ ▒ ██▒▒████▄    ▓██▒
▒████ ░▓██  ▒██░▓██  ▀█ ██▒▒███   ▓██ ░▄█ ▒▒██  ▀█▄  ▒██░
░▓█▒  ░▓▓█  ░██░▓██▒  ▐▌██▒▒▓█  ▄ ▒██▀▀█▄  ░██▄▄▄▄██ ▒██░
░▒█░   ▒▒█████▓ ▒██░   ▓██░░▒████▒░██▓ ▒██▒ ▓█   ▓██▒░██████▒
 ▒ ░   ░▒▓▒ ▒ ▒ ░ ▒░   ▒ ▒ ░░ ▒░ ░░ ▒▓ ░▒▓░ ▒▒   ▓▒█░░ ▒░▓  ░
 ░     ░░▒░ ░ ░ ░ ░░   ░ ▒░ ░ ░  ░  ░▒ ░ ▒░  ▒   ▒▒ ░░ ░ ▒  ░
 ░ ░    ░░░ ░ ░    ░   ░ ░    ░     ░░   ░   ░   ▒     ░ ░
          ░              ░    ░  ░   ░           ░  ░    ░  ░

██╗      █████╗ ██████╗ ██╗  ██╗██╗███╗   ██╗
██║     ██╔══██╗██╔══██╗██║ ██╔╝██║████╗  ██║
██║     ███████║██████╔╝█████╔╝ ██║██╔██╗ ██║
██║     ██╔══██║██╔══██╗██╔═██╗ ██║██║╚██╗██║
███████╗██║  ██║██║  ██║██║  ██╗██║██║ ╚████║
╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝
**/
