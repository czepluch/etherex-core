# Etherex Protocol Invariants Mapping

## Executive Overview

Etherex is a concentrated liquidity DEX implementing an x(3,3) governance model built on the Linea network. This document identifies the **most critical** protocol-wide invariants that must hold true to maintain security and solvency.

**Check Difficulty Legend:**

- **EASY**: Simple require statements or basic state checks
- **MEDIUM**: Cross-function or single-contract state validation
- **HARD**: Cross-contract state consistency or complex calculations
- **VERY HARD**: Intra-transaction state changes or external dependencies

**Verification Status Legend:**

- **VERIFIED**: Enforced by smart contract logic (require statements, modifiers, etc.)
- **UNVERIFIED**: Not enforced by contracts, requires external monitoring

## 1. Token Supply and Conservation (CRITICAL)

### 1.1 Total REX supply must never exceed 1,000,000,000 tokens

- **Contracts:** Etherex.sol, Minter.sol
- **Why Critical:** Prevents inflation attacks
- **Check Difficulty:** EASY - Simple require statement in mint function
- **Verification Status:** VERIFIED - Enforced by `require(totalSupply + amount <= MAX_SUPPLY)` in mint function

### 1.2 Total xREX in circulation = REX locked + accumulated rebases - distributed exit penalties

- **Formula:** `xREX_total = REX_locked + rebases - (0.5 × early_exits)`
- **Contracts:** xREX staking contract, Voter.sol
- **Why Critical:** Prevents token creation/destruction exploits
- **Check Difficulty:** HARD - Requires reading state from multiple contracts
- **Verification Status:** UNVERIFIED - No single contract enforces this relationship

## 2. AMM Mathematical Invariants (CRITICAL)

### 2.1 Price at any tick i must equal 1.0001^i

- **Formula:** `price = (sqrtPrice / 2^96)^2 = 1.0001^tick`
- **Contracts:** RamsesV3Pool.sol
- **Why Critical:** Violation breaks price discovery
- **Check Difficulty:** MEDIUM - Mathematical validation in price calculations
- **Verification Status:** VERIFIED - Enforced by mathematical calculations in pool logic

### 2.2 Total active liquidity must equal sum of individual positions within current price range

- **Formula:** `L_total = Σ L_i where tick_lower_i ≤ currentTick ≤ tick_upper_i`
- **Contracts:** RamsesV3Pool.sol
- **Why Critical:** Incorrect liquidity calculations could lead to pool drainage
- **Check Difficulty:** HARD - Requires iterating through all positions
- **Verification Status:** VERIFIED - Enforced by tick bitmap and liquidity tracking

### 2.3 For stable pairs: k = xy(x² + y²) must be preserved; for volatile pairs: k = x × y must be preserved

- **Contracts:** Pair.sol
- **Why Critical:** Maintains AMM pricing integrity
- **Check Difficulty:** MEDIUM - Mathematical validation in swap functions
- **Verification Status:** VERIFIED - Enforced by swap calculations in Pair.sol

## 3. Fee Distribution (CRITICAL)

### 3.1 If pool has gauge: 100% fees → xREX holders; If no gauge: 95% → LPs, 5% → protocol

- **Contracts:** FeeCollector.sol, Pool contracts
- **Why Critical:** Ensures correct revenue distribution
- **Check Difficulty:** MEDIUM - State validation in fee distribution functions
- **Verification Status:** VERIFIED - Enforced by fee routing logic in contracts

### 3.2 Sum of collected fees = total generated fees - protocol fees

- **Formula:** `Σ(feesBelowTick + feesAboveTick) + protocolFees = totalGeneratedFees`
- **Contracts:** Pool contracts, FeeCollector.sol
- **Why Critical:** Prevents fee loss or double collection
- **Check Difficulty:** HARD - Requires cross-contract fee tracking
- **Verification Status:** UNVERIFIED - No mechanism to verify fee accounting across contracts

### 3.3 Dynamic fees must remain within [0.0001%, 50%] range

- **Contracts:** Pool fee management
- **Why Critical:** Prevents excessive fee extraction
- **Check Difficulty:** EASY - Simple bounds checking in fee setter functions
- **Verification Status:** VERIFIED - Enforced by bounds checking in fee setters

## 4. Governance and Voting (CRITICAL)

### 4.1 Total vote weight across all gauges must equal total staked xREX

