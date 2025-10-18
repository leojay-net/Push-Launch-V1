// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

// import {BondingCurve} from "./BondingCurve.sol";
import {LaunchToken} from "./LaunchToken.sol";
import {IUniswapV2RouterMinimal} from "./interfaces/IUniswapV2RouterMinimal.sol";
import {IUniswapV2FactoryMinimal} from "./interfaces/IUniswapV2FactoryMinimal.sol";
import {ILaunchpad, IBondingCurveMinimal} from "./interfaces/ILaunchpad.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {ERC165Checker} from "@openzeppelin/utils/introspection/ERC165Checker.sol";

import {LaunchpadLPVault} from "./LaunchpadLPVault.sol";
import {Initializable} from "@solady/utils/Initializable.sol";
import {Ownable} from "@solady/auth/Ownable.sol";
import {ReentrancyGuard} from "@solady/utils/ReentrancyGuard.sol";

import {IUniV2Factory} from "./interfaces/IUniV2Factory.sol";
import {IUniswapV2Pair} from "./interfaces/IUniswapV2Pair.sol";
import {IDistributor} from "./interfaces/IDistributor.sol";
import {IPushLaunchpadV2Pair} from "./uniswap/interfaces/IPushLaunchpadV2Pair.sol";
import {IUEAFactory, UniversalAccountId} from "./interfaces/IUniversal.sol";

// Operator roles and CLOB integration removed for simplified launchpad

contract Launchpad is ILaunchpad, Initializable, Ownable, ReentrancyGuard {
    using SafeTransferLib for address;

    /*▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀
                                EVENTS
    ▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀*/

    /// @dev sig: 0xedb9fe87bd33aab1b87917d7ac18478fc6e849256def39db1a60ca615a1a35f9
    event LaunchpadDeployed(
        address indexed quoteAsset,
        address bondingCurve,
        address router,
        uint256 eventNonce
    );
    /// @dev sig: 0xb32a6b288aadfa675cb030ee2f51c6dc12675a9e5531231a996b8edb611f1956
    event BondingLocked(
        address indexed token,
        IUniswapV2Pair indexed pairAddress,
        uint256 eventNonce
    );
    /// @dev sig: 0xca2a6f300abd801d3ade4ca6344f9caba868f5165eb754544d4fe6195fe07212
    event BondingCurveUpdated(
        address indexed oldCurve,
        address indexed newCurve,
        uint256 eventNonce
    );
    /// @dev sig: 0x8d4aad4953d0ca700d468f3753aa14432d1b35b43ec6409f051fb6aa43a89607
    event TokenLaunched(
        address indexed dev,
        address indexed token,
        address indexed quoteAsset,
        IBondingCurveMinimal bondingCurve,
        uint256 timestamp,
        uint256 eventNonce
    );
    /// @dev sig: 0x221ca85ebf95f18d1618caabee27ca0867de44313b2989c305e6e6f96f582e40
    event QuoteAssetUpdated(
        address indexed oldQuoteToken,
        address indexed newQuoteToken,
        uint256 newQuoteTokenDecimals,
        uint256 eventNonce
    );
    /// @dev sig: 0xe8f92b6d8befe44289e67ee6740a1b61cfea7bd8ebe8c2050c4ec7ef555d5fc5
    event Swap(
        address indexed buyer,
        address indexed token,
        int256 baseDelta,
        int256 quoteDelta,
        uint256 nextAmountSold,
        uint256 newPrice,
        uint256 eventNonce
    );

    /// @notice Emitted when a universal transaction occurs (from any chain)
    /// @dev sig: computed at runtime
    event UniversalSwap(
        address indexed buyer,
        address indexed token,
        string chainNamespace,
        string chainId,
        bytes originOwner,
        bool isUEA,
        int256 baseDelta,
        int256 quoteDelta,
        uint256 eventNonce
    );

    /*▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀
                                ERRORS
    ▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀*/

    /// @dev sig: 0xa2c1d73f
    error BadLaunchFee();
    /// @dev sig: 0x2fe7552a
    error InvalidCurve();
    /// @dev sig: 0xfe717103
    error BondingCurveSetupFailed(bytes returnData);
    /// @dev sig: 0xc7022a01
    error MissingCredits();
    /// @dev sig: 0x5e2acf84
    error OnlyLaunchAsset();
    /// @dev sig: 0x9efab874
    error BondingInactive();
    /// @dev sig: 0x9c8d2cd2
    error InvalidRecipient();
    /// @dev sig: 0x4233ebcb
    error DustAttackInvalid();
    /// @dev sig: 0x1d33d88c
    error InvalidQuoteAsset();
    /// @dev sig: 0x6f156a5e
    error UninitializedCurve();
    /// @dev sig: 0xa3265e40
    error UninitializedQuote();
    /// @dev sig: 0x9b480a76
    error InvalidQuoteScaling();
    /// @dev sig: 0xad73b7b2
    error UnsupportedRewardToken();
    /// @dev sig: 0x6728a9f6
    error SlippageToleranceExceeded();
    /// @dev sig: 0xb12d13eb
    error ETHTransferFailed();
    /// @dev sig: 0xa1d718af
    error InsufficientBaseSold();

    /*▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀
                                STATE
    ▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀*/

    /// @dev The abi version of this impl so the indexer can handle event-changing upgrades
    uint256 public constant ABI_VERSION = 1;
    uint256 public constant TOTAL_SUPPLY = 1 ether * 1e9;
    uint256 public constant BONDING_SUPPLY = 800_000_000 ether;

    // Router/operator removed
    IDistributor public immutable distributor;
    IUniswapV2RouterMinimal public immutable uniV2Router;
    IUniswapV2FactoryMinimal internal immutable uniV2Factory;

    // @todo make proxy addr immutable with deterministic addr
    LaunchpadLPVault public launchpadLPVault;

    /// @dev This is just the quote ERC20 cast as LaunchToken so we dont have to import ERC20
    LaunchToken public currentQuoteAsset;
    IBondingCurveMinimal public currentBondingCurve;

    mapping(address token => LaunchData) internal _launches;

    uint256 public launchFee;

    /// @dev Event nonce for tracking event ordering offchain
    uint256 private _eventNonce;

    /*▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀
                        UNIVERSAL FEATURES STATE
    ▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀*/

    /// @notice UEA Factory system contract address on Push Chain
    /// @dev This is a precompiled contract at a fixed address
    address public constant UEA_FACTORY =
        0x00000000000000000000000000000000000000eA;

    /// @notice Track total volume per chain for each token
    /// @dev token => chainHash => volume
    mapping(address => mapping(bytes32 => uint256)) public chainVolume;

    /// @notice Track transaction count per chain for each token
    /// @dev token => chainHash => count
    mapping(address => mapping(bytes32 => uint256)) public chainTxCount;

    /// @notice Track unique users per chain for each token
    /// @dev token => chainHash => user => hasTransacted
    mapping(address => mapping(bytes32 => mapping(address => bool)))
        public chainUserTracking;

    /// @notice Track per-chain stats globally
    /// @dev chainHash => volume
    mapping(bytes32 => uint256) public globalChainVolume;

    /// @notice Track per-chain transaction count globally
    /// @dev chainHash => tx count
    mapping(bytes32 => uint256) public globalChainTxCount;

    /*▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀
                                MODIFIERS
    ▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀*/

    modifier onlyLaunchAsset() {
        if (_launches[msg.sender].quote == address(0)) revert OnlyLaunchAsset();
        _;
    }

    modifier onlyBondingActive(address token) {
        if (!_launches[token].active) revert BondingInactive();
        _;
    }

    // Operator gating removed

    /*▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀
                                CONSTRUCTOR
    ▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀*/

    // slither-disable-next-line missing-zero-check
    constructor(address uniV2Router_, address distributor_) {
        uniV2Router = IUniswapV2RouterMinimal(uniV2Router_);
        uniV2Factory = IUniswapV2FactoryMinimal(uniV2Router.factory());
        distributor = IDistributor(distributor_);

        _disableInitializers();
    }

    /// @dev bondingCurveSetupData should contain an ABI-encoded call destined for the bonding curve contract
    function initialize(
        address owner_,
        address quoteAsset_,
        address bondingCurve_,
        address launchpadLPVault_,
        bytes memory bondingCurveInitData
    ) external initializer {
        _initializeOwner(owner_);

        if (quoteAsset_ == address(0)) revert InvalidQuoteAsset();
        if (
            !ERC165Checker.supportsInterface(
                bondingCurve_,
                type(IBondingCurveMinimal).interfaceId
            )
        ) {
            revert InvalidCurve();
        }

        // Sanity check that the new quote asset at the very least implements an ERC20 approval
        LaunchToken(quoteAsset_).approve(address(this), 0);

        currentBondingCurve = IBondingCurveMinimal(bondingCurve_);
        currentQuoteAsset = LaunchToken(quoteAsset_);
        launchpadLPVault = LaunchpadLPVault(launchpadLPVault_);

        // e.g. bondingCurve.setVirtualReserves({virtualBase: virtualBase_, virtualQuote: virtualQuote_});
        currentBondingCurve.init(bondingCurveInitData);

        emit LaunchpadDeployed(
            quoteAsset_,
            bondingCurve_,
            address(uniV2Router),
            _incEventNonce()
        );
    }

    /*▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀
                                PUBLIC VIEWS
    ▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀*/

    function launches(
        address launchToken
    ) public view returns (LaunchData memory) {
        return _launches[launchToken];
    }

    function baseSoldFromCurve(address token) public view returns (uint256) {
        return _launches[token].curve.baseSoldFromCurve(token);
    }

    function quoteBoughtByCurve(address token) public view returns (uint256) {
        return _launches[token].curve.quoteBoughtByCurve(token);
    }

    function quoteBaseForQuote(
        address token,
        uint256 quoteAmount,
        bool isBuy
    ) public view returns (uint256 baseAmount) {
        return
            _launches[token].curve.quoteBaseForQuote(token, quoteAmount, isBuy);
    }

    function quoteQuoteForBase(
        address token,
        uint256 baseAmount,
        bool isBuy
    ) public view returns (uint256 quoteAmount) {
        return
            _launches[token].curve.quoteQuoteForBase(token, baseAmount, isBuy);
    }

    function eventNonce() external view returns (uint256) {
        return _eventNonce;
    }

    /*▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀
                        UNIVERSAL VIEW FUNCTIONS
    ▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀*/

    /// @notice Get the total volume for a specific token from a specific chain
    /// @param token The token address
    /// @param chainNamespace The chain namespace (e.g., "eip155")
    /// @param chainId The chain ID (e.g., "1")
    /// @return The total volume from that chain for this token
    function getTokenVolumeByChain(
        address token,
        string memory chainNamespace,
        string memory chainId
    ) external view returns (uint256) {
        bytes32 chainHash = getChainHash(chainNamespace, chainId);
        return chainVolume[token][chainHash];
    }

    /// @notice Get the transaction count for a specific token from a specific chain
    /// @param token The token address
    /// @param chainNamespace The chain namespace
    /// @param chainId The chain ID
    /// @return The number of transactions from that chain for this token
    function getTokenTxCountByChain(
        address token,
        string memory chainNamespace,
        string memory chainId
    ) external view returns (uint256) {
        bytes32 chainHash = getChainHash(chainNamespace, chainId);
        return chainTxCount[token][chainHash];
    }

    /// @notice Get the global volume from a specific chain across all tokens
    /// @param chainNamespace The chain namespace
    /// @param chainId The chain ID
    /// @return The total volume from that chain
    function getGlobalVolumeByChain(
        string memory chainNamespace,
        string memory chainId
    ) external view returns (uint256) {
        bytes32 chainHash = getChainHash(chainNamespace, chainId);
        return globalChainVolume[chainHash];
    }

    /// @notice Get the global transaction count from a specific chain
    /// @param chainNamespace The chain namespace
    /// @param chainId The chain ID
    /// @return The total transaction count from that chain
    function getGlobalTxCountByChain(
        string memory chainNamespace,
        string memory chainId
    ) external view returns (uint256) {
        bytes32 chainHash = getChainHash(chainNamespace, chainId);
        return globalChainTxCount[chainHash];
    }

    /// @notice Check if a user has transacted for a token from a specific chain
    /// @param token The token address
    /// @param chainNamespace The chain namespace
    /// @param chainId The chain ID
    /// @param user The user address
    /// @return True if the user has transacted
    function hasUserTransactedFromChain(
        address token,
        string memory chainNamespace,
        string memory chainId,
        address user
    ) external view returns (bool) {
        bytes32 chainHash = getChainHash(chainNamespace, chainId);
        return chainUserTracking[token][chainHash][user];
    }

    /*▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀
                            PUBLIC WRITES
    ▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀*/

    /// @notice Launches a new token
    function launch(
        string memory name,
        string memory symbol,
        string memory mediaURI
    ) external payable nonReentrant returns (address token) {
        if (msg.value != launchFee) revert BadLaunchFee();

        address quote = address(currentQuoteAsset);
        IBondingCurveMinimal curve = currentBondingCurve;

        if (quote == address(0)) revert UninitializedQuote();
        if (address(curve) == address(0)) revert UninitializedCurve();

        token = address(new LaunchToken(name, symbol, mediaURI));

        curve.initializeCurve(token, TOTAL_SUPPLY, BONDING_SUPPLY);
        distributor.createRewardsPair(token, quote);

        _launches[token] = LaunchData({
            active: true,
            curve: curve,
            quote: quote
        });

        emit TokenLaunched({
            dev: msg.sender,
            token: token,
            quoteAsset: quote,
            bondingCurve: curve,
            timestamp: block.timestamp,
            eventNonce: _incEventNonce()
        });

        LaunchToken(token).mint(TOTAL_SUPPLY);
    }

    /// @notice Buys an `amountOutBase` of a bonding `token` so long as it costs less than `maxAmountInQuote`
    function buy(
        BuyData calldata buyData
    )
        external
        nonReentrant
        onlyBondingActive(buyData.token)
        returns (
            // operator routing removed
            uint256 amountOutBaseActual,
            uint256 amountInQuote
        )
    {
        IUniswapV2Pair pair = _assertValidRecipient(
            buyData.recipient,
            buyData.token
        );
        LaunchData memory data = _launches[buyData.token];

        (amountOutBaseActual, data.active) = _checkGraduation(
            buyData.token,
            data,
            buyData.amountOutBase
        );

        amountInQuote = data.curve.buy(buyData.token, amountOutBaseActual);

        if (data.active && amountInQuote == 0) revert DustAttackInvalid();
        if (amountInQuote > buyData.maxAmountInQuote)
            revert SlippageToleranceExceeded();

        buyData.token.safeTransfer(buyData.recipient, amountOutBaseActual);
        address(data.quote).safeTransferFrom(
            buyData.account,
            address(this),
            amountInQuote
        );

        _emitSwapEvent({
            account: buyData.account,
            token: buyData.token,
            baseAmount: amountOutBaseActual,
            quoteAmount: amountInQuote,
            isBuy: true,
            curve: data.curve
        });

        // If graduated, handle AMM setup and remaining swap
        if (!data.active) {
            (amountOutBaseActual, amountInQuote) = _graduate(
                buyData,
                pair,
                data,
                amountOutBaseActual,
                amountInQuote
            );
        }
    }

    function _graduate(
        BuyData calldata buyData,
        IUniswapV2Pair pair,
        LaunchData memory data,
        uint256 amountOutBaseActual,
        uint256 amountInQuote
    )
        internal
        returns (uint256 finalAmountOutBaseActual, uint256 finalAmountInQuote)
    {
        LaunchToken(buyData.token).unlock();
        _launches[buyData.token].active = false;
        emit BondingLocked(buyData.token, pair, _incEventNonce());

        uint256 additionalQuote = _createPairAndSwapRemaining({
            token: buyData.token,
            pair: pair,
            data: data,
            remainingBase: buyData.amountOutBase - amountOutBaseActual,
            remainingQuote: buyData.maxAmountInQuote - amountInQuote,
            recipient: buyData.recipient
        });

        finalAmountInQuote = amountInQuote + additionalQuote;
        finalAmountOutBaseActual = additionalQuote > 0
            ? buyData.amountOutBase
            : amountOutBaseActual;
    }

    /// @notice Sells an `amountInBase` of a bonding `token` as long as the proceeds are at least `minAmountOutQuote`
    function sell(
        address account,
        address token,
        address recipient,
        uint256 amountInBase,
        uint256 minAmountOutQuote
    )
        external
        nonReentrant
        onlyBondingActive(token)
        returns (
            // operator routing removed
            uint256 amountInBaseActual,
            uint256 amountOutQuoteActual
        )
    {
        LaunchData memory data = _launches[token];

        uint256 currentBaseSold = data.curve.baseSoldFromCurve(token);
        if (currentBaseSold < amountInBase) revert InsufficientBaseSold();

        // slither-disable-next-line reentrancy-no-eth
        uint256 amountOutQuote = data.curve.sell(token, amountInBase);

        if (amountOutQuote == 0) revert DustAttackInvalid();
        if (amountOutQuote < minAmountOutQuote)
            revert SlippageToleranceExceeded();

        _emitSwapEvent({
            account: account,
            token: token,
            baseAmount: amountInBase,
            quoteAmount: amountOutQuote,
            isBuy: false,
            curve: data.curve
        });

        token.safeTransferFrom(account, address(this), amountInBase);
        data.quote.safeTransfer(recipient, amountOutQuote);

        return (amountInBase, amountOutQuote);
    }

    /*▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀
                               OWNER-ONLY
    ▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀*/

    /// @notice Updates the bonding curve, live launches are not affected
    function updateBondingCurve(address newBondingCurve) external onlyOwner {
        if (
            !ERC165Checker.supportsInterface(
                newBondingCurve,
                type(IBondingCurveMinimal).interfaceId
            )
        ) {
            revert InvalidCurve();
        }

        emit BondingCurveUpdated(
            address(currentBondingCurve),
            newBondingCurve,
            _incEventNonce()
        );

        currentBondingCurve = IBondingCurveMinimal(newBondingCurve);
    }

    /// @notice Updates the quote asset.
    /// @dev The quote asset cannot have been an existing LaunchToken
    function updateQuoteAsset(address newQuoteAsset) external onlyOwner {
        if (
            newQuoteAsset == address(0) ||
            _launches[newQuoteAsset].quote != address(0)
        ) revert InvalidQuoteAsset();

        // Check new quote at least implements approve in lieu of ERC165
        LaunchToken(newQuoteAsset).approve(address(this), 0);

        emit QuoteAssetUpdated(
            address(currentQuoteAsset),
            newQuoteAsset,
            LaunchToken(newQuoteAsset).decimals(),
            _incEventNonce()
        );

        currentQuoteAsset = LaunchToken(newQuoteAsset);
    }

    /// @notice Pulls the fees earned from launching tokens
    function pullFees() external onlyOwner {
        // slither-disable-next-line low-level-calls
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");

        if (!success) revert ETHTransferFailed();
    }

    // @todo event
    function updateLaunchFee(uint256 newLaunchFee) external onlyOwner {
        launchFee = newLaunchFee;
    }

    // @todo event
    function updateLaunchpadLPVault(
        address newLaunchpadLPVault
    ) external onlyOwner {
        launchpadLPVault = LaunchpadLPVault(newLaunchpadLPVault);
    }

    /*▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀
                                FEE-SHARING
    ▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀*/

    function increaseStake(
        address account,
        uint96 shares
    ) external onlyLaunchAsset {
        distributor.increaseStake(msg.sender, account, shares);
    }

    function decreaseStake(
        address account,
        uint96 shares
    ) external onlyLaunchAsset {
        distributor.decreaseStake(msg.sender, account, shares);
    }

    // @todo this call needs to be simplified. the token can know the pair address and call it directly
    // launchpadLp in the pair is going to be a different address than this, so we cant call it directly here
    // pair just knows the distributor address which is why we pass the call to distributor, or we have to add the launchpad address as well
    function endRewards() external onlyLaunchAsset {
        address quote = _launches[msg.sender].quote;
        // @todo stick with one pair interface
        address pairAddress = uniV2Factory.getPair(msg.sender, quote);
        IPushLaunchpadV2Pair pair = IPushLaunchpadV2Pair(pairAddress);

        distributor.endRewards(pair);
    }

    /*▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀
                            INTERNAL LOGIC
    ▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀*/

    function _checkGraduation(
        address token,
        LaunchData memory data,
        uint256 amountOutBase
    ) internal view returns (uint256 amountOutBaseActual, bool stillActive) {
        uint256 maxBaseForSale = data.curve.bondingSupply(token); // 800 million tokens

        uint256 baseSold = data.curve.baseSoldFromCurve(token); //
        uint256 nextAmountSold = baseSold + amountOutBase;

        // No graduation, can buy full amount of base requested from curve
        if (nextAmountSold < maxBaseForSale) return (amountOutBase, true);

        amountOutBaseActual = maxBaseForSale - baseSold;

        return (amountOutBaseActual, false);
    }

    /// @dev Internal struct to help with stack depth
    struct SwapRemainingData {
        address token;
        address quote;
        address recipient;
        uint256 baseAmount;
        uint256 quoteAmount;
    }

    function _createPairAndSwapRemaining(
        address token,
        IUniswapV2Pair pair,
        LaunchData memory data,
        uint256 remainingBase,
        uint256 remainingQuote,
        address recipient
    ) internal returns (uint256 additionalQuoteUsed) {
        /// @todo sr wardens, please flag in your QA report your thoughts on the comments below

        // Create or get the pair
        address pairAddress = uniV2Factory.getPair(token, data.quote);

        if (pairAddress == address(0)) {
            // Pair doesn't exist, create it
            pairAddress = uniV2Factory.createPair(token, data.quote);
        }

        pair = IUniswapV2Pair(pairAddress);

        pair.skim(owner());

        // Add initial liquidity
        uint256 tokensToLock = data.curve.totalSupply(token) -
            data.curve.bondingSupply(token);
        uint256 quoteToLock = data.curve.quoteBoughtByCurve(token);

        token.safeApprove(address(uniV2Router), tokensToLock);
        data.quote.safeApprove(address(uniV2Router), quoteToLock);

        uniV2Router.addLiquidity({
            tokenA: token,
            tokenB: address(data.quote),
            amountADesired: tokensToLock,
            amountBDesired: quoteToLock,
            amountAMin: 0,
            amountBMin: 0,
            to: address(launchpadLPVault),
            deadline: block.timestamp
        });

        // Handle remaining swap if needed

        // @todo clean up control flow here and confirm this is the right trigger
        if (remainingBase > 0 && remainingQuote > 0) {
            uint256 quoteNeeded = uniV2Router.getAmountIn({
                amountOut: remainingBase,
                reserveIn: quoteToLock,
                reserveOut: tokensToLock
            });

            if (remainingQuote >= quoteNeeded) {
                SwapRemainingData memory d = SwapRemainingData({
                    token: token,
                    quote: data.quote,
                    recipient: recipient,
                    baseAmount: remainingBase,
                    quoteAmount: quoteNeeded
                });

                (, uint256 quoteUsed) = _swapRemaining(d);
                return quoteUsed;
            }
        }

        return 0;
    }

    /// @dev Tries to perform an exact out swap of the remaining quote tokens from a partially filled buy
    function _swapRemaining(
        SwapRemainingData memory data
    ) internal returns (uint256, uint256) {
        // Transfer the remaining quote from the user
        data.quote.safeTransferFrom(
            msg.sender,
            address(this),
            data.quoteAmount
        );

        // Prepare swap path
        address[] memory path = new address[](2);
        path[0] = data.quote;
        path[1] = data.token;

        // Approve router to spend remaining quote
        data.quote.safeApprove(address(uniV2Router), data.quoteAmount);

        try
            uniV2Router.swapTokensForExactTokens(
                data.baseAmount,
                data.quoteAmount,
                path,
                data.recipient,
                block.timestamp + 1
            )
        returns (uint[] memory amounts) {
            // Remove approval
            data.quote.safeApprove(address(uniV2Router), 0);

            // Refund any unused quote tokens (amounts[0] is actual quote used)
            uint256 quoteUsed = amounts[0];
            if (data.quoteAmount > quoteUsed) {
                data.quote.safeTransfer(
                    msg.sender,
                    data.quoteAmount - quoteUsed
                );
            }

            // Return the tokens received and quote actually used
            return (data.baseAmount, quoteUsed);
        } catch {
            // If swap fails, return the additional quote tokens to the user and remove approval
            data.quote.safeApprove(address(uniV2Router), 0);
            data.quote.safeTransfer(msg.sender, data.quoteAmount);
            return (0, 0);
        }
    }

    /// @dev Since the launchpad is the only address able to send or receive launch tokens during bonding,
    /// and an arbitrary `recipient` can be specified for
    function _assertValidRecipient(
        address recipient,
        address baseToken
    ) internal view returns (IUniswapV2Pair pair) {
        address pairAddress = uniV2Factory.getPair(
            baseToken,
            _launches[baseToken].quote
        );
        pair = IUniswapV2Pair(pairAddress);
        if (address(pair) == recipient) revert InvalidRecipient();
    }

    /*▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀
                        UNIVERSAL HELPER FUNCTIONS
    ▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀*/

    /// @notice Gets the origin chain information for a caller
    /// @param caller The address to check
    /// @return account The Universal Account ID struct
    /// @return isUEA True if the address is a UEA, false if it's a native Push Chain user
    function getOriginInfo(
        address caller
    ) public view returns (UniversalAccountId memory account, bool isUEA) {
        // Check if UEA Factory contract exists (has code)
        uint256 size;
        assembly {
            size := extcodesize(0x00000000000000000000000000000000000000eA)
        }

        // If no code at UEA_FACTORY address (test env), treat as native Push Chain user
        if (size == 0) {
            return (account, false);
        }

        // Try to call the UEA Factory - if it fails, return defaults
        try IUEAFactory(UEA_FACTORY).getOriginForUEA(caller) returns (
            UniversalAccountId memory _account,
            bool _isUEA
        ) {
            return (_account, _isUEA);
        } catch {
            // If call fails, treat as native Push Chain user
            return (account, false);
        }
    }

    /// @notice Generates a unique hash for a chain based on namespace and ID
    /// @param chainNamespace The chain namespace (e.g., "eip155", "solana")
    /// @param chainId The chain ID (e.g., "1", "11155111")
    /// @return The keccak256 hash of the concatenated namespace and ID
    function getChainHash(
        string memory chainNamespace,
        string memory chainId
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(chainNamespace, chainId));
    }

    /// @notice Gets the chain hash for the caller's origin
    /// @param caller The address to check
    /// @return chainHash The hash identifying the caller's origin chain
    /// @return isUEA Whether the caller is a UEA (true) or native Push Chain user (false)
    function getCallerChainHash(
        address caller
    ) public view returns (bytes32 chainHash, bool isUEA) {
        (UniversalAccountId memory account, bool _isUEA) = getOriginInfo(
            caller
        );

        if (!_isUEA) {
            // Native Push Chain user
            chainHash = keccak256(abi.encodePacked("pushchain", "testnet"));
        } else {
            // UEA from another chain
            chainHash = getChainHash(account.chainNamespace, account.chainId);
        }

        return (chainHash, _isUEA);
    }

    /// @notice Updates universal tracking stats for a transaction
    /// @param token The token address
    /// @param caller The caller address
    /// @param volume The transaction volume to add
    function _updateUniversalStats(
        address token,
        address caller,
        uint256 volume
    ) internal {
        (bytes32 chainHash, bool isUEA) = getCallerChainHash(caller);

        // Update per-token, per-chain stats
        chainVolume[token][chainHash] += volume;
        chainTxCount[token][chainHash] += 1;

        // Track unique users
        if (!chainUserTracking[token][chainHash][caller]) {
            chainUserTracking[token][chainHash][caller] = true;
        }

        // Update global stats
        globalChainVolume[chainHash] += volume;
        globalChainTxCount[chainHash] += 1;
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function _emitSwapEvent(
        address account,
        address token,
        uint256 baseAmount,
        uint256 quoteAmount,
        bool isBuy,
        IBondingCurveMinimal curve
    ) internal {
        int256 baseDelta = isBuy ? int256(baseAmount) : -int256(baseAmount);
        int256 quoteDelta = isBuy ? -int256(quoteAmount) : int256(quoteAmount);

        emit Swap({
            buyer: account,
            token: token,
            baseDelta: baseDelta,
            quoteDelta: quoteDelta,
            nextAmountSold: curve.baseSoldFromCurve(token), // Current state after trade
            newPrice: curve.quoteBoughtByCurve(token),
            eventNonce: _incEventNonce()
        });

        // Emit universal swap event with origin chain info
        (UniversalAccountId memory originAccount, bool isUEA) = getOriginInfo(
            account
        );

        emit UniversalSwap({
            buyer: account,
            token: token,
            chainNamespace: originAccount.chainNamespace,
            chainId: originAccount.chainId,
            originOwner: originAccount.owner,
            isUEA: isUEA,
            baseDelta: baseDelta,
            quoteDelta: quoteDelta,
            eventNonce: _eventNonce // Use same nonce as Swap event
        });

        // Update universal stats
        _updateUniversalStats(token, account, quoteAmount);
    }

    /// @dev Increments and returns the event nonce
    function _incEventNonce() internal returns (uint256) {
        return ++_eventNonce;
    }
}
