// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3FlashCallback.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract borrow_only is IUniswapV3FlashCallback {
    address private owner;

    address public Pool_borrowed;

    IERC20 public Token_borrowed;
    uint256 start_time;

    modifier onlyOwner(){
        require(msg.sender==owner,"Only owner can call this function");
        _;
    }

    constructor(
        address _Pool_borrowed,
        address _Token_borrowed
    ){
        owner=msg.sender;
        Pool_borrowed=_Pool_borrowed;
        Token_borrowed=IERC20(_Token_borrowed);
    }

    function borow_token(uint256 amount) external onlyOwner{

        IUniswapV3Pool(Pool_borrowed).flash(address(this),amount,0,abi.encode(amount));
        start_time=block.timestamp;
    }

    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external override{
        require(block.timestamp>=start_time+100,"delay is not passed yet");
        uint256 amountBorrowed=abi.decode(data,(uint256));
        uint256 fee = fee0 != 0 ? fee0 : fee1;
        uint256 totaldebt=amountBorrowed+fee;
        Token_borrowed.transfer(msg.sender,totaldebt);

        revert();
    }


}