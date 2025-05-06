// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract Farmuttopia {
    IERC20 public usdt;
    address public owner;

    uint256 public pointRate = 1 * 10**5;
    uint256 public waterCost = 2 * 10**5;
    uint256 public plotExpansionPrice = 5 * 10**6;

    uint256 public seasonPool;
    uint256 public developerShare = 20; // 20% to developers
    uint256 public constant MAX_LEADERS = 50;

    enum SeedType { Common, Rare, Epic }
    enum HarvestQuality { Rotten, Poor, Good, Excellent }

    mapping(SeedType => uint256) public seedPrices;
    mapping(SeedType => uint256) public growDurations;
    mapping(SeedType => uint256) public wateringDurations;

    constructor(address _usdt) {
        usdt = IERC20(_usdt);
        owner = msg.sender;

        seedPrices[SeedType.Common] = 0.008 * 1e6;
        seedPrices[SeedType.Rare] = 0.015 * 1e6;
        seedPrices[SeedType.Epic] = 0.03 * 1e6;

        growDurations[SeedType.Common] = 1 hours;
        growDurations[SeedType.Rare] = 4 hours;
        growDurations[SeedType.Epic] = 12 hours;

        wateringDurations[SeedType.Common] = 30 minutes;
        wateringDurations[SeedType.Rare] = 1 hours;
        wateringDurations[SeedType.Epic] = 2 hours;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    struct Seed {
        uint256 plantTime;
        uint256 growDuration;
        bool watered;
        bool harvested;
        uint256 wateredAt;
        SeedType seedType;
    }

    mapping(address => Seed[]) public seeds;
    mapping(address => uint256) public points;
    mapping(address => uint256) public landSize;

    address[] public topPlayers;
    mapping(address => bool) public isPlayer;

    event SeedPlanted(address indexed user, uint256 indexed index, uint256 growDuration, SeedType seedType);
    event Watered(address indexed user, uint256 indexed index);
    event Harvested(address indexed user, uint256 indexed index, string quality, uint256 rewardPoints);
    event PointsConverted(address indexed user, uint256 points, uint256 usdtAmount);
    event LandExpanded(address indexed user, uint256 newLandSize);
    event SeasonEnded(uint256 poolDistributed);

    function buySeed(SeedType _type) external {
        uint256 price = seedPrices[_type];
        require(price > 0, "Invalid seed type");
        require(usdt.transferFrom(msg.sender, address(this), price), "Payment failed");

        seasonPool += price;

        require(seeds[msg.sender].length < landSize[msg.sender], "Not enough land");

        seeds[msg.sender].push(Seed({
            plantTime: block.timestamp,
            growDuration: growDurations[_type],
            watered: false,
            harvested: false,
            wateredAt: 0,
            seedType: _type
        }));

        emit SeedPlanted(msg.sender, seeds[msg.sender].length - 1, growDurations[_type], _type);
    }

    function water(uint256 _index) external {
        require(_index < seeds[msg.sender].length, "Invalid seed");
        Seed storage s = seeds[msg.sender][_index];
        require(!s.watered, "Already watered");
        require(!s.harvested, "Already harvested");

        require(usdt.transferFrom(msg.sender, address(this), waterCost), "Water fee failed");

        seasonPool += waterCost;

        s.watered = true;
        s.wateredAt = block.timestamp;

        emit Watered(msg.sender, _index);
    }

    function harvest(uint256 _index) external {
        require(_index < seeds[msg.sender].length, "Invalid seed");
        Seed storage s = seeds[msg.sender][_index];
        require(s.watered, "Must water before harvest");
        require(!s.harvested, "Already harvested");
        require(block.timestamp >= s.plantTime + s.growDuration, "Too early");

        require(block.timestamp >= s.wateredAt + wateringDurations[s.seedType], "Must wait after watering");

        s.harvested = true;

        uint256 rand = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, _index))) % 100;
        HarvestQuality quality;
        uint256 reward;

        if (rand < 20) {
            quality = HarvestQuality.Rotten;
            reward = 0;
        } else if (rand < 50) {
            quality = HarvestQuality.Poor;
            reward = 1;
        } else if (rand < 85) {
            quality = HarvestQuality.Good;
            reward = 3;
        } else {
            quality = HarvestQuality.Excellent;
            reward = 5;
        }

        if (reward > 0) {
            points[msg.sender] += reward;
            _updateLeaderboard(msg.sender);
        }

        emit Harvested(msg.sender, _index, _getQualityName(quality), reward);
    }

    function _updateLeaderboard(address player) internal {
        if (!isPlayer[player]) {
            topPlayers.push(player);
            isPlayer[player] = true;
        }
    }

    function _getQualityName(HarvestQuality q) internal pure returns (string memory) {
        if (q == HarvestQuality.Rotten) return "Rotten";
        if (q == HarvestQuality.Poor) return "Poor";
        if (q == HarvestQuality.Good) return "Good";
        return "Excellent";
    }

    function convertPointsToUSDT() external {
        uint256 userPoints = points[msg.sender];
        require(userPoints > 0, "No points");

        uint256 amount = userPoints * pointRate;
        require(usdt.balanceOf(address(this)) >= amount, "Not enough USDT");

        points[msg.sender] = 0;
        require(usdt.transfer(msg.sender, amount), "Transfer failed");

        emit PointsConverted(msg.sender, userPoints, amount);
    }

    function expandLand(uint256 _plots) external {
        require(_plots > 0, "Must expand at least 1");
        uint256 cost = _plots * plotExpansionPrice;
        require(usdt.transferFrom(msg.sender, address(this), cost), "Payment failed");

        seasonPool += cost;

        landSize[msg.sender] += _plots;

        emit LandExpanded(msg.sender, landSize[msg.sender]);
    }

    function endSeasonAndDistribute() external onlyOwner {
        require(topPlayers.length > 0, "No players");
        uint256 devAmount = (seasonPool * developerShare) / 100;
        uint256 prizePool = seasonPool - devAmount;

        require(usdt.transfer(owner, devAmount), "Dev transfer failed");

        // Sort and select top 50
        address[] memory sorted = _sortTopPlayers();
        uint256 totalWinners = sorted.length > MAX_LEADERS ? MAX_LEADERS : sorted.length;
        uint256 rewardPerPlayer = prizePool / totalWinners;

        for (uint256 i = 0; i < totalWinners; i++) {
            require(usdt.transfer(sorted[i], rewardPerPlayer), "Reward transfer failed");
        }

        emit SeasonEnded(prizePool);

        // Reset season
        seasonPool = 0;
        delete topPlayers;
    }

    function _sortTopPlayers() internal view returns (address[] memory) {
        address[] memory sorted = topPlayers;
        for (uint256 i = 0; i < sorted.length; i++) {
            for (uint256 j = i + 1; j < sorted.length; j++) {
                if (points[sorted[j]] > points[sorted[i]]) {
                    (sorted[i], sorted[j]) = (sorted[j], sorted[i]);
                }
            }
        }
        return sorted;
    }

    function getSeed(address user, uint256 index) external view returns (Seed memory) {
        return seeds[user][index];
    }

    function getMyPoints() external view returns (uint256) {
        return points[msg.sender];
    }

    function getLandSize(address user) external view returns (uint256) {
        return landSize[user];
    }

    function getTopPlayers() external view returns (address[] memory) {
        return _sortTopPlayers();
    }

    function setPointRate(uint256 _rate) external onlyOwner {
        pointRate = _rate;
    }

    function withdrawUSDT(uint256 amount) external onlyOwner {
        require(usdt.transfer(owner, amount), "Withdraw failed");
    }
}
