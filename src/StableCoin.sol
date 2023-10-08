// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol"; 
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/*
 * @title StableCoin
 * @author viki_wiki
 * @Collatral ETH
 * @Minting Algorithm
 * 
 * This is just an ERC20 implementation of our stable coin.
 * 
 */

contract StableCoin is ERC20Burnable, Ownable{

    error DSC_MustBeMoreThan0();
    error DSC_InsufficientBalanceToBurn();
    error DSC_ZeroAddress();
    error DSC_LessThan0();

    constructor() ERC20("DectralisedStableCoin", "DSC") Ownable(msg.sender){}

    function burn(uint256 amount) public override onlyOwner{
        uint256 balance = balanceOf(msg.sender);

        if(amount <= 0){
            revert DSC_MustBeMoreThan0();
        }

        if(balance < amount){
            revert DSC_InsufficientBalanceToBurn();
        }

        super.burn(amount);
    }

    function mint(address to, uint256 amount) public onlyOwner returns(bool) {
        if(to == address(0)){
            revert DSC_ZeroAddress();
        }

        if(amount <= 0){
            revert DSC_LessThan0();
        }

        _mint(to, amount);
        return true;
    }
}