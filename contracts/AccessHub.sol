// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IAccessHub} from "./interfaces/IAccessHub.sol";
import {AccessControlEnumerableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {IVoter} from "./interfaces/IVoter.sol";
import {IMinter} from "./interfaces/IMinter.sol";
import {IXRex} from "./interfaces/IXRex.sol";
import {IREX33} from "./interfaces/IREX33.sol";

import {IRamsesV3Factory} from "./CL/core/interfaces/IRamsesV3Factory.sol";
import {IPairFactory} from "./interfaces/IPairFactory.sol";
import {IFeeRecipientFactory} from "./interfaces/IFeeRecipientFactory.sol";
import {IRamsesV3Pool} from "./CL/core/interfaces/IRamsesV3Pool.sol";
import {IFeeCollector} from "./CL/gauge/interfaces/IFeeCollector.sol";
import {IVoteModule} from "./interfaces/IVoteModule.sol";
import {GaugeV3} from "./CL/gauge/GaugeV3.sol";
import {ClGaugeFactory} from "./CL/gauge/ClGaugeFactory.sol";

import {Errors} from "./libraries/Errors.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract AccessHub is IAccessHub, Initializable, AccessControlEnumerableUpgradeable {
    /**
     * Start of Storage Slots
     */

    /// @notice role that can call changing fee splits and swap fees
    bytes32 public constant SWAP_FEE_SETTER = keccak256("SWAP_FEE_SETTER");
    /// @notice operator role
    bytes32 public constant PROTOCOL_OPERATOR = keccak256("PROTOCOL_OPERATOR");

    /// @inheritdoc IAccessHub
    address public timelock;
    /// @inheritdoc IAccessHub
    address public treasury;

    /**
     * "nice-to-have" addresses for quickly finding contracts within the system
     */

    /// @inheritdoc IAccessHub
    address public clGaugeFactory;
    /// @inheritdoc IAccessHub
    address public gaugeFactory;
    /// @inheritdoc IAccessHub
    address public feeDistributorFactory;

    /**
     * core contracts
     */

    /// @notice central voter contract
    IVoter public voter;
    /// @notice weekly emissions minter
    IMinter public minter;

    /// @notice xRam contract
    IXRex public xRam;
    /// @notice R33 contract
    IREX33 public r33;
    /// @notice CL V3 factory
    IRamsesV3Factory public ramsesV3PoolFactory;
    /// @notice legacy pair factory
    IPairFactory public poolFactory;
    /// @notice legacy fees holder contract
    IFeeRecipientFactory public feeRecipientFactory;
    /// @notice fee collector contract
    IFeeCollector public feeCollector;
    /// @notice voteModule contract
    IVoteModule public voteModule;

    /**
     * End of Storage Slots
     */
    modifier timelocked() {
        require(msg.sender == timelock, NOT_TIMELOCK(msg.sender));
        _;
    }
    modifier onlyMultisig() {
        require(msg.sender == treasury, Errors.NOT_AUTHORIZED(msg.sender));
        _;
    }

    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc IAccessHub
    function initialize(InitParams calldata params) external initializer {
        /// @dev initialize all external interfaces
        timelock = params.timelock;
        treasury = params.treasury;
        voter = IVoter(params.voter);
        minter = IMinter(params.minter);
        xRam = IXRex(params.xRam);
        r33 = IREX33(params.r33);
        ramsesV3PoolFactory = IRamsesV3Factory(params.ramsesV3PoolFactory);
        poolFactory = IPairFactory(params.poolFactory);
        feeRecipientFactory = IFeeRecipientFactory(params.feeRecipientFactory);
        feeCollector = IFeeCollector(params.feeCollector);
        voteModule = IVoteModule(params.voteModule);

        /// @dev reference addresses
        clGaugeFactory = params.clGaugeFactory;
        gaugeFactory = params.gaugeFactory;
        feeDistributorFactory = params.feeDistributorFactory;

        /// @dev fee setter role given to treasury
        _grantRole(SWAP_FEE_SETTER, params.treasury);
        /// @dev operator role given to treasury
        _grantRole(PROTOCOL_OPERATOR, params.treasury);
        /// @dev initially give admin role to treasury
        _grantRole(DEFAULT_ADMIN_ROLE, params.treasury);
        /// @dev give timelock the admin role
        _grantRole(DEFAULT_ADMIN_ROLE, params.timelock);
    }

    function reinit(InitParams calldata params) external onlyMultisig {
        voter = IVoter(params.voter);
        minter = IMinter(params.minter);
        xRam = IXRex(params.xRam);
        r33 = IREX33(params.r33);
        ramsesV3PoolFactory = IRamsesV3Factory(params.ramsesV3PoolFactory);
        poolFactory = IPairFactory(params.poolFactory);
        feeRecipientFactory = IFeeRecipientFactory(params.feeRecipientFactory);
        feeCollector = IFeeCollector(params.feeCollector);
        voteModule = IVoteModule(params.voteModule);

        /// @dev reference addresses
        clGaugeFactory = params.clGaugeFactory;
        gaugeFactory = params.gaugeFactory;
        feeDistributorFactory = params.feeDistributorFactory;
    }

    /// @inheritdoc IAccessHub
    function initializeVoter(
        IVoter.InitializationParams memory inputs
    ) external onlyMultisig {
        voter.initialize(
            inputs
        );
    }

    /**
     * Fee Setting Logic
     */

    /// @inheritdoc IAccessHub
    function setSwapFees(address[] calldata _pools, uint24[] calldata _swapFees) external onlyRole(SWAP_FEE_SETTER) {
        /// @dev ensure continuity of length
        require(_pools.length == _swapFees.length, Errors.LENGTH_MISMATCH());
        for (uint256 i; i < _pools.length; ++i) {
            /// @dev we check if the pool is v3 or legacy and set their fees accordingly
            if (ramsesV3PoolFactory.isPairV3(_pools[i])) {
                ramsesV3PoolFactory.setFee(_pools[i], _swapFees[i]);
            } else if (poolFactory.isPair(_pools[i])) {
                poolFactory.setPairFee(_pools[i], _swapFees[i]);
            }
        }
    }

    /// @inheritdoc IAccessHub
    function setFeeSplitCL(address[] calldata _pools, uint24[] calldata _feeProtocol)
        external
    {
        /// @dev allow either SWAP_FEE_SETTER role holders OR the voter contract
        require(
            hasRole(SWAP_FEE_SETTER, msg.sender) || msg.sender == address(voter),
            Errors.NOT_AUTHORIZED(msg.sender)
        );
        
        /// @dev ensure continuity of length
        require(_pools.length == _feeProtocol.length, Errors.LENGTH_MISMATCH());
        for (uint256 i; i < _pools.length; ++i) {
            ramsesV3PoolFactory.setPoolFeeProtocol(_pools[i], _feeProtocol[i]);
        }
    }

    /// @inheritdoc IAccessHub
    function setFeeSplitLegacy(address[] calldata _pools, uint256[] calldata _feeSplits)
        external
    {
        /// @dev allow either SWAP_FEE_SETTER role holders OR the voter contract
        require(
            hasRole(SWAP_FEE_SETTER, msg.sender) || msg.sender == address(voter),
            Errors.NOT_AUTHORIZED(msg.sender)
        );
        
        /// @dev ensure continuity of length
        require(_pools.length == _feeSplits.length, Errors.LENGTH_MISMATCH());
        for (uint256 i; i < _pools.length; ++i) {
            poolFactory.setPairFeeSplit(_pools[i], _feeSplits[i]);
        }
    }

    /// @notice sets the fee recipient for legacy pairs
    function setFeeRecipientLegacyBatched(address[] calldata _pairs, address[] calldata _feeRecipients) external onlyMultisig {
        require(_pairs.length == _feeRecipients.length, Errors.LENGTH_MISMATCH());
        for (uint256 i; i < _pairs.length; ++i) {
            poolFactory.setFeeRecipient(_pairs[i], _feeRecipients[i]);
        }
    }

    /**
     * Voter governance
     */

    /// @inheritdoc IAccessHub
    function setNewGovernorInVoter(address _newGovernor) external onlyRole(PROTOCOL_OPERATOR) {
        /// @dev no checks are needed as the voter handles this already
        voter.setGovernor(_newGovernor);
    }

    /// @inheritdoc IAccessHub
    function governanceWhitelist(address[] calldata _token, bool[] calldata _whitelisted)
        external
        onlyRole(PROTOCOL_OPERATOR)
    {
        /// @dev ensure continuity of length
        require(_token.length == _whitelisted.length, Errors.LENGTH_MISMATCH());
        for (uint256 i; i < _token.length; ++i) {
            /// @dev if adding to the whitelist
            if (_whitelisted[i]) {
                /// @dev call the voter's whitelist function
                voter.whitelist(_token[i]);
            }
            /// @dev remove the token's whitelist
            else {
                voter.revokeWhitelist(_token[i]);
            }
        }
    }

    /// @inheritdoc IAccessHub
    function killGauge(address[] calldata _pairs) external onlyRole(PROTOCOL_OPERATOR) {
        for (uint256 i; i < _pairs.length; ++i) {
            /// @dev store pair
            address pair = _pairs[i];
            /// @dev collect fees from the pair
            feeCollector.collectProtocolFees(pair);
            /// @dev kill the gauge
            voter.killGauge(voter.gaugeForPool(pair));
            /// @dev set the new fees in the pair to 95/5
            ramsesV3PoolFactory.setPoolFeeProtocol(pair, 5);
        }
    }

    /// @inheritdoc IAccessHub
    function reviveGauge(address[] calldata _pairs) external onlyRole(PROTOCOL_OPERATOR) {
        for (uint256 i; i < _pairs.length; ++i) {
            address pair = _pairs[i];
            /// @dev collect fees from the pair
            feeCollector.collectProtocolFees(pair);
            /// @dev revive the pair
            voter.reviveGauge(voter.gaugeForPool(pair));
            /// @dev set fee to the factory default
            ramsesV3PoolFactory.setPoolFeeProtocol(pair, ramsesV3PoolFactory.feeProtocol());
        }
    }

    /// @inheritdoc IAccessHub
    function setEmissionsRatioInVoter(uint256 _pct) external onlyRole(PROTOCOL_OPERATOR) {
        voter.setGlobalRatio(_pct);
    }

    /// @inheritdoc IAccessHub
    function retrieveStuckEmissionsToGovernance(address _gauge, uint256 _period) external onlyRole(PROTOCOL_OPERATOR) {
        voter.stuckEmissionsRecovery(_gauge, _period);
    }

    /// @notice Set the minimum time threshold for rewarder (in seconds)
    /// @param _timeThreshold New time threshold in seconds (0 = no threshold)
    function setTimeThresholdForRewarder(uint256 _timeThreshold) external onlyRole(PROTOCOL_OPERATOR) {
        voter.setTimeThresholdForRewarder(_timeThreshold);
    }

    /// @inheritdoc IAccessHub
    function createLegacyGauge(address _pool) external onlyRole(PROTOCOL_OPERATOR) returns (address) {
        return voter.createGauge(_pool);
    }

    /// @inheritdoc IAccessHub
    function createCLGauge(address tokenA, address tokenB, int24 tickSpacing)
        external
        onlyRole(PROTOCOL_OPERATOR)
        returns (address)
    {
        return voter.createCLGauge(tokenA, tokenB, tickSpacing);
    }

    /**
     * xRam Functions
     */

    function setFeeCollectorAccessHub(address _feeCollector) external onlyMultisig {
        feeCollector = IFeeCollector(_feeCollector);
    }
    function setFeeCollectorInClGaugeFactory(address _feeCollector) external onlyMultisig {
        ClGaugeFactory(clGaugeFactory).setFeeCollector(_feeCollector);
    }

    /// @inheritdoc IAccessHub
    function transferWhitelistInXRam(address[] calldata _who, bool[] calldata _whitelisted)
        external
        onlyRole(PROTOCOL_OPERATOR)
    {
        /// @dev ensure continuity of length
        require(_who.length == _whitelisted.length, Errors.LENGTH_MISMATCH());
        xRam.setExemption(_who, _whitelisted);
    }

    /// @inheritdoc IAccessHub
    function toggleXRamGovernance(bool enable) external onlyRole(PROTOCOL_OPERATOR) {
        /// @dev if enabled we call unpause otherwise we pause to disable
        enable ? xRam.unpause() : xRam.pause();
    }

    /// @inheritdoc IAccessHub
    function operatorRedeemXRam(uint256 _amount) external onlyRole(PROTOCOL_OPERATOR) {
        xRam.operatorRedeem(_amount);
    }

    /// @inheritdoc IAccessHub
    function migrateOperator(address _operator) external onlyRole(PROTOCOL_OPERATOR) {
        xRam.migrateOperator(_operator);
    }

    /// @inheritdoc IAccessHub
    function rescueTrappedTokens(address[] calldata _tokens, uint256[] calldata _amounts)
        external
        onlyRole(PROTOCOL_OPERATOR)
    {
        xRam.rescueTrappedTokens(_tokens, _amounts);
    }

    /**
     * X33 Functions
     */

    /// @inheritdoc IAccessHub
    function transferOperatorInR33(address _newOperator) external onlyRole(PROTOCOL_OPERATOR) {
        r33.transferOperator(_newOperator);
    }

    /**
     * Minter Functions
     */

    /// @inheritdoc IAccessHub
    function setEmissionsMultiplierInMinter(uint256 _multiplier) external onlyRole(PROTOCOL_OPERATOR) {
        minter.updateEmissionsMultiplier(_multiplier);
    }

    /**
     * Reward List Functions
     */

    /// @inheritdoc IAccessHub
    function augmentGaugeRewardsForPair(
        address[] calldata _pools,
        address[] calldata _rewards,
        bool[] calldata _addReward
    ) external onlyRole(PROTOCOL_OPERATOR) {
        /// @dev length continuity check
        require(_pools.length == _rewards.length && _rewards.length == _addReward.length, Errors.LENGTH_MISMATCH());
        /// @dev loop through all entries
        for (uint256 i; i < _pools.length; ++i) {
            /// @dev fetch the gauge address
            address gauge = voter.gaugeForPool(_pools[i]);
            /// @dev if true (add rewards)
            if (_addReward[i]) {
                // voter.whitelistGaugeRewards(gauge, _rewards[i]); //TODO do we remove this?
            }
            /// @dev if false remove the rewards
            else {
                // voter.removeGaugeRewardWhitelist(gauge, _rewards[i]); //TODO do we remove this?
            }
        }
    }
    /// @inheritdoc IAccessHub

    function removeFeeDistributorRewards(address[] calldata _pools, address[] calldata _rewards)
        external
        onlyRole(PROTOCOL_OPERATOR)
    {
        require(_pools.length == _rewards.length, Errors.LENGTH_MISMATCH());
        for (uint256 i; i < _pools.length; ++i) {
            voter.removeFeeDistributorReward(voter.feeDistributorForGauge(voter.gaugeForPool(_pools[i])), _rewards[i]);
        }
    }

    /**
     * FeeCollector functions
     */

    /// @inheritdoc IAccessHub
    function setTreasuryInFeeCollector(address newTreasury) external onlyRole(PROTOCOL_OPERATOR) {
        feeCollector.setTreasury(newTreasury);
    }

    /// @inheritdoc IAccessHub
    function setTreasuryFeesInFeeCollector(uint256 _treasuryFees) external onlyRole(PROTOCOL_OPERATOR) {
        feeCollector.setTreasuryFees(_treasuryFees);
    }

    /**
     * FeeRecipientFactory functions
     */

    /// @inheritdoc IAccessHub
    function setFeeToTreasuryInFeeRecipientFactory(uint256 _feeToTreasury) external onlyRole(PROTOCOL_OPERATOR) {
        feeRecipientFactory.setFeeToTreasury(_feeToTreasury);
    }

    /// @inheritdoc IAccessHub
    function setTreasuryInFeeRecipientFactory(address _treasury) external onlyRole(PROTOCOL_OPERATOR) {
        feeRecipientFactory.setTreasury(_treasury);
    }

    /**
     * CL Pool Factory functions
     */

    /// @inheritdoc IAccessHub
    function enableTickSpacing(int24 tickSpacing, uint24 initialFee) external onlyRole(PROTOCOL_OPERATOR) {
        ramsesV3PoolFactory.enableTickSpacing(tickSpacing, initialFee);
    }

    /// @inheritdoc IAccessHub
    function setGlobalClFeeProtocol(uint24 _feeProtocolGlobal) external onlyRole(PROTOCOL_OPERATOR) {
        ramsesV3PoolFactory.setFeeProtocol(_feeProtocolGlobal);
    }

    /// @inheritdoc IAccessHub
    /// @notice sets the address of the voter in the v3 factory for gauge fee setting
    function setVoterAddressInFactoryV3(address _voter) external onlyMultisig {
        ramsesV3PoolFactory.setVoter(_voter);
    }

    /// @inheritdoc IAccessHub
    /// @notice sets the address of the voter in the fee recipient factory for fee recipient creation
    function setVoterInFeeRecipientFactory(address _voter) external onlyMultisig {
        feeRecipientFactory.setVoter(_voter);
    }

    /// @inheritdoc IAccessHub
    function setFeeCollectorInFactoryV3(address _newFeeCollector) external onlyMultisig {
        ramsesV3PoolFactory.setFeeCollector(_newFeeCollector);
    }

      /// @notice Update FeeDistributor for a gauge (emergency governance function)
    function updateFeeDistributorForGauge(address _gauge, address _newFeeDistributor) external onlyMultisig {
        voter.updateFeeDistributorForGauge(_gauge, _newFeeDistributor);

    }

    /// @notice Create a new FeeDistributor with specified feeRecipient (emergency governance function)
    function createFeeDistributorWithRecipient(address _feeRecipient) external onlyMultisig returns (address) {
        return voter.createFeeDistributorWithRecipient(_feeRecipient);
    }


    /**
     * Legacy Pool Factory functions
     */

    /// @inheritdoc IAccessHub
    function setTreasuryInLegacyFactory(address _treasury) external onlyMultisig {
        poolFactory.setTreasury(_treasury);
    }


    /// @inheritdoc IAccessHub
    function setVoterInLegacyFactory(address _voter) external onlyMultisig {
        IPairFactory(poolFactory).setVoter(_voter);
    }

    /// @inheritdoc IAccessHub
    function setFeeSplitWhenNoGauge(bool status) external onlyRole(PROTOCOL_OPERATOR) {
        poolFactory.setFeeSplitWhenNoGauge(status);
    }

    /// @inheritdoc IAccessHub
    function setLegacyFeeSplitGlobal(uint256 _feeSplit) external onlyRole(PROTOCOL_OPERATOR) {
        poolFactory.setFeeSplit(_feeSplit);
    }

    /// @inheritdoc IAccessHub
    function setLegacyFeeGlobal(uint256 _fee) external onlyRole(PROTOCOL_OPERATOR) {
        poolFactory.setFee(_fee);
    }

    /// @inheritdoc IAccessHub
    function setSkimEnabledLegacy(address _pair, bool _status) external onlyRole(PROTOCOL_OPERATOR) {
        poolFactory.setSkimEnabled(_pair, _status);
    }

    

    /**
     * VoteModule Functions
     */

    /// @inheritdoc IAccessHub
    function setCooldownExemption(address[] calldata _candidates, bool[] calldata _exempt) external timelocked {
        for (uint256 i; i < _candidates.length; ++i) {
            voteModule.setCooldownExemption(_candidates[i], _exempt[i]);
        }
    }

    /// @inheritdoc IAccessHub
    function setNewRebaseStreamingDuration(uint256 _newDuration) external timelocked {
        // voteModule.setNewDuration(_newDuration); //TODO do we remove this?
    }

    /// @inheritdoc IAccessHub
    function setNewVoteModuleCooldown(uint256 _newCooldown) external timelocked {
        voteModule.setNewCooldown(_newCooldown);
    }

    /**
     * Timelock specific functions
     */

    /// @inheritdoc IAccessHub
    function execute(address _target, bytes calldata _payload) external timelocked {
        (bool success,) = _target.call(_payload);
        require(success, MANUAL_EXECUTION_FAILURE(_payload));
    }

    /// @inheritdoc IAccessHub
    function setNewTimelock(address _timelock) external timelocked {
        require(timelock != _timelock, SAME_ADDRESS());
        timelock = _timelock;
    }


    function reinitializeV3Gauge(
        address _gauge,
        address _voter,
        address _nfpManager,
        address _feeCollector,
        address _pool
    ) public onlyMultisig {
        GaugeV3(_gauge).initializeV2(_voter, _nfpManager, _feeCollector, _pool);
    }

    function setV3FactoryImplementation(address _newImplementation) public onlyMultisig {
        ClGaugeFactory(clGaugeFactory).setImplementation(_newImplementation);
    }
}