- **Formula:** `Σ(vote_weights_all_gauges) = total_staked_xREX`
- **Contracts:** Voter.sol, GaugeV3.sol
- **Why Critical:** Prevents vote inflation
- **Check Difficulty:** HARD - Requires iterating through all gauges
- **Verification Status:** UNVERIFIED - No mechanism to verify vote weight consistency

### 4.2 Each gauge receives emissions strictly proportional to its vote share

- **Formula:** `gauge_emissions = (gauge_votes / total_votes) × weekly_emissions`
- **Contracts:** Voter.sol
- **Why Critical:** Ensures fair reward distribution
- **Check Difficulty:** MEDIUM - Mathematical validation in emission distribution
- **Verification Status:** VERIFIED - Enforced by emission calculation logic

## 5. x(3,3) Game Theory (CRITICAL)

### 5.1 100% of early exit penalties must be redistributed to remaining xREX stakers proportionally

- **Formula:** `rebase_per_staker = (total_penalties × staker_share) / total_active_shares`
- **Contracts:** VoteModule.sol
- **Why Critical:** Prevents value leakage and maintains anti-dilution mechanism
- **Check Difficulty:** HARD - Complex calculation across all stakers
- **Verification Status:** VERIFIED - Enforced by rebase distribution logic

### 5.2 Exit penalties follow x(3,3) schedule: 0% (early), 50% (middle period), 0% (after lock)

- **Contracts:** xREX staking contract
- **Why Critical:** Ensures predictable exit conditions and prevents penalty manipulation
- **Check Difficulty:** MEDIUM - Time-based validation in exit functions
- **Verification Status:** VERIFIED - Enforced by time-based penalty logic

### 5.3 REX33:xREX redemption ratio must always increase (never decrease)

- **Formula:** `redemption_ratio = (underlying_xREX + rewards) / REX33_supply`
- **Contracts:** REX33 token contract
- **Why Critical:** Ensures holders never lose value through compounding
- **Check Difficulty:** MEDIUM - State validation in redemption functions
- **Verification Status:** UNVERIFIED - No mechanism to enforce ratio monotonicity

## 6. Economic Security (CRITICAL)

### 6.1 Sum of all token balances = sum of user positions + protocol reserves

- **Formula:** `Σ(token_balances) = Σ(user_positions) + protocol_reserves`
- **Contracts:** All pool contracts
- **Why Critical:** Prevents fund drainage through accounting errors
- **Check Difficulty:** HARD - Requires reading all pool states
- **Verification Status:** UNVERIFIED - No cross-contract balance verification

### 6.2 LP shares must represent proportional claim on underlying assets

- **Formula:** `user_assets = (user_shares / total_shares) × total_assets`
- **Contracts:** LP token contracts, pools
- **Why Critical:** Maintains fair ownership representation
- **Check Difficulty:** MEDIUM - Mathematical validation in LP functions
- **Verification Status:** VERIFIED - Enforced by LP mint/burn calculations

## 7. Access Control (CRITICAL)

### 7.1 Critical protocol changes require timelock approval

- **Contracts:** AccessHub.sol, protocol admin functions
- **Why Critical:** Prevents single point of failure
- **Check Difficulty:** EASY - Modifier validation on admin functions
- **Verification Status:** VERIFIED - Enforced by `timelocked` modifier

### 7.2 Admins/owners must never be changed and then changed back in the same transaction

- **Contracts:** AccessHub.sol, all admin functions
- **Why Critical:** Prevents intra-transaction ownership manipulation attacks
- **Check Difficulty:** HARD - Requires monitoring intra-transaction ownership changes
- **Verification Status:** UNVERIFIED - No mechanism to verify ownership changes

### 7.3 No single address can hold multiple critical roles simultaneously

- **Contracts:** AccessHub.sol
- **Why Critical:** Prevents excessive centralization and single points of failure
- **Check Difficulty:** MEDIUM - Role overlap validation
- **Verification Status:** UNVERIFIED - Treasury currently holds multiple roles

### 7.4 Timelock delay must not be reduced below minimum threshold

- **Contracts:** TimeLock.sol
- **Why Critical:** Ensures adequate governance delay for security
- **Check Difficulty:** MEDIUM - Timelock parameter validation
- **Verification Status:** UNVERIFIED - No minimum delay enforcement

### 7.5 Emergency functions must not bypass timelock requirements

