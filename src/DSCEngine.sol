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

    //////////////////////
    // State variables  //
    //////////////////////
    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_CollateralDeposited;

    StableCoin DSC;

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
        }

        DSC = StableCoin(dscAddress);
    }

    function depositCollateralAndMintDSC() external {}

    /*
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
    }

    function redeemCollateralForDSC() external {}

    function mintDSC() external {}

    function burnDSC() external {}

    function liquidate() external {}

    function getHealthFactor() external {}
}
