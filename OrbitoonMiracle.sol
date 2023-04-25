// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract OrbitoonMiracle is ERC721, Ownable {
    using SafeMath for uint256;
    uint256 public _mintPrice = 1 ether;
    uint256 private _tokenIdTracker;
    mapping(address => uint256) private _lastMintTime;
    uint256 public constant _mintCooldown = 90 days;
    address payable public _contractOwner;

    constructor() ERC721("OrbitoonMiracle", "ORM") {
        _contractOwner = payable(msg.sender);
    }

    function mint() public payable {
        uint256 price = _mintPrice;
        require(msg.value == price, "Incorrect payment amount");
        require(_lastMintTime[msg.sender] + _mintCooldown < block.timestamp, "Can only mint once every 90 days");

        uint256 tokenId = _tokenIdTracker;
        _safeMint(msg.sender, tokenId);
        _tokenIdTracker++;
        _lastMintTime[msg.sender] = block.timestamp;
        _contractOwner.transfer(msg.value);
    }

    function setMintPrice(uint256 price) public onlyOwner {
        _mintPrice = price.mul(1 ether);
    }

    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom( address from, address to, uint256 tokenId, bytes memory _data) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }
}
