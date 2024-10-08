// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/aave/ILendingPool.sol";
import "./interface/aave/ILendingPoolAddressesProvider.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

//1-uniswap
//2-pancakeswap
//3-sushiswap
//4-

contract flash_loan {
    address private owner;
    ILendingPoolAddressesProvider public addressesProvider =
        ILendingPoolAddressesProvider(
            0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb
        );
    ILendingPool public lendingPool =
        ILendingPool(addressesProvider.getLendingPool());

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor(address _owner) {
        owner = _owner;
    }

    function Execute_flash_loan(
        uint256 Amount,
        address Input_token,
        address Output_token,
        uint8 First_swap,
        uint8 Second_swap
    ) external onlyOwner {
        address[] memory assets;
        uint256[] memory amounts;
        uint256[] memory modes;

        assets[0] = Input_token;
        amounts[0] = Amount;
        modes[0] = 0; // Mode 0 means no debt will be created, repay the loan

        bytes memory params = abi.encode(Input_token,Output_token,First_swap,Second_swap);

        // Request flash loan from Aave
        lendingPool.flashLoan(
            address(this), // receiverAddress
            assets, // assets array
            amounts, // amounts array
            modes, // modes array
            address(this), // onBehalfOf
            params, // params
            0 // referralCode (set to 0)
        );
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        require(initiator==address(this),"Invalid initiator");
        (
            address Input_token,
            address Output_token,
            uint8 First_swap,
            uint8 Second_swap
        )=abi.decode(params,(address,address,uint8,uint8));

        uint256 Repayment_aave=amounts[0]+premiums[0];
        IERC20(assets[0]).approve(address(this), amounts[0]);
        Swap_dex(amounts[0],Input_token,Output_token,First_swap);
        Swap_dex(amounts[0],Output_token,Input_token,Second_swap);
        uint256 Remaining_funds=IERC20(assets[0]).balanceOf(address(this));
        require(Remaining_funds>Repayment_aave,'no profit');
        IERC20(assets[0]).approve(address(lendingPool), Repayment_aave);
        IERC20(assets[0]).transfer(msg.sender, Repayment_aave);
        return(true);

    }

    function Swap_dex(
        uint256 amount,
        address Input_token,
        address Output_token,
        uint8 dex
    ) internal{
        if(dex==0){
            swap_onuniswap3(amount,Input_token,Output_token);
        }
        else if(dex==1){
            swap_onuniswap2(amount,Input_token,Output_token);
        }
        else if(dex==2){
            swap_onuniswap2(amount,Input_token,Output_token);
        }
        else if(dex==3){
            swap_onuniswap2(amount,Input_token,Output_token);
        }
        else if(dex==4){
            swap_onuniswap2(amount,Input_token,Output_token);
        }
        else if(dex==5){
            swap_onuniswap2(amount,Input_token,Output_token);
        }
        else if(dex==6){
            swap_onuniswap2(amount,Input_token,Output_token);
        }
        else if(dex==7){
            swap_onuniswap2(amount,Input_token,Output_token);
        }



    }
     function swap_onuniswap3(uint256 amount,address Input_token,address Output_token) internal{

     }
     function swap_onuniswap2(uint256 amount,address Input_token,address Output_token) internal{
     
     }
}
