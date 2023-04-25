// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract OrbitoonWater is ERC721, Ownable {
    using SafeMath for uint256;
    uint256 private _tokenIdTracker;
    mapping(address => uint256) private _lastMintTime;
    uint256 public constant _mintCooldown = 24 hours;
    address payable public _contractOwner;

    mapping(uint256 => uint256) private _tokenTier;

    struct Tier {
        uint256 price;
        uint256 number;
    }

    mapping(uint256 => Tier) public tiers;

    constructor() ERC721("OrbitoonWater", "ORW") {
        _contractOwner = payable(msg.sender);

        // Set up the tiers
        tiers[0] = Tier({price: 0.03 ether, number: 1});
        tiers[1] = Tier({price: 0.007 ether, number: 2});
        tiers[2] = Tier({price: 0 ether, number: 3});
    }

    function mint(uint256 tier) public payable {
        require(tier < 3, "Invalid tier index");
        uint256 price = tiers[tier].price;
        require(msg.value == price, "Incorrect payment amount");
        require(
            _lastMintTime[msg.sender] + _mintCooldown < block.timestamp,
            "Can only mint once every 24 hours"
        );

        uint256 tokenId = _tokenIdTracker;
        _safeMint(msg.sender, tokenId);
        _tokenIdTracker++;
        _lastMintTime[msg.sender] = block.timestamp;
        _contractOwner.transfer(msg.value);

        // Store the tier of the token
        _tokenTier[tokenId] = tier;
    }

    function setTierPrice(uint256 tierIndex, uint256 price) public onlyOwner {
        require(tierIndex < 3, "Invalid tier index");
        tiers[tierIndex].price = price;
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );
        _safeTransfer(from, to, tokenId, _data);
    }

    function getTokenTier(uint256 tokenId) public view returns (uint256) {
        require(_exists(tokenId), "ERC721: token does not exist");
        return _tokenTier[tokenId];
    }
}