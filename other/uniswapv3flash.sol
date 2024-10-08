// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "hardhat/console.sol";

contract uniswapv3_flash {
    address owner;
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
        address poola,
        address poolb,
        address token0,
        address token1,
        address receiveraddress
    ) external onlyOwner {
        IUniswapV3Pool Pool_a = IUniswapV3Pool(poola);
        uint256 amount = amountx + amounty;
        IERC20(token1).approve(address(this), amount);
        Pool_a.flash(
            address(this),
            0,
            amount,
            abi.encode(
                amountx,
                amounty,
                poola,
                poolb,
                token0,
                token1,
                receiveraddress
            )
        );
    }

    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external returns (bool) {
        (
            uint256 amountx,
            uint256 amounty,
            address poola,
            address poolb,
            address token0,
            address token1,
            address receiveraddress
        ) = abi.decode(
                data,
                (uint256, uint256, address, address, address, address, address)
            );
        require(msg.sender == poola, "Invalid sender");
        IERC20(token1).approve(address(this), amounty + amountx);

        uint256 repayment_poola = amountx + amounty + fee0 + fee1;
        console.log("Repayment poola amount:", repayment_poola);

        // // Check balances before swap
        uint256 initialBalanceToken0 = IERC20(token0).balanceOf(address(this));
        uint256 initialBalanceToken1 = IERC20(token1).balanceOf(address(this));
        console.log("Initial balance of token0:", initialBalanceToken0);
        console.log("Initial balance of token1:", initialBalanceToken1);
        swapping(amounty, poola, poolb, token1, token0);

        uint256 remaining_funds = IERC20(token1).balanceOf(address(this));
        console.log("Remaining funds after swap:", remaining_funds);

        require(remaining_funds > initialBalanceToken1 + fee1, "No profit");
        IERC20(token1).approve(msg.sender, repayment_poola);
        IERC20(token1).transfer(msg.sender, repayment_poola);

        uint256 recepta = IERC20(token1).balanceOf(address(this));
        require(
            IERC20(token1).transfer(receiveraddress, recepta),
            "Transfer to receiver failed"
        );

        return true;
    }

    function swapping(
        uint256 amount,
        address poola,
        address poolb,
        address token0,
        address token1
    ) internal {
        IUniswapV3Pool FirstPool = IUniswapV3Pool(poola);

        // Approve token1 for the first pool (token1 -> token0)
        IERC20(token1).approve(poola, amount);

        bool zeroForOneFirst = false; // false means token1 -> token0
        int256 amountSpecifiedFirst = int256(amount); // Amount of token1 to swap
        uint160 sqrtPriceLimitX96First = 0; // No price limit, allowing any price

        uint256 token0before = IERC20(token0).balanceOf(poola);
        uint256 token1before = IERC20(token1).balanceOf(poola);
        console.log(
            "balance of token0 and token1:",
            token0before,
            token1before
        );
        console.log("balance of token1 ::", token1before);

        // Perform the first swap: token1 -> token0
        FirstPool.swap(
            address(this), // Recipient of token0 after the swap
            zeroForOneFirst, // Direction: token1 -> token0
            amountSpecifiedFirst, // Amount of token1 being swapped
            sqrtPriceLimitX96First, // Price limit (0 means no limit)
            abi.encode(true) // Data passed to the callback function
        );

        require(false,'here is failed');
        uint256 token0Balance = IERC20(token0).balanceOf(address(this));

        // Approve token0 for the second pool (token0 -> token1)
        IERC20(token0).approve(poolb, token0Balance);

        IUniswapV3Pool SecondPool = IUniswapV3Pool(poolb);

        // Swap token0 -> token1 in the second pool
        bool zeroForOneSecond = true; // true means token0 -> token1
        int256 amountSpecifiedSecond = int256(token0Balance); // Amount of token0 to swap
        uint160 sqrtPriceLimitX96Second = 0; // No price limit, allowing any price

        // Perform the second swap: token0 -> token1
        SecondPool.swap(
            address(this), // Recipient of token1 after the swap
            zeroForOneSecond, // Direction: token0 -> token1
            amountSpecifiedSecond, // Amount of token0 being swapped
            sqrtPriceLimitX96Second, // Price limit (0 means no limit)
            abi.encode(token0Balance) // Data passed to the callback function
        );
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be the zero address");
        owner = newOwner;
    }
}
