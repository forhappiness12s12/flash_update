// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "hardhat/console.sol";


contract uniswapv3_flash{
    address owner;
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    constructor(
        address _owner
    ) {
        owner = _owner;
    }
    function execute_flash(
        uint256 amountx,
        uint256 amounty,
        address poola,
        address poolb,
        address token0,
        address token1,
        address receiveraddress
    )external onlyOwner {
        IUniswapV3Pool Pool_a=IUniswapV3Pool(poola);
        uint256 amount=amountx+amounty;
        Pool_a.flash(
            address(this),
            0,
            amount,
            abi.encode(amountx,amounty,poola,poolb,token0,token1,receiveraddress)
            );

    }
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external returns (bool){
        (
            uint256 amountx,
            uint256 amounty,
            address poola,
            address poolb,
            address token0,
            address token1,
            address receiveraddress
            
        ) = abi.decode(data, (uint256,uint256,address,address,address,address,address));
         require(msg.sender == poola, "Invalid sender");
         IERC20(token1).approve(address(this), amountx+amounty);
         uint256 repayment_poola=amountx+amounty+fee0+fee1;
         swapping(amounty,poola,poolb,token0,token1);
         uint256 remaining_funds=IERC20(token1).balanceOf(address(this));
         require(remaining_funds>repayment_poola,'no profit');
         IERC20(token1).approve(msg.sender, repayment_poola);
         IERC20(token1).transfer(msg.sender, repayment_poola);
         uint256 recepta=IERC20(token1).balanceOf(address(this));
         IERC20(token1).transfer(receiveraddress,recepta);
            return true;
         
         

    }
    function swapping(uint256 amounty, address poola,address poolb,address token0,address token1) internal{
        IERC20(token1).approve(poola, amounty);
        IUniswapV3Pool firstPool=IUniswapV3Pool(poola);
        bool zeroForOneFirst = false; // true means token1 -> token0
        int256 amountSpecifiedFirst = int256(amounty); // Amount of token0 to swap
        uint160 sqrtPriceLimitX96First = 0; // No price limit, allowing any price

        firstPool.swap(
            address(this), // Recipient of token1 after the swap
            zeroForOneFirst, // Direction: token0 <- token1
            amountSpecifiedFirst, // Amount of token0 being swapped
            sqrtPriceLimitX96First, // Price limit (0 means no limit)
            abi.encode(amounty) // Data passed to the callback function
        );

        uint256 token0Balance=IERC20(token0).balanceOf(address(this));
        IERC20(token0).approve(poolb, token0Balance);

        IUniswapV3Pool secondPool = IUniswapV3Pool(poolb);

        // Swap token1 -> token0 in pool2
        bool zeroForOneSecond = true; // false means token1 <- token0
        int256 amountSpecifiedSecond = int256(token0Balance); // Amount of token1 to swap
        uint160 sqrtPriceLimitX96Second = 0; // No price limit, allowing any price

        // Perform the second swap: token1 -> token0
        secondPool.swap(
            address(this), // Recipient of token0 after the swap
            zeroForOneSecond, // Direction: token1 -> token0
            amountSpecifiedSecond, // Amount of token1 being swapped
            sqrtPriceLimitX96Second, // Price limit (0 means no limit)
            abi.encode(token0Balance) // Data passed to the callback function
        );
    }

        function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be the zero address");
        owner = newOwner;
    }
}