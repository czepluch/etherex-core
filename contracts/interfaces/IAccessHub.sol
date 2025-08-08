// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IVoteModule} from "contracts/interfaces/IVoteModule.sol";
import {IVoter} from "contracts/interfaces/IVoter.sol";
import {IFeeRecipientFactory} from "contracts/interfaces/IFeeRecipientFactory.sol";
import {IMinter} from "contracts/interfaces/IMinter.sol";
import {IXRex} from "contracts/interfaces/IXRex.sol";
import {IREX33} from "contracts/interfaces/IREX33.sol";
import {IRamsesV3Factory} from "contracts/CL/core/interfaces/IRamsesV3Factory.sol";
import {IPairFactory} from "contracts/interfaces/IPairFactory.sol";
import {IFeeCollector} from "contracts/CL/gauge/interfaces/IFeeCollector.sol";

interface IAccessHub {
    error SAME_ADDRESS();
    error NOT_TIMELOCK(address);
    error MANUAL_EXECUTION_FAILURE(bytes);
    error KICK_FORBIDDEN(address);

    /// @dev Struct to hold initialization parameters
    struct InitParams {
        address timelock;
        address treasury;
        address voter;
        address minter;
        address xRam;
        address r33;
        address ramsesV3PoolFactory;
        address poolFactory;
        address clGaugeFactory;
        address gaugeFactory;
        address feeRecipientFactory;
        address feeDistributorFactory;
        address feeCollector;
        address voteModule;
    }

    /// @notice protocol timelock address
    function timelock() external view returns (address timelock);

    /// @notice protocol treasury address
    function treasury() external view returns (address treasury);

    /// @notice vote module
    function voteModule() external view returns (IVoteModule voteModule);

    /// @notice voter
    function voter() external view returns (IVoter voter);

    /// @notice weekly emissions minter
    function minter() external view returns (IMinter minter);

    /// @notice xRam contract  
    function xRam() external view returns (IXRex xRam);

    /// @notice R33 contract
    function r33() external view returns (IREX33 r33);

    /// @notice CL V3 factory
    function ramsesV3PoolFactory() external view returns (IRamsesV3Factory ramsesV3PoolFactory);

    /// @notice legacy pair factory
    function poolFactory() external view returns (IPairFactory poolFactory);

    /// @notice fee collector contract
    function feeCollector() external view returns (IFeeCollector feeCollector);

    /// @notice concentrated (v3) gauge factory
    function clGaugeFactory() external view returns (address _clGaugeFactory);

    /// @notice legacy gauge factory address
    function gaugeFactory() external view returns (address _gaugeFactory);

    /// @notice the feeDistributor factory address
    function feeDistributorFactory() external view returns (address _feeDistributorFactory);

    /// @notice fee recipient factory
    function feeRecipientFactory() external view returns (IFeeRecipientFactory _feeRecipientFactory);

    /// @notice initializing function for setting values in the AccessHub
    function initialize(InitParams calldata params) external;

    /// @notice re-initializing function for updating values in the AccessHub
    function reinit(InitParams calldata params) external;

    /// @notice sets the swap fees for multiple pairs
    function setSwapFees(address[] calldata _pools, uint24[] calldata _swapFees)
        external;

    /// @notice sets the split of fees between LPs and voters
    function setFeeSplitCL(address[] calldata _pools, uint24[] calldata _feeProtocol) external;

    /// @notice sets the split of fees between LPs and voters for legacy pools
    function setFeeSplitLegacy(address[] calldata _pools, uint256[] calldata _feeSplits) external;

    /**
     * Voter governance
     */

    /// @notice sets a new governor address in the voter.sol contract
    function setNewGovernorInVoter(address _newGovernor) external;

    /// @notice whitelists a token for governance, or removes if boolean is set to false
    function governanceWhitelist(address[] calldata _token, bool[] calldata _whitelisted) external;

    /// @notice kills active gauges, removing them from earning further emissions, and claims their fees prior
    function killGauge(address[] calldata _pairs) external;

    /// @notice revives inactive/killed gauges
    function reviveGauge(address[] calldata _pairs) external;

    /// @notice sets the ratio of xRam/Ramses awarded globally to LPs
    function setEmissionsRatioInVoter(uint256 _pct) external;

    /// @notice allows governance to retrieve emissions in the voter contract that will not be distributed due to the gauge being inactive
    /// @dev allows per-period retrieval for granularity
    function retrieveStuckEmissionsToGovernance(address _gauge, uint256 _period) external;

    /// @notice sets the minimum time threshold for rewarder (in seconds)
    function setTimeThresholdForRewarder(uint256 _timeThreshold) external;

    /// @notice creates a new gauge for a legacy pool
    function createLegacyGauge(address _pool) external returns (address);

    /// @notice creates a new concentrated liquidity gauge for a CL pool
    function createCLGauge(address tokenA, address tokenB, int24 tickSpacing) external returns (address);

    /**
     * xRam Functions
     */

