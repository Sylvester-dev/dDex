// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract dLandExchange is ERC20 {

    address public dldTokenAddress;

    // Exchange is inheriting ERC20, becase our exchange would keep track of dld LP tokens
    constructor(address _dldtoken) ERC20("DLD LP Token", "DLP") {
        require(_DLDtoken != address(0), "Token address passed is a null address");
        dldTokenAddress = _dldtoken;
    }

    /** 
    *  @dev Returns the amount of `DLD Tokens` held by the contract
    */
    function getReserve() public view returns (uint) {
        return ERC20(dldTokenAddress).balanceOf(address(this));
    }

  
}