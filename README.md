# Farmuttopia Smart Contract

Farmuttopia is a blockchain-based farming game where players can plant seeds, water them, and harvest crops to earn points and rewards. The game uses USDT as its primary currency for transactions.

## Features

### Core Game Mechanics
- Plant different types of seeds (Common, Rare, Epic)
- Water plants to ensure proper growth
- Harvest crops with varying quality levels
- Earn points based on harvest quality
- Convert points to USDT rewards
- Expand your farming land

### Seed Types and Characteristics
- **Common Seeds**
  - Price: 0.008 USDT
  - Growth Duration: 1 hour
  - Watering Duration: 30 minutes

- **Rare Seeds**
  - Price: 0.015 USDT
  - Growth Duration: 4 hours
  - Watering Duration: 1 hour

- **Epic Seeds**
  - Price: 0.03 USDT
  - Growth Duration: 12 hours
  - Watering Duration: 2 hours

### Harvest Quality Levels
- Rotten (20% chance): 0 points
- Poor (30% chance): 1 point
- Good (35% chance): 3 points
- Excellent (15% chance): 5 points

### Game Economy
- Watering Cost: 0.2 USDT
- Plot Expansion Price: 5 USDT per plot
- Point Conversion Rate: 0.1 USDT per point
- Developer Share: 20% of season pool
- Maximum Leaderboard Size: 50 players

## Smart Contract Functions

### Player Functions
- `buySeed(SeedType _type)`: Purchase a new seed
- `water(uint256 _index)`: Water a planted seed
- `harvest(uint256 _index)`: Harvest a grown crop
- `convertPointsToUSDT()`: Convert earned points to USDT
- `expandLand(uint256 _plots)`: Purchase additional farming plots

### View Functions
- `getSeed(address user, uint256 index)`: Get seed details
- `getMyPoints()`: Check player's points
- `getLandSize(address user)`: Check player's land size
- `getTopPlayers()`: View leaderboard

### Admin Functions
- `endSeasonAndDistribute()`: End season and distribute rewards
- `setPointRate(uint256 _rate)`: Update point conversion rate
- `withdrawUSDT(uint256 amount)`: Withdraw USDT from contract

## Technical Details

- **Contract Version**: Solidity ^0.8.19
- **Token Standard**: ERC20 (USDT)
- **License**: MIT

## Game Flow

1. Players start with a basic land size
2. Purchase seeds using USDT
3. Water seeds within the required timeframe
4. Wait for growth duration to complete
5. Harvest crops to earn points
6. Convert points to USDT or compete for season rewards
7. Expand land to plant more seeds

## Season System

- Each season accumulates a prize pool from seed purchases and watering fees
- 20% of the pool goes to developers
- Remaining 80% is distributed among top 50 players
- Season can be ended by the contract owner to distribute rewards

## Security Features

- Owner-only functions for administrative tasks
- USDT transfer checks for all transactions
- Proper access control for critical functions
- Safe math operations (using Solidity 0.8.x)

## Getting Started

1. Ensure you have USDT tokens
2. Approve the contract to spend your USDT
3. Start by purchasing your first seed
4. Follow the growth and watering cycles
5. Harvest and earn points
6. Convert points to USDT or compete for season rewards

## Note

This contract requires USDT tokens to be approved before any transactions can be made. Make sure to approve the contract address with sufficient USDT allowance before playing.
