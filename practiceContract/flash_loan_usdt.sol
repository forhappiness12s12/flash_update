// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3FlashCallback.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract FlashLoanExample1 is IUniswapV3FlashCallback {
    address private owner;

    // Addresses of the pools
    address public usdtWethPool; // Pool 1: USDT/WETH
    address public wethUsdtPool; // Pool 2: WETH/USDT
    address private receiver;

    IERC20 public usdtToken;
    IERC20 public wethToken;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor(
        address _usdtWethPool,
        address _wethUsdtPool,
        address _usdtToken,
        address _wethToken,
        address _receiver
    ) {
        owner = msg.sender;
        usdtWethPool = _usdtWethPool;
        wethUsdtPool = _wethUsdtPool;
        receiver=_receiver;
        usdtToken = IERC20(_usdtToken);
        wethToken = IERC20(_wethToken);
    }

    // Flash loan function, borrowing USDT from the Uniswap pool
    function flashLoan(uint256 amount) external onlyOwner {
        // Call the pool to initiate the flash loan (borrowing USDT)
        IUniswapV3Pool(usdtWethPool).flash(address(this), amount, 0, abi.encode(amount));
    }

    // This callback is called after the flash loan has been issued
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data1
    ) external override {
        uint256 amountBorrowed = abi.decode(data1, (uint256));
        uint256 balanceBefore=usdtToken.balanceOf(address(this));

        // 1. Swap USDT to WETH
        swapUsdtToWeth(amountBorrowed);

        // 2. Swap WETH back to USDT
        uint256 wethBalance = wethToken.balanceOf(address(this));
        swapWethToUsdt(wethBalance);
        uint256 balanceAfter=usdtToken.balanceOf(address(this));

        // 3. Repay the flash loan with fees
        uint256 totalDebt = amountBorrowed + fee0+fee1; // add the flash loan fee
        
        uint256 profit=balanceAfter-balanceBefore-totalDebt;
        if(profit<=0){
            revert("no profit");
        }

        usdtToken.transfer(msg.sender, totalDebt);

        uint256 remainingfunds=usdtToken.balanceOf(address(this));
        if(remainingfunds>0){
            usdtToken.transfer(receiver,remainingfunds);
        }
        
    }

    // Swap USDT to WETH using the USDT/WETH pool
    function swapUsdtToWeth(uint256 amountIn) internal {
        // Approve the pool to spend USDT
        usdtToken.approve(wethUsdtPool, amountIn);

        // Get the Uniswap V3 pool contract for USDT/WETH
        IUniswapV3Pool pool = IUniswapV3Pool(usdtWethPool);

        // Define swap parameters
        bool zeroForOne = true; // true means USDT -> WETH (token0 to token1)
        int256 amountSpecified = int256(amountIn); // Amount of USDT to swap
        uint160 sqrtPriceLimitX96 = 0; // No price limit, allowing any price

        // Call the swap function of the pool
        pool.swap(
            address(this),    // Recipient of WETH after the swap
            zeroForOne,       // Direction: USDT to WETH
            amountSpecified,  // Amount of USDT being swapped
            sqrtPriceLimitX96, // Price limit (0 means no limit)
            abi.encode(amountIn) // Data passed to the callback function
        );
    }

    // Swap WETH to USDT using the WETH/USDT pool
    function swapWethToUsdt(uint256 amountIn) internal {
        // Approve the pool to spend WETH
        wethToken.approve(usdtWethPool, amountIn);

        // Get the Uniswap V3 pool contract for WETH/USDT
        IUniswapV3Pool pool = IUniswapV3Pool(wethUsdtPool);

        // Define swap parameters
        bool zeroForOne = false; // false means WETH -> USDT (token1 to token0)
        int256 amountSpecified = int256(amountIn); // Amount of WETH to swap
        uint160 sqrtPriceLimitX96 = 0; // No price limit, allowing any price

        // Call the swap function of the pool
        pool.swap(
            address(this),     // Recipient of USDT after the swap
            zeroForOne,        // Direction: WETH to USDT
            amountSpecified,   // Amount of WETH being swapped
            sqrtPriceLimitX96, // Price limit (0 means no limit)
            abi.encode(amountIn) // Data passed to the callback function
        );
    }

    // Withdraw remaining tokens from the contract (USDT or WETH)
    function withdraw(IERC20 token, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than zero");
        token.transfer(receiver, amount);
    }
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be the zero address");
        owner = newOwner;
    }

}