- **Contracts:** AccessHub.sol, emergency functions
- **Why Critical:** Prevents emergency functions from being used as backdoors
- **Check Difficulty:** MEDIUM - Function modifier validation
- **Verification Status:** UNVERIFIED - No verification of emergency function restrictions

## 8. Cross-Contract State Consistency (CRITICAL)

### 8.1 LP positions staked in gauges must match on-chain position state

- **Contracts:** GaugeV3.sol, NonfungiblePositionManager.sol
- **Why Critical:** Prevents double-spending of liquidity rewards
- **Check Difficulty:** HARD - Cross-contract position validation
- **Verification Status:** UNVERIFIED - No mechanism to verify position consistency

### 8.2 Pool gauge status must match fee distribution configuration

- **Contracts:** FeeCollector.sol, Voter.sol
- **Why Critical:** Ensures correct fee routing
- **Check Difficulty:** MEDIUM - Cross-contract state validation
- **Verification Status:** UNVERIFIED - No mechanism to verify fee-gauge consistency

## 9. Price Deviation Protection (CRITICAL)

### 9.1 Current price must not deviate more than 5% from TWAP over 1 hour

- **Formula:** `|current_price - twap_1h| / twap_1h ≤ 0.05`
- **Contracts:** Pair.sol, RamsesV3Pool.sol
- **Why Critical:** Prevents oracle manipulation and extreme price movements
- **Check Difficulty:** MEDIUM - Oracle calculation and comparison
- **Verification Status:** UNVERIFIED - No deviation limits enforced in contracts

### 9.2 Price of same token pair across different pools must not deviate more than 3%

- **Formula:** `|price_pool1 - price_pool2| / min(price_pool1, price_pool2) ≤ 0.03`
- **Contracts:** All pool contracts
- **Why Critical:** Prevents arbitrage exploitation and ensures price discovery integrity
- **Check Difficulty:** HARD - Cross-pool price comparison
- **Verification Status:** UNVERIFIED - No cross-pool price monitoring

### 9.3 Oracle observations must be recorded at least every 30 minutes for legacy pairs

- **Formula:** `block.timestamp - last_observation_timestamp ≤ 1800`
- **Contracts:** Pair.sol
- **Why Critical:** Ensures oracle data freshness and prevents stale price feeds
- **Check Difficulty:** EASY - Timestamp validation in oracle functions
- **Verification Status:** VERIFIED - Enforced by TWAP observation logic

### 9.4 Single swap price impact must not exceed 10% for any trade size

- **Formula:** `|price_before - price_after| / price_before ≤ 0.10`
- **Contracts:** All pool contracts
- **Why Critical:** Prevents large trades from manipulating prices excessively
- **Check Difficulty:** MEDIUM - Price impact calculation in swap functions
- **Verification Status:** UNVERIFIED - No price impact limits enforced

### 9.5 Pools must maintain minimum liquidity for oracle reliability

- **Formula:** `total_liquidity ≥ minimum_liquidity_threshold`
- **Contracts:** All pool contracts
- **Why Critical:** Ensures oracle manipulation resistance
- **Check Difficulty:** EASY - Simple liquidity threshold validation

## Additional Security Concerns

- No tests in the repo
- Repo doesn't compile. Lots of missing interfaces and libraries
- No guide in docs on how to build or run the project
- Contracts are verified on etherscan, but there's not a version in the repo that matches
- The [audit linked of Shadow Exchange](https://diligence.consensys.io/audits/2024/08/ramses-v3/) mentions [a commit in a repository](https://github.com/RamsesExchange/Ramses-V3/commit/061c142c5f53e4d3d19d9caf8b093a837062cc17) that is no longer available
- The [Etherex Team Multisig](https://lineascan.build/address/0xde4B22Eb9F9c2C55e72e330C87663b28e9d388f7#readProxyContract) is a 1/3 multisig

## Missing Cheatcodes/Functionality

- More flexible ownership checks for contracts
- Consider increasing assertion gas limit (should be easy, so let's only do it if we run into limits)

## Pseudo Assertions for Critical Unverified Invariants

### 1. x(3,3) Cross-Contract Conservation

Sum of mappings is a hard open problem. Look further into if we can use the induction pattern to verify this invariant in an assertion.

```solidity
contract X33ConservationAssertion is Assertion {
    function triggers() external view override {
        // Need to find out when to trigger
    }
    
    function assertion_validateX33Conservation() external view override {
        // Need to initialize these in constructor:
        // IVoter public voter;
        // IXRex public xRex;
        // IREX33 public rex33;

        IAccessHub public accessHub; // Assertion Adopter

        // Get REX locked in voter
        uint256 rexInVoter = voter.totalREXLocked();
        
        // Get underlying REX in REX33 contract
        uint256 rexInREX33 = rex33.underlyingREX();
        
        // Get total xREX supply and accumulated rebases
        uint256 totalXREXSupply = xRex.totalSupply();
        uint256 accumulatedRebases = xRex.accumulatedRebases();
        
        // Calculate total xREX claims
        uint256 totalXREXClaims = totalXREXSupply + accumulatedRebases;
        
        // Verify conservation: REX in voter + REX in REX33 = total xREX claims
        require(
            rexInVoter + rexInREX33 == totalXREXClaims,
            "X33_CONSERVATION_VIOLATION"
        );
    }
}
```

### 2. Fee Distribution Completeness

This is probably going to be difficult to do combined. It might be possible if we do it per contract and verify that they all have correct accounting. It could get expensive though.

```solidity
// Phylax Credible Layer Assertion
contract FeeDistributionAssertion is Assertion {
    IAccessHub public accessHub;
    IFeeCollector public feeCollector;
    
    constructor(address _accessHub) {
        accessHub = IAccessHub(_accessHub);
        feeCollector = accessHub.feeCollector();
    }
    
    function triggers() external view override {
        // Need to find out when to trigger
    }
    
    function assertion_validateFeeDistribution() external view override {
        // Get total fees distributed to xREX holders
        uint256 xREXFees = feeCollector.totalDistributedToXREX();
        
        // Get total fees distributed to LPs
        uint256 lpFees = feeCollector.totalDistributedToLPs();
        
        // Get protocol fees collected
        uint256 protocolFees = feeCollector.totalProtocolFees();
        
        // Get total fees generated across all pools
        uint256 totalFeesGenerated = feeCollector.totalFeesGenerated();
        
        // Verify fee distribution completeness
        require(
            xREXFees + lpFees + protocolFees == totalFeesGenerated,
            "FEE_DISTRIBUTION_INCOMPLETE"
        );
    }
}
```

### 3. Gauge-Pool State Consistency

Again verifying sums across contracts is an open problem. Even without doing it accross contracts.
We can probably to this one by verifying on a per user basis if changes happen, but it's not viable to check this for all users for every transaction.

```solidity
// Phylax Credible Layer Assertion
contract GaugePoolConsistencyAssertion is Assertion {
    IAccessHub public accessHub;
    IVoter public voter;
    
    constructor(address _accessHub) {
        accessHub = IAccessHub(_accessHub);
        voter = accessHub.voter();
    }
    
    function triggers() external view override {
        // Need to find out when to trigger
    }
    
    function assertion_validateGaugePoolConsistency() external view override {
        // Get all gauges from voter
        address[] memory gauges = voter.getAllGauges();
        
        for (uint i = 0; i < gauges.length; i++) {
            address gauge = gauges[i];
            address pool = voter.poolForGauge(gauge);
            
            if (voter.isAlive(gauge)) {
                // If gauge is alive, pool should have 0% protocol fee (all fees to xREX)
                uint24 feeProtocol = IRamsesV3Pool(pool).feeProtocol();
                require(feeProtocol == 0, "GAUGE_ALIVE_BUT_FEES_NOT_TO_XREX");
                
                // Verify gauge state matches voter state
                require(
                    GaugeV3(gauge).isAlive() == voter.isAlive(gauge),
                    "GAUGE_STATE_MISMATCH"
                );
            }
        }
    }
}
```

### 4. Price Deviation Monitoring

This should be doable by checking the price of pairs against each other.

```solidity
// Phylax Credible Layer Assertion
contract PriceDeviationAssertion is Assertion {
    IAccessHub public accessHub;
    IRamsesV3Factory public v3Factory;
    IPairFactory public pairFactory;
    
    uint256 public constant MAX_DEVIATION_BPS = 300; // 3%
    
    constructor(address _accessHub) {
        accessHub = IAccessHub(_accessHub);
        v3Factory = accessHub.ramsesV3PoolFactory();
        pairFactory = accessHub.poolFactory();
    }
    
    function triggers() external view override {
        // Need to find out when to trigger
    }
    
    function assertion_validatePriceDeviation() external view override {
        // Get all V3 pools for common token pairs
        address[] memory v3Pools = getV3PoolsForCommonPairs();
        
        for (uint i = 0; i < v3Pools.length; i++) {
            address[] memory pools = getPoolsForSamePair(v3Pools[i]);
            
            if (pools.length > 1) {
                uint256 price1 = getPriceFromPool(pools[0]);
                uint256 price2 = getPriceFromPool(pools[1]);
                
                // Calculate deviation in basis points
                uint256 deviation = calculateDeviation(price1, price2);
                
                require(
                    deviation <= MAX_DEVIATION_BPS,
                    "PRICE_DEVIATION_TOO_HIGH"
                );
            }
        }
    }
    
    function calculateDeviation(uint256 price1, uint256 price2) internal pure returns (uint256) {
        if (price1 == 0 || price2 == 0) return 0;
        
        uint256 minPrice = price1 < price2 ? price1 : price2;
        uint256 maxPrice = price1 > price2 ? price1 : price2;
        
        return ((maxPrice - minPrice) * 10000) / minPrice;
    }
    
    function getPriceFromPool(address pool) internal view returns (uint256) {
        // Implementation depends on pool type (V2 vs V3)
        if (v3Factory.isPairV3(pool)) {
            return getV3PoolPrice(pool);
        } else {
            return getV2PoolPrice(pool);
        }
    }
    
    function getV3PoolPrice(address pool) internal view returns (uint256) {
        // Get current sqrt price from V3 pool
        (uint160 sqrtPriceX96,,,,,,) = IRamsesV3Pool(pool).slot0();
        return uint256(sqrtPriceX96) * uint256(sqrtPriceX96) * 1e18 >> 192;
    }
    
    function getV2PoolPrice(address pool) internal view returns (uint256) {
        // Get reserves from V2 pool
        (uint112 reserve0, uint112 reserve1,) = IPair(pool).getReserves();
        return (uint256(reserve1) * 1e18) / uint256(reserve0);
    }
}
```

## Access Control Analysis

### **Critical Admin Accounts & Powers**

#### **1. Treasury (Multisig) - HIGHEST POWER**

- **Role**: `DEFAULT_ADMIN_ROLE`, `SWAP_FEE_SETTER`, `PROTOCOL_OPERATOR`
- **Powers**:
  - Can reinitialize all core contracts (`reinit()`)
  - Can set fee collectors and factories
  - Can create fee distributors
  - Can set voter addresses in factories
  - Can update fee distributor for gauges
  - Can set treasury addresses in all contracts
  - Can set V3 factory implementation
  - **CRITICAL**: Can change all contract references without timelock

#### **2. Timelock - CRITICAL SAFEGUARD**

- **Role**: `DEFAULT_ADMIN_ROLE`
- **Powers**:
  - Can execute arbitrary calls (`execute()`)
  - Can change timelock address (`setNewTimelock()`)
  - Can set cooldown exemptions
  - Can change vote module cooldown
  - **CRITICAL**: Can execute any payload on any contract

#### **3. PROTOCOL_OPERATOR Role - HIGH POWER**

- **Default Holder**: Treasury
- **Powers**:
  - Can kill/revive gauges
  - Can create gauges (legacy and CL)
  - Can set emissions ratios
  - Can retrieve stuck emissions
  - Can toggle xREX governance
  - Can redeem xREX as operator
  - Can migrate operators
  - Can set emissions multipliers
  - Can set treasury fees
  - Can enable tick spacing
  - Can set global fee protocols
  - Can set legacy fee splits

#### **4. SWAP_FEE_SETTER Role - MEDIUM POWER**

- **Default Holder**: Treasury
- **Powers**:
  - Can set swap fees on pools
  - Can set fee splits (CL and legacy)

### **Access Control Risks**

#### **HIGH RISK**

1. **Treasury has excessive power**: Can reinitialize contracts without timelock
2. **Timelock can execute arbitrary code**: `execute()` function allows any payload
3. **No role separation**: Treasury holds multiple critical roles
4. **Operator can kill gauges**: Can disable reward distribution

#### **MEDIUM RISK**

1. **Fee manipulation**: Treasury can change all fee structures
2. **Emissions control**: Operator can adjust emission ratios
3. **Gauge creation**: Operator can create gauges for any pool
