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

    /**
    * @dev Adds liquidity to the exchange.
    */
    function addLiquidity(uint _amount) public payable returns (uint) {
        uint liquidity;
        uint ethBalance = address(this).balance;
        uint dldTokenReserve = getReserve();
        ERC20 dldToken = ERC20(dldTokenAddress);
        /* 
            If the reserve is empty, intake any user supplied value for 
            `Ether` and `DLD` tokens because there is no ratio currently
        */
        if(dldTokenReserve == 0) {
            // Transfer the `dldToken` address from the user's account to the contract
            dldToken.transferFrom(msg.sender, address(this), _amount);
            // Take the current ethBalance and mint `ethBalance` amount of LP tokens to the user.
            // `liquidity` provided is equal to `ethBalance` because this is the first time user 
            // is adding `Eth` to the contract, so whatever `Eth` contract has is equal to the one supplied 
            // by the user in the current `addLiquidity` call
            // `liquidity` tokens that need to be minted to the user on `addLiquidity` call shouls always be propotional
            // to the eth specified by the user
            liquidity = ethBalance;
            _mint(msg.sender, liquidity);
        } else {
            /* 
                If the reserve is not empty, intake any user supplied value for 
                `Ether` and determine according to the ratio how many `DLD` tokens
                need to be supplied to prevent any large price impacts because of the additional
                liquidity
            */
            // EthReserve should be the current ethBalance subtracted by the value of ether sent by the user
            // in the current `addLiquidity` call
            uint ethReserve =  ethBalance - msg.value;
            // Ratio should always be maintained so that there are no major price impacts when adding liquidity
            // Ration here is -> (dldTokenAmount user can add/dldTokenReserve in the contract) = (Eth Sent by the user/Eth Reserve in the contract);
            // So doing some maths, (dldTokenAmount user can add) = (Eth Sent by the user * dldTokenReserve /Eth Reserve);
            uint dldTokenAmount = (msg.value * dldTokenReserve)/(ethReserve);
            require(_amount >= dldTokenAmount, "Amount of tokens sent is less than the minimum tokens required");
            // transfer only (dldTokenAmount user can add) amount of `DLD tokens` from users account
            // to the contract
            dldToken.transferFrom(msg.sender, address(this), dldTokenAmount);
            // The amount of LP tokens that would be sent to the user should be propotional to the liquidity of
            // ether added by the user
            // Ratio here to be maintained is -> 
            // (lp tokens to be sent to the user(liquidity)/ totalSupply of LP tokens in contract) = (eth sent by the user)/(eth reserve in the contract)
            // by some maths -> liquidity =  (totalSupply of LP tokens in contract * (eth sent by the user))/(eth reserve in the contract)
            liquidity = (totalSupply() * msg.value)/ ethReserve;
            _mint(msg.sender, liquidity);
        }
         return liquidity;
    }

    /** 
        @dev Returns the amount Eth/DLD tokens that would be returned to the user
        * in the swap
    */
    function removeLiquidity(uint _amount) public returns (uint , uint) {
        require(_amount > 0, "_amount should be greater than zero");
        uint ethReserve = address(this).balance;
        uint _totalSupply = totalSupply();
        // The amount of Eth that would be sent back to the user is based
        // on a ratio 
        // Ratio is -> (Eth sent back to the user/ Current Eth reserve)  
        // = (amount of LP tokens that user wants to withdraw)/ Total supply of `LP` tokens
        // Then by some maths -> (Eth sent back to the user) 
        // = (Current Eth reserve * amount of LP tokens that user wants to withdraw)/Total supply of `LP` tokens
        uint ethAmount = (ethReserve * _amount)/ _totalSupply;
        // The amount of DLD token that would be sent back to the user is based
        // on a ratio 
        // Ratio is -> (DLD sent back to the user/ Current DLD token reserve)  
        // = (amount of LP tokens that user wants to withdraw)/ Total supply of `LP` tokens
        // Then by some maths -> (DLD sent back to the user/) 
        // = (Current DLD token reserve * amount of LP tokens that user wants to withdraw)/Total supply of `LP` tokens
        uint dldTokenAmount = (getReserve() * _amount)/ _totalSupply;
        // Burn the sent `LP` tokens from the user'a wallet because they are already sent to 
        // remove liquidity
        _burn(msg.sender, _amount);
        // Transfer `ethAmount` of Eth from user's wallet to the contract
        payable(msg.sender).transfer(ethAmount);
        // Transfer `dldTokenAmount` of `DLD` tokens from the user's wallet to the contract 
        ERC20(dldTokenAddress).transfer(msg.sender, dldTokenAmount);
        return (ethAmount, dldTokenAmount);
    }

    /** 
    @dev Returns the amount Eth/DLD tokens that would be returned to the user
    * in the swap
    */
     function getAmountOfTokens(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) public pure returns (uint256) {
        require(inputReserve > 0 && outputReserve > 0, "invalid reserves");
        // We are charging a fees of `1%`
        // Input amount with fees = (input amount - (1*(input amount)/100)) = ((input amount)*99)/100
        uint256 inputAmountWithFee = inputAmount * 99;
        // Because we need to follow the concept of `XY = K` curve
        // We need to make sure (x + Δx)*(y - Δy) = (x)*(y)
        // so the final formulae is Δy = (y*Δx)/(x + Δx);
        // Δy in our case is `tokens to be recieved`
        // Δx = ((input amount)*99)/100, x = inputReserve, y = outputReserve
        // So by putting the values in the formulae you can get the numerator and denominator
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = (inputReserve * 100) + inputAmountWithFee;
        return numerator / denominator;
    }

    /** 
    @dev Swaps Ether for DLD Tokens
    */
    function ethTodldToken(uint _minTokens) public payable {
        uint256 tokenReserve = getReserve();
        // call the `getAmountOfTokens` to get the amount of crypto dev tokens
        // that would be returned to the user after the swap
        // Notice that the `inputReserve` we are sending is equal to  
        //  `address(this).balance - msg.value` instead of just `address(this).balance`
        // because `address(this).balance` already contains the `msg.value` user has sent in the given call
        // so we need to subtract it to get the actual input reserve
        uint256 tokensBought = getAmountOfTokens(
            msg.value,
            address(this).balance - msg.value,
            tokenReserve
        );

        require(tokensBought >= _minTokens, "insufficient output amount");
        // Transfer the `DLD` tokens to the user
        ERC20(dldTokenAddress).transfer(msg.sender, tokensBought);
    }


    /** 
    @dev Swaps dld Tokens for Ether
    */
    function dldTokenToEth(uint _tokensSold, uint _minEth) public {
       uint256 tokenReserve = getReserve();
        // call the `getAmountOfTokens` to get the amount of ether
        // that would be returned to the user after the swap
        uint256 ethBought = getAmountOfTokens(
            _tokensSold,
            tokenReserve,
            address(this).balance
        );
        require(ethBought >= _minEth, "insufficient output amount");
        // Transfer `DLD` tokens from the user's address to the contract
        ERC20(dldTokenAddress).transferFrom(
            msg.sender,
            address(this),
            _tokensSold
        );
        // send the `ethBought` to the user from the contract
        payable(msg.sender).transfer(ethBought);
    }
}