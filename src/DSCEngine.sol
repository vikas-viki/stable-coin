// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {StableCoin} from "./StableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
/*
 * @title DSCEngine
 * @author viki_wiki
 *
 * The contract is minimalised to maintain a  peg of 1 token = $1
 *
 * The contract has following properties:
 * - Exogenous Colletral.
 * - Dollar pegged.
 * - Algorithmically stable.
 *
 * The contract is designed to be always "Over collateralized", meaning, colletral > total $value of all DSC.
 *
 * @notice This contract is the code of DSC, having all the logic coded for it's expected functionality.
 *
 */

contract DSCEngine is ReentrancyGuard {
    ////////////////////
    // Errors         //
    ////////////////////
    error DSCEngine_MoreThanZeroRequired();
    error DSCEngine_NumberOfTokensAndPricefeedsMustBeSame();
    error DSCEngine_TokenNotAllowed();
    error DSCEngine_CollateralDepositFailed();
    error DSCEngine_InsufficientCollateral(uint256 amount);
    error DSCEngine_MintFailed();

    //////////////////////
    // State variables  //
    //////////////////////
    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_CollateralDeposited;
    mapping(address user => uint256 amount) private s_DSCMinted;

    StableCoin DSC;

    address[] public s_CollateralTokens;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant PRICEFEED_PRECISION = 1e10;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;

    ////////////////////
    // Events         //
    ////////////////////
    event CollateralDeposited(address indexed depositor, address indexed token, uint256 indexed amount);

    ////////////////////
    // Modifiers      //
    ////////////////////
    modifier greaterThanZero(uint256 amount) {
        if (amount <= 0) {
            revert DSCEngine_MoreThanZeroRequired();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine_TokenNotAllowed();
        }
        _;
    }

    ////////////////////
    // Functions      //
    ////////////////////

    constructor(address[] memory tokens, address[] memory priceFeeds, address dscAddress) {
        uint256 tokensLength = tokens.length;

        if (tokensLength != priceFeeds.length) {
            revert DSCEngine_NumberOfTokensAndPricefeedsMustBeSame();
        }

        for (uint256 i = 0; i < tokensLength; i++) {
            s_priceFeeds[tokens[i]] = priceFeeds[i];
            s_CollateralTokens.push(tokens[i]);
        }

        DSC = StableCoin(dscAddress);
    }

    function depositCollateralAndMintDSC() external {}

    /*
     * @notice Follows CEI (Checks[MODIFIERS]-Effects[EVENTS]-Interactions) pattern
     * @param tokenCollateral the token to provide as collateral
     * @param amount the amount of wETH to provide as collateral
     */
    function depositCollateral(address tokenCollateral, uint256 amount)
        external
        greaterThanZero(amount)
        isAllowedToken(tokenCollateral)
        nonReentrant
    {
        s_CollateralDeposited[msg.sender][tokenCollateral] += amount;
        emit CollateralDeposited(msg.sender, tokenCollateral, amount);

        (bool success) = IERC20(tokenCollateral).transferFrom(msg.sender, address(this), amount);

        if (!success) {
            revert DSCEngine_CollateralDepositFailed();
        }
    }

    function redeemCollateralForDSC() external {}

    /*
     * @notice Follows CEI (Checks[MODIFIERS]-Effects[EVENTS]-Interactions) pattern
     * @param amountDSCToMint the amount of DSC to mint\
     * @notice collateral must be greater than the amount of DSC to mint
    */
    function mintDSC(uint256 amountDSCToMint) external greaterThanZero(amountDSCToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDSCToMint;

        _revertIfHealthFactorIsBroken(msg.sender);

        bool minted = DSC.mint(msg.sender, amountDSCToMint);

        if (!minted) {
            revert DSCEngine_MintFailed();
        }
    }

    function burnDSC() external {}

    function liquidate() external {}

    function getHealthFactor() external {}

    ///////////////////////////////////
    // Private & Internal functions  //
    ///////////////////////////////////

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDSCMinted, uint256 totalCollateralValueInUSD)
    {
        totalDSCMinted = s_DSCMinted[user];
        totalCollateralValueInUSD = getAccountCollateralValue(user);
    }

    /*
    * @param user the address of the user
    * @notice gets the health factor of user based on collateral with 18 decimals
    */
    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalDSCMinted, uint256 totalCollateralValueInUSD) = _getAccountInformation(user);

        uint256 collateralAdjustedForThreshold =
            (totalCollateralValueInUSD * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDSCMinted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine_InsufficientCollateral(userHealthFactor);
        }
    }

    ///////////////////////////////////
    // Public & External functions   //
    ///////////////////////////////////

    /*
    * @param The address of the user
    * @notice user gets the total collateral value of the user
    */
    function getAccountCollateralValue(address user) public view returns (uint256 collateralValue) {
        for (uint256 i = 0; i < s_CollateralTokens.length; i++) {
            address token = s_CollateralTokens[i];
            uint256 amount = s_CollateralDeposited[user][token];

            collateralValue += getUSDValue(token, amount);
        }
        return collateralValue;
    }

    /*
    * @param token the address of the token
    * @param amount the amount of the token
    * @notice gets the value of the token in USD
    */
    function getUSDValue(address token, uint256 amount) public view returns (uint256) {
        address priceFeed = s_priceFeeds[token];

        AggregatorV3Interface priceFeedContract = AggregatorV3Interface(priceFeed);

        (, int256 price,,,) = priceFeedContract.latestRoundData();

        return ((uint256(price) * PRICEFEED_PRECISION) * amount) / PRECISION;
    }
}