    /// @notice enables or disables the transfer whitelist in xRam
    function transferWhitelistInXRam(address[] calldata _who, bool[] calldata _whitelisted) external;

    /// @notice enables or disables the governance in xRam
    function toggleXRamGovernance(bool enable) external;

    /// @notice allows redemption from the operator
    function operatorRedeemXRam(uint256 _amount) external;

    /// @notice migrates the xRam operator
    function migrateOperator(address _operator) external;

    /// @notice rescues any trapped tokens in xRam
    function rescueTrappedTokens(address[] calldata _tokens, uint256[] calldata _amounts) external;

    /**
     * X33 Functions
     */

    /// @notice transfers the r33 operator address
    function transferOperatorInR33(address _newOperator) external;

    /**
     * Minter Functions
     */

    /// @notice sets the inflation multiplier
    /// @param _multiplier the multiplier
    function setEmissionsMultiplierInMinter(uint256 _multiplier) external;

    /**
     * Reward List Functions
     */

    /// @notice function for adding or removing rewards for pools
    function augmentGaugeRewardsForPair(
        address[] calldata _pools,
        address[] calldata _rewards,
        bool[] calldata _addReward
    ) external;
    /// @notice function for removing rewards for feeDistributors
    function removeFeeDistributorRewards(address[] calldata _pools, address[] calldata _rewards) external;

    /**
     * FeeCollector functions
     */

    /// @notice Sets the treasury address to a new value.
    /// @param newTreasury The new address to set as the treasury.
    function setTreasuryInFeeCollector(address newTreasury) external;

    /// @notice Sets the value of treasury fees to a new amount.
    /// @param _treasuryFees The new amount of treasury fees to be set.
    function setTreasuryFeesInFeeCollector(uint256 _treasuryFees) external;

    /**
     * FeeRecipientFactory functions
     */

    /// @notice set the fee % to be sent to the treasury
    /// @param _feeToTreasury the fee % to be sent to the treasury
    function setFeeToTreasuryInFeeRecipientFactory(uint256 _feeToTreasury) external;

    /// @notice set a new treasury address
    /// @param _treasury the new address
    function setTreasuryInFeeRecipientFactory(address _treasury) external;

    /**
     * CL Pool Factory functions
     */

    /// @notice enables a tickSpacing with the given initialFee amount
    /// @dev unlike UniswapV3, we map via the tickSpacing rather than the fee tier
    /// @dev tickSpacings may never be removed once enabled
    /// @param tickSpacing The spacing between ticks to be enforced for all pools created
    /// @param initialFee The initial fee amount, denominated in hundredths of a bip (i.e. 1e-6)
    function enableTickSpacing(int24 tickSpacing, uint24 initialFee) external;

    /// @notice sets the feeProtocol (feeSplit) for new CL pools and stored in the factory
    function setGlobalClFeeProtocol(uint24 _feeProtocolGlobal) external;

    /// @notice sets the address of the voter in the v3 factory for gauge fee setting
    function setVoterAddressInFactoryV3(address _voter) external;

    /// @notice sets the address of the feeCollector in the v3 factory for fee routing
    function setFeeCollectorInFactoryV3(address _newFeeCollector) external;

    /**
     * Legacy Pool Factory functions
     */

    /// @notice sets the treasury address in the legacy factory
    function setTreasuryInLegacyFactory(address _treasury) external;

    /// @notice sets the voter address in the legacy factory
    function setVoterInLegacyFactory(address _voter) external;

    /// @notice enables or disables if there is a feeSplit when no gauge for legacy pairs
    function setFeeSplitWhenNoGauge(bool status) external;

    /// @notice set the default feeSplit in the legacy factory
    function setLegacyFeeSplitGlobal(uint256 _feeSplit) external;

    /// @notice set the default swap fee for legacy pools
    function setLegacyFeeGlobal(uint256 _fee) external;

    /// @notice sets whether a pair can have skim() called or not for rebasing purposes
    function setSkimEnabledLegacy(address _pair, bool _status) external;

    /**
     * VoteModule Functions
     */

    /// @notice sets addresses as exempt or removes their exemption
    function setCooldownExemption(address[] calldata _candidates, bool[] calldata _exempt) external;

    /// @notice function to alter the duration that rebases are streamed in the voteModule
    function setNewRebaseStreamingDuration(uint256 _newDuration) external;

    /// @notice function to change the cooldown in the voteModule
    function setNewVoteModuleCooldown(uint256 _newCooldown) external;

    /// @notice sets the address of the voter in the fee recipient factory for fee recipient creation
    function setVoterInFeeRecipientFactory(address _voter) external;


    /**
     * Timelock gated functions
     */

    /// @notice timelock gated payload execution in case tokens get stuck or other unexpected behaviors
    function execute(address _target, bytes calldata _payload) external;

    /// @notice timelock gated function to change the timelock
    function setNewTimelock(address _timelock) external;

    /// @notice function for initializing the voter contract with its dependencies
    function initializeVoter(
        IVoter.InitializationParams memory inputs
    ) external;
}
