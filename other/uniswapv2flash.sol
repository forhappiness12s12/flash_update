// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "hardhat/console.sol";

contract UniswapFlash {
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor(address _owner) {
        owner = _owner;
    }

    function execute_flash(
        uint256 amountx,
        uint256 amounty,
        address v2Router,
        address v3Pool,
        address token0,
        address token1,
        address receiveraddress
    ) external onlyOwner {
        // Call Uniswap V2 to execute a flash loan
        IUniswapV2Router02 router = IUniswapV2Router02(v2Router);
        router.flashLoan(
            address(this),
            token1,
            amountx + amounty,
            abi.encode(amountx, amounty, v2Router, v3Pool, token0, token1, receiveraddress)
        );
    }

    function uniswapV2FlashCallback(
        address token, 
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external {
        (
            uint256 amountx,
            uint256 amounty,
            address v2Router,
            address v3Pool,
            address token0,
            address token1,
            address receiveraddress
        ) = abi.decode(data, (uint256, uint256, address, address, address, address, address));

        // Repayment
        uint256 repayment = amount + fee;
        console.log("Repayment amount:", repayment);

        // First swap in Uniswap V2 (poola)
        swappingInUniswapV2(amounty, v2Router, token0, token1);

        // Then swap on Uniswap V3 (poolb)
        swappingInUniswapV3(amounty, v3Pool, token0, token1);

        // Ensure you have enough tokens to repay the flash loan
        uint256 remainingFunds = IERC20(token1).balanceOf(address(this));
        require(remainingFunds >= repayment, "Not enough funds to repay the flash loan");

        // Repay the flash loan
        IERC20(token).approve(msg.sender, repayment);
        IERC20(token).transfer(msg.sender, repayment);

        // Transfer remaining funds to the receiver
        require(IERC20(token1).transfer(receiveraddress, remainingFunds), "Transfer to receiver failed");
    }

    function swappingInUniswapV2(
        uint256 amount,
        address v2Router,
        address token0,
        address token1
    ) internal {
        IUniswapV2Router02 router = IUniswapV2Router02(v2Router);

        // Approve token1 for the Uniswap V2 pool
        IERC20(token1).approve(v2Router, amount);

        address;
        path[0] = token1; // Token being sold
        path[1] = token0; // Token being bought

        // Execute the swap on Uniswap V2
        router.swapExactTokensForTokens(
            amount,               // Amount of token1 to swap
            0,                    // Minimum amount of token0 to receive (set to 0 for simplicity)
            path,                 // Path: token1 -> token0
            address(this),        // Recipient of token0
            block.timestamp       // Deadline
        );

        console.log("Swapped in Uniswap V2: Token1 -> Token0");
    }

    function swappingInUniswapV3(
        uint256 amount,
        address v3Pool,
        address token0,
        address token1
    ) internal {
        IUniswapV3Pool pool = IUniswapV3Pool(v3Pool);

        // Approve token0 for the Uniswap V3 pool
        IERC20(token0).approve(v3Pool, amount);

        bool zeroForOne = true; // token0 -> token1 (since we swapped for token0 in V2)
        int256 amountSpecified = int256(amount);
        uint160 sqrtPriceLimitX96 = 0; // No price limit

        // Perform the swap on Uniswap V3
        pool.swap(
            address(this), // Recipient of token1 after the swap
            zeroForOne,     // Direction: token0 -> token1
            amountSpecified,
            sqrtPriceLimitX96,
            abi.encode(true) // Optional data passed to the callback function
        );

        console.log("Swapped in Uniswap V3: Token0 -> Token1");
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be the zero address");
        owner = newOwner;
    }
}
