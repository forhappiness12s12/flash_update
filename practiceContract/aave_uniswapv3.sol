// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/aave/ILendingPool.sol";
import "./interface/aave/ILendingPoolAddressesProvider.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract aave_uniswapv3_flash_loan {
    address private owner;
    address private tokena=address(0);
    address private tokenb=0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address private poola=0xc82819F72A9e77E2c0c3A69B3196478f44303cf4; //small liquidity pool// ETH/USDC
    address private poolb=0x641C00A822e8b671738d32a431a4Fb6074E5c79d; //large liquidity pool// ETH/USDC

    uint256 totaldebt=0;
    ILendingPoolAddressesProvider public addressesProvider=ILendingPoolAddressesProvider(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb); // Arbitrum mainnet addressProvider-0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb
    ILendingPool public lendingPool=ILendingPool(addressesProvider.getLendingPool());
    IUniswapV3Pool public uniswapV3Pool= IUniswapV3Pool(poola); // ETH/USDC pool with small liquidity on arbitrum mainnet-0xc473e2aEE3441BF9240Be85eb122aBB059A3B57c
    
    
    

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor(
        address _owner
    ) {
        owner = _owner;
    }

    function executeFlashloan_uniswap(
        uint256 amountA
    ) external onlyOwner {
        // Request flash loan from Uniswap V3
        uniswapV3Pool.flash(
            address(this),
            amountA,
            0, // Use 0 for assetB or adjust as needed
            abi.encode(tokena, amountA)
        );

        
    }

    function executeFlashloan_aave(
        uint256 amountA) internal{
            // Prepare arrays for Aave flash loan
        address[] memory assets;
        uint256[] memory amounts;
        uint256[] memory modes;

        assets[0] = tokena;
        amounts[0] = amountA;
        modes[0] = 0; // Mode 0 means no debt will be created, repay the loan

        bytes memory data = abi.encode(tokena, amountA);

        // Request flash loan from Aave
        lendingPool.flashLoan(
            address(this), // receiverAddress
            assets, // assets array
            amounts, // amounts array
            modes, // modes array
            address(this), // onBehalfOf
            data, // params
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
        require(initiator == address(this), "Invalid initiator");

        (
            address flashLoanAssetA
        ) = abi.decode(params, (address));
        uint256 repay_aave = amounts[0] + premiums[0];
        totaldebt=totaldebt+repay_aave;

        // Execute Aave flash loan logic
        IERC20(assets[0]).approve(address(this), amounts[0]); // permission of using token assets
        // Example: Swap on Uniswap or any other logic
        swap_uniswap(amounts[0], flashLoanAssetA, tokenb, poola, poolb);
        uint256 remainingfunds=IERC20(flashLoanAssetA).balanceOf(address(this));
        // Repay Aave flash loan

        
        require(remainingfunds>totaldebt,'no profit');
        
        IERC20(assets[0]).approve(address(lendingPool), repay_aave);
        IERC20(assets[0]).transfer(msg.sender, repay_aave);
        //repay,The reason address 'to' is msg.sender is because this function is called by msg.sender of lendingpool
        // IERC20(flashLoanAssetA).transfer(uniswap_pool, repay_uniswap);
        // uint256 remain=IERC20(flashLoanAssetA).balanceOf(address(this));
        // IERC20(flashLoanAssetA).transfer(owner, remain);
        return true;
    }

    // Callback function for Uniswap V3 flash loan
    function uniswapV3FlashCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        require(msg.sender == address(uniswapV3Pool), "Invalid sender");

        (
            address flashLoanAssetA,
            uint256 amountA
            
        ) = abi.decode(data, (address, uint256));
        

        uint256 amountBorrowed1 = abi.decode(data, (uint256));
        uint256 repay_uniswap=amount0+amount1+amountBorrowed1;
        totaldebt=totaldebt+repay_uniswap;
        executeFlashloan_aave(amountA);
        IERC20(flashLoanAssetA).transfer(msg.sender,repay_uniswap);
    }

    function swap_uniswap(
        uint256 amount,
        address token0,
        address token1,
        address pool1,
        address pool2
    ) internal onlyOwner {
        // Approve the first pool to spend token0
        IERC20(token0).approve(pool1, amount);

        // Get the Uniswap V3 pool contract for token0/token1 (pool1)
        IUniswapV3Pool firstPool = IUniswapV3Pool(pool1);

        // Swap token0 -> token1 in pool1
        bool zeroForOneFirst = true; // true means token0 -> token1
        int256 amountSpecifiedFirst = int256(amount); // Amount of token0 to swap
        uint160 sqrtPriceLimitX96First = 0; // No price limit, allowing any price

        // Perform the first swap: token0 -> token1
        firstPool.swap(
            address(this), // Recipient of token1 after the swap
            zeroForOneFirst, // Direction: token0 -> token1
            amountSpecifiedFirst, // Amount of token0 being swapped
            sqrtPriceLimitX96First, // Price limit (0 means no limit)
            abi.encode(amount) // Data passed to the callback function
        );

        // Approve the second pool to spend token1
        uint256 token1Balance = IERC20(token1).balanceOf(address(this));
        IERC20(token1).approve(pool2, token1Balance);

        // Get the Uniswap V3 pool contract for token1/token0 (pool2)
        IUniswapV3Pool secondPool = IUniswapV3Pool(pool2);

        // Swap token1 -> token0 in pool2
        bool zeroForOneSecond = false; // false means token1 -> token0
        int256 amountSpecifiedSecond = int256(token1Balance); // Amount of token1 to swap
        uint160 sqrtPriceLimitX96Second = 0; // No price limit, allowing any price

        // Perform the second swap: token1 -> token0
        secondPool.swap(
            address(this), // Recipient of token0 after the swap
            zeroForOneSecond, // Direction: token1 -> token0
            amountSpecifiedSecond, // Amount of token1 being swapped
            sqrtPriceLimitX96Second, // Price limit (0 means no limit)
            abi.encode(token1Balance) // Data passed to the callback function
        );

        
    }

    // Allow owner to withdraw any remaining tokens
    function withdrawTokens(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner, amount);
    }
}
