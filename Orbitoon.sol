// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./OrbitoonMiracle.sol";
import "./OrbitoonWater.sol";
import "./OrbitoonFood.sol";

contract Orbitoon is ERC721, Ownable {
  using SafeMath for uint256;

  struct OrbitoonStatus {
    uint256 experience;
    uint256 food;
    uint256 water;
    uint256 lastFedTime;
    uint256 lastWateredTime;
    uint256 lastResurrectedTime;
    bool special_1;
    bool special_2;
    bool special_3;
  }

  mapping(uint256 => mapping(string => uint256)) private _attributes;
  mapping(uint256 => OrbitoonStatus) private _status;
  mapping(uint256 => string) private _tokenURIs;
  mapping(address => uint256[]) private _ownedTokens;
  mapping(uint256 => uint256) private _ownedTokensIndex;
  mapping(uint256 => address) private _tokenOwners;
  mapping(uint256 => address) private _tokenApprovals;
  mapping(address => mapping(address => bool)) private _operatorApprovals;
  mapping(address => uint256) private _walletTokenCount;


  string public _name;
  string public _symbol;
  uint256 public constant MAX_NFTS_PER_WALLET = 10;
  uint256 public _mintPrice = 0.065 ether;
  uint256 public _totalSupply;
  uint256 public _maxSupply;
  uint256 private _nextTokenId;
  uint256 private _foodTier1 = 30;
  uint256 private _foodTier2 = 7;
  uint256 private _foodTier3 = 1;
  uint256 private _waterTier1 = 30;
  uint256 private _waterTier2 = 7;
  uint256 private _waterTier3 = 1;
  address payable private _contractOwner;
  address private _contractManager;
  OrbitoonMiracle private _miracleContract;
  OrbitoonFood private _foodContract;
  OrbitoonWater private _waterContract;

  constructor(
    string memory __name,
    string memory __symbol,
    address miracleContractAddress,
    address foodContractAddress,
    address waterContractAddress
  ) ERC721(__name, __symbol) {
    _contractOwner = payable(_msgSender());
    _contractManager = _msgSender();
    _name = __name;
    _symbol = __symbol;
    _totalSupply = 0;
    _nextTokenId = 0;
    _maxSupply = 1000;
    _miracleContract = OrbitoonMiracle(miracleContractAddress);
    _foodContract = OrbitoonFood(foodContractAddress);
    _waterContract = OrbitoonWater(waterContractAddress);
  }

  function _setAttribute(uint256 tokenId, string memory attribute, uint256 value) private {
    require(_exists(tokenId), "ERC721: token does not exist");
    require(_tokenOwners[tokenId] == _msgSender(), "ERC721: not owner yet");
    _attributes[tokenId][attribute] = value;
  }

  function _assignRandomAttributes(uint256 tokenId) private {
    uint256 randomNumber = block.prevrandao;
    _setAttribute(tokenId, "friendliness", uint8(uint256(keccak256(abi.encodePacked(block.timestamp - 10, randomNumber, tokenId))) % 5));
    _setAttribute(tokenId, "intelligence", uint8(uint256(keccak256(abi.encodePacked(block.timestamp - 11, randomNumber, tokenId))) % 5));
    _setAttribute(tokenId, "curiosity", uint8(uint256(keccak256(abi.encodePacked(block.timestamp - 2, randomNumber, tokenId))) % 5));
    _setAttribute(tokenId, "playfulness", uint8(uint256(keccak256(abi.encodePacked(block.timestamp - 36, randomNumber, tokenId))) % 5));
    _setAttribute(tokenId, "empathy", uint8(uint256(keccak256(abi.encodePacked(block.timestamp - 4, randomNumber, tokenId))) % 5));
  }

  function awardXp(uint256 tokenId, uint256 experience) public {
    require(_exists(tokenId), "ERC721: token does not exist");
    require(
      _contractManager == _msgSender(),
      "ERC721: only manager contract can award xp"
    );

    _status[tokenId].experience = _status[tokenId].experience + experience;
  }

  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    require(_exists(tokenId), "ERC721: token does not exist");
    return _tokenURIs[tokenId];
  }

  function setTokenURI(uint256 tokenId, string memory _tokenURI) public onlyOwner {
    require(_exists(tokenId), "ERC721: token does not exist");
    _tokenURIs[tokenId] = _tokenURI;
  }

  function setContractManager(address newManager) public onlyOwner {
    _contractManager = newManager;
  }

  function setMintPrice(uint256 price) public onlyOwner {
    _mintPrice = price.mul(1 ether);
  }

  function balanceOf(
    address owner
  ) public view virtual override returns (uint256) {
    require(
      owner != address(0),
      "ERC721: balance query for the zero address"
    );

    return _ownedTokens[owner].length;
  }

  function tokenOfOwnerByIndex(
    address owner,
    uint256 index
  ) public view virtual returns (uint256) {
    require(
      index < balanceOf(owner),
      "ERC721Enumerable: owner index out of bounds"
    );

    return _ownedTokens[owner][index];
  }

  function getStatus(
    uint256 tokenId
  ) public view returns (OrbitoonStatus memory) {
    require(_exists(tokenId), "ERC721: token does not exist");
    return _status[tokenId];
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

  function approve(address to, uint256 tokenId) public virtual override {
    address owner = ownerOf(tokenId);
    require(to != owner, "ERC721: approval to current owner");

    require(
      _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
      "ERC721: approve caller is not owner nor approved for all"
    );

    _tokenApprovals[tokenId] = to;
    emit Approval(owner, to, tokenId);
  }

  function setApprovalForAll(
    address operator,
    bool approved
  ) public virtual override {
    require(operator != _msgSender(), "ERC721: approve to caller");

    _operatorApprovals[_msgSender()][operator] = approved;
    emit ApprovalForAll(_msgSender(), operator, approved);
  }

  function getApproved(
    uint256 tokenId
  ) public view virtual override returns (address) {
    require(
      _exists(tokenId),
      "ERC721: approved query for nonexistent token"
    );

    return _tokenApprovals[tokenId];
  }

  function isApprovedForAll(
    address owner,
    address operator
  ) public view virtual override returns (bool) {
    return _operatorApprovals[owner][operator];
  }


  function mintMultiple(uint256 _amount) public payable {
    if (_nextTokenId >= 25) {
      require(_amount > 0 && _amount <= 10, "Amount should be between 1 and 10.");
      require(msg.value == _mintPrice.mul(_amount), "Incorrect amount of ether sent");
    }

    if(msg.sender != _contractOwner) {
      require(_walletTokenCount[msg.sender] + _amount <= MAX_NFTS_PER_WALLET, "Exceeds maximum NFTs per wallet");
    }

    for (uint256 i = 0; i < _amount; i++) {
      mint();
    }
  }

  function mint() public payable {
    uint256 randomNumber = block.prevrandao;
    require(_nextTokenId <= _maxSupply, "Max supply reached");

    if(msg.sender != _contractOwner) {
      require(_walletTokenCount[msg.sender] + 1 <= MAX_NFTS_PER_WALLET, "Exceeds maximum NFTs per wallet");
    }


    if (_nextTokenId < 25) {
      require(
        _msgSender() == _contractOwner,
        "First 25 mints reserved to treasury"
      );
    }

    uint256 tokenId = _nextTokenId;
    _mint(_msgSender(), tokenId);
    require(_exists(tokenId), "Token not created");

    _status[tokenId].food = 30;
    _status[tokenId].water = 30;
    _status[tokenId].lastFedTime = block.timestamp;
    _status[tokenId].lastWateredTime = block.timestamp;

    _status[tokenId].special_1 = tokenId < 25; // 100% chance of rarity max tier
    _status[tokenId].special_3 = tokenId > 24 && uint8(uint256(keccak256(abi.encodePacked(block.timestamp + 7,randomNumber,tokenId))) % 20) == 13; // 5% chance of minting rarity lower tier
    _status[tokenId].special_2 = tokenId > 24 && !_status[tokenId].special_3 && uint8(uint256(keccak256(abi.encodePacked(block.timestamp + 2, randomNumber, tokenId))) % 100) == 69; // 1% chance of minting rarity mid tier

    _ownedTokens[_msgSender()].push(tokenId);
    _tokenOwners[tokenId] = _msgSender();
    _ownedTokensIndex[tokenId] = _ownedTokens[_msgSender()].length - 1;
    _nextTokenId++;
    uint256 _oldSupply = _totalSupply;
    _totalSupply++;
    require(_oldSupply != _totalSupply, "Error minting token");
    _walletTokenCount[msg.sender]++;
    _assignRandomAttributes(tokenId);
    _tokenURIs[tokenId] = "https://ipfs.io/ipfs/QmS2uG6SDTCJVsHrnpY2zDpTgB5NtB8ypGWqBoyQhq6sKW?filename=unrevealedMetadata.json";
    _contractOwner.transfer(msg.value);
  }

  function feed(uint256 tokenId, uint256 foodTokenId) public {
    require(_exists(tokenId), "ERC721: token does not exist");
    require(_tokenOwners[tokenId] == _msgSender(), "ERC721: not owner");
    require(
      _foodContract.ownerOf(foodTokenId) == _msgSender(),
      "ERC721: food token not owned by sender"
    );

    uint256 foodLeft = getFoodLeft(tokenId);
    require(foodLeft > 0, "ERC721: Orbitoon is dead");

    uint256 tier = OrbitoonFood(owner()).getTokenTier(tokenId);
    uint256 refillAmount = 0;
    if (tier == 0) {
      refillAmount = 30;
    } else if (tier == 1) {
      refillAmount = 7;
    } else if (tier == 2) {
      refillAmount = 1;
    }

    if (foodLeft < 180) {
      uint256 newFood = foodLeft + refillAmount;
      if (newFood > 180) {
        newFood = 180;
      }
      _status[tokenId].food = uint8(newFood);
      _status[tokenId].lastFedTime = block.timestamp;

      // Burn token
      _foodContract.safeTransferFrom(
        _msgSender(),
        address(0),
        foodTokenId
      );
    }
  }

  function water(uint256 tokenId, uint256 waterTokenId) public {
    require(_exists(tokenId), "ERC721: token does not exist");
    require(_tokenOwners[tokenId] == _msgSender(), "ERC721: not owner");
    require(
      _waterContract.ownerOf(waterTokenId) == _msgSender(),
      "ERC721: water token not owned by sender"
    );

    uint256 waterLeft = getWaterLeft(tokenId);
    require(waterLeft > 0, "ERC721: Orbitoon is dead");

    uint256 tier = OrbitoonFood(owner()).getTokenTier(tokenId);
    uint256 refillAmount = 0;
    if (tier == 0) {
      refillAmount = 30;
    } else if (tier == 1) {
      refillAmount = 7;
    } else if (tier == 2) {
      refillAmount = 1;
    }

    if (waterLeft < 180) {
      uint256 newWater = waterLeft + refillAmount;
      if (newWater > 180) {
        newWater = 180;
      }
      _status[tokenId].water = uint8(newWater);
      _status[tokenId].lastWateredTime = block.timestamp;

      // Burn token
      _waterContract.safeTransferFrom(
        _msgSender(),
        address(0),
        waterTokenId
      );
    }
  }

  function getWaterLeft(uint256 tokenId) public view returns (uint256) {
    require(_exists(tokenId), "ERC721: token does not exist");

    uint256 lastWateredTime = _status[tokenId].lastWateredTime;
    uint256 __water = _status[tokenId].water;

    if (__water == 0) {
      return 0;
    } else {
      uint256 daysSinceLastWatered = (block.timestamp - lastWateredTime) / (24 * 3600);
      uint256 waterLeft = __water > daysSinceLastWatered ? __water - daysSinceLastWatered : 0;

      return waterLeft;
    }
  }

  function getFoodLeft(uint256 tokenId) public view returns (uint256) {
    require(_exists(tokenId), "ERC721: token does not exist");

    uint256 lastFedTime = _status[tokenId].lastFedTime;
    uint256 __food = _status[tokenId].food;

    if (__food == 0) {
      return 0;
    } else {
      uint256 daysSinceLastFed = (block.timestamp - lastFedTime) / (24 * 3600);
      uint256 foodLeft = __food > daysSinceLastFed ? __food - daysSinceLastFed : 0;

      return foodLeft;
    }
  }

  function resurrect(uint256 tokenId, uint256 miracleTokenId) public {
    require(_exists(tokenId), "ERC721: token does not exist");
    require(_tokenOwners[tokenId] == _msgSender(), "ERC721: not owner");
    require(
      _miracleContract.ownerOf(miracleTokenId) == _msgSender(),
      "ERC721: miracle token not owned by sender"
    );
    uint256 __water = _status[tokenId].water;
    uint256 __food = _status[tokenId].food;
    require(__water == 0, "ERC721: Orbitoon is not dead");
    require(__food == 0, "ERC721: Orbitoon is not dead");

    // Update the water and food status
    _status[tokenId].water = uint8(30);
    _status[tokenId].food = uint8(30);
    _status[tokenId].lastResurrectedTime = block.timestamp;

    // Transfer the miracle token to the contract owner
    _miracleContract.safeTransferFrom(
      _msgSender(),
      address(0),
      miracleTokenId
    );
  }
}
