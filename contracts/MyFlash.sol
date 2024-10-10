// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/aave/ILendingPool.sol";
import "./interface/aave/ILendingPoolAddressesProvider.sol";
import "./interface/aave/IPool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";
import "./interface/aave/pancakeswap/pancakeswapIQuoter.sol";
import "./interface/aave/pancakeswap/pancakeswapISwapRouter.sol";
import "./interface/aave/camelot/camelotIQuoter.sol";
import "./interface/aave/camelot/camelotISwapRouter.sol";
import "./interface/aave/sushiswap/sushiswapIQuoter.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "hardhat/console.sol";

contract myFlash is Initializable {
    address private owner;
    address private receiver;
    ILendingPoolAddressesProvider public addressesProvider; // Arbitrum mainnet addressProvider-0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb
    IPool public lendingPool;
    ISwapRouter public swapRouter;
    ISwapRouter public sushiswapRouter;
    IQuoter public quoter;
    camelotIQuoter public camelotQuoter;
    pancakeswapIQuoterV2 public pancakeswapQuoter;
    pancakeswapISwapRouter public pancakeSwapRouter;
    sushiswapIQuoterV2 public sushiswapQuoter;
    IUniswapV3Pool public _uniswapPool500;
    IUniswapV3Pool public _uniswapPool300;
    camelotISwapRouter public _camelotSwapRouter;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    


    constructor(address _owner, address _receiver) {
        owner = _owner;
        receiver = _receiver;
        addressesProvider = ILendingPoolAddressesProvider(
            0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb
        );
        lendingPool = IPool(addressesProvider.getPool());
        swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564); //uniswap v3 swapRouter
        quoter = IQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6); // Uniswap v3 Quoter
        camelotQuoter = camelotIQuoter(
            0x0Fc73040b26E9bC8514fA028D998E73A254Fa76E
        ); //camelot v3 quoter
        _camelotSwapRouter = camelotISwapRouter(
            0x1F721E2E82F6676FCE4eA07A5958cF098D339e18
        );
        pancakeswapQuoter = pancakeswapIQuoterV2(
            0xB048Bbc1Ee6b733FFfCFb9e9CeF7375518e25997
        );
        pancakeSwapRouter = pancakeswapISwapRouter(
            0x1b81D678ffb9C0263b24A97847620C99d213eB14
        );
        sushiswapQuoter = sushiswapIQuoterV2(
            0x0524E833cCD057e4d7A296e3aaAb9f7675964Ce1
        ); //https://docs.sushi.com/docs/Products/V3%20AMM/Periphery/Deployment%20Addresses
        sushiswapRouter = ISwapRouter(
            0x8A21F6768C1f8075791D08546Dadf6daA0bE820c
        );
        _uniswapPool500 = IUniswapV3Pool(
            0xC6962004f452bE9203591991D15f6b388e09E8D0
        );
        _uniswapPool300 = IUniswapV3Pool(
            0xc473e2aEE3441BF9240Be85eb122aBB059A3B57c
        );
    }

    struct FlashParams {
        address token;
        address pairtoken;
        uint256 amount;
        uint256 usePath;
        uint256 path1;
        uint256 path2;
    }

    function getEstimate(
        address token,
        uint256 amount,
        address pairToken
    ) public returns (uint256 amount0, uint256[2] memory dexNames) {
        (amount0, dexNames[0]) = _getMaxProfit(token, amount, pairToken);
        console.log("first swap", amount0, dexNames[0]);
        (amount0, dexNames[1]) = _getMaxProfit(pairToken, amount0, token);
        console.log("second swap", amount0, dexNames[1]);

        // require(amount0>estimateResult,"no profit");
    }
    function estimateProfit(
    address token,
    uint256 amount,
    address pairToken
) external onlyOwner returns (uint256, uint256[2] memory) {
    console.log("here is estimateProfit");
    (uint256 amount0, uint256[2] memory dexNames) = getEstimate(token, amount, pairToken);
    console.log("getestimate is finished");
    return (amount0, dexNames);
}


    function callFlash(FlashParams calldata params) external onlyOwner {
        address token = params.token;
        address pairtoken = params.pairtoken;
        uint256 amount = params.amount;
        uint256[2] memory dexNames;
        uint256 amount0;
        // int256 disablePath=-1;
        if (params.usePath == 0) {
            (amount0, dexNames) = getEstimate(token, amount, pairtoken);
        } else {
            console.log("1");
            dexNames[0] = params.path1;
            dexNames[1] = params.path2;
        }
        // require(false,"failed");
        bytes memory data = abi.encode(token, pairtoken, dexNames);

        // Request flash loan from Aave
        lendingPool.flashLoanSimple(
            address(this), // receiverAddress
            token, // assets array
            amount,
            data, // params
            0 // referralCode (set to 0)
        );
    }
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        console.log("executeOperation");
        (address token, address pairtoken, uint256[2] memory dex) = abi.decode(
            params,
            (address, address, uint256[2])
        );

        require(initiator == address(this), "Invalid initiator");
        uint256 repayAmount = amount + premium;
        IERC20(asset).approve(address(this), amount);
        uint256 beforeSwapAmount = IERC20(asset).balanceOf(address(this));
        uint256 afterSwapAmount = beforeSwapAmount;
        console.log("here is swap contract", dex[0]);
        afterSwapAmount = _swapOnDex(dex[0], amount, token, pairtoken);
        afterSwapAmount = _swapOnDex(dex[1], afterSwapAmount, pairtoken, token);
        console.log("afterSwapAmount", afterSwapAmount);
        uint256 remainingfunds = IERC20(asset).balanceOf(address(this));
        require(remainingfunds > repayAmount, "no profit");
        IERC20(asset).transfer(msg.sender, repayAmount);
        remainingfunds = IERC20(asset).balanceOf(address(this));
        IERC20(asset).transfer(receiver, remainingfunds);
        return true;
    }

    // Define a struct to hold multiple return values to avoid too many local variables
    struct QuoteResult {
        uint256 price;
        uint256 fee;
        uint160 sqrtPriceX96After;
        uint32 initializedTicksCrossed;
        uint256 gasEstimate;
    }

    function _getMaxProfit(
        address inputToken,
        uint256 inputAmount,
        address outputToken
    ) internal returns (uint256 amountOut, uint256 dexName) {
        uint256 price = 0;
        amountOut = 0;
        dexName = 0; // default to Uniswap V3

        // Uniswap V3 0.05% Quote//0xC6962004f452bE9203591991D15f6b388e09E8D0
        price = getUniswapV3Quote(inputToken, outputToken, 500, inputAmount);
        if (amountOut < price) {
            amountOut = price;
            dexName = 0; // Uniswap V3
        }
        //Uniswap v3 0.3% Quote//0xc473e2aEE3441BF9240Be85eb122aBB059A3B57c
        price = getUniswapV3Quote(inputToken, outputToken, 3000, inputAmount);
        if (amountOut < price) {
            amountOut = price;
            dexName = 1; // Uniswap V3
        }

        // Camelot Quote
        price = getCamelotV3Quote(inputToken, outputToken, inputAmount);
        if (amountOut < price) {
            amountOut = price;
            dexName = 2; // Camelot
        }

        //PancakeSwap Quote 0.01%//0x7fCDC35463E3770c2fB992716Cd070B63540b947
        QuoteResult memory pancakeResult = getPancakeSwapQuote(
            inputToken,
            outputToken,
            100,
            inputAmount
        );
        if (amountOut < pancakeResult.price) {
            amountOut = pancakeResult.price;
            dexName = 3; // PancakeSwap
        }
        //PancakeSwap Quote 0.05%//0xd9e2a1a61B6E61b275cEc326465d417e52C1b95c
        pancakeResult = getPancakeSwapQuote(
            inputToken,
            outputToken,
            500,
            inputAmount
        );
        if (amountOut < pancakeResult.price) {
            amountOut = pancakeResult.price;
            dexName = 4; // PancakeSwap
        }

        //Sushiswap Quote 0.05%//0xf3Eb87C1F6020982173C908E7eB31aA66c1f0296
        QuoteResult memory sushiswapResult = getSushiswapQuote(
            inputToken,
            outputToken,
            500,
            inputAmount
        );
        if (amountOut < sushiswapResult.price) {
            amountOut = sushiswapResult.price;
            dexName = 5; // sushiswap
        }
        //Sushiswap Quote 0.05%//0xB658eE5c63922d2852f24458efFA2Bfa2cBA3574
        sushiswapResult = getSushiswapQuote(
            inputToken,
            outputToken,
            100,
            inputAmount
        );
        if (amountOut < sushiswapResult.price) {
            amountOut = sushiswapResult.price;
            dexName = 6; // sushiswap
        }

        return (amountOut, dexName);
    }

    // Helper function for Uniswap V3
    function getUniswapV3Quote(
        address inputToken,
        address outputToken,
        uint24 poolFee,
        uint256 inputAmount
    ) internal returns (uint256 price) {
        price = quoter.quoteExactInputSingle(
            inputToken,
            outputToken,
            poolFee,
            inputAmount,
            0
        );
        console.log("uniswap v3", poolFee, price);
        return price;
    }

    // Helper function for Camelot V3
    function getCamelotV3Quote(
        address inputToken,
        address outputToken,
        uint256 inputAmount
    ) internal returns (uint256 price) {
        uint16 fee1;
        (price, fee1) = camelotQuoter.quoteExactInputSingle(
            inputToken,
            outputToken,
            inputAmount,
            0
        );
        console.log("camelot v3", price);
        return price;
    }

    // Helper function for PancakeSwap
    function getPancakeSwapQuote(
        address inputToken,
        address outputToken,
        uint24 poolFee,
        uint256 inputAmount
    ) internal returns (QuoteResult memory result) {
        (
            result.price,
            result.sqrtPriceX96After,
            result.initializedTicksCrossed,
            result.gasEstimate
        ) = pancakeswapQuoter.quoteExactInputSingle(
            pancakeswapIQuoterV2.QuoteExactInputSingleParams(
                inputToken,
                outputToken,
                inputAmount,
                100,
                0
            )
        );
        console.log("pancakeswap price", poolFee, result.price);
        return result;
    }

    //Helper function for SushiSwap
    function getSushiswapQuote(
        address inputToken,
        address outputToken,
        uint24 poolFee,
        uint256 inputAmount
    ) internal returns (QuoteResult memory result) {
        (
            result.price,
            result.sqrtPriceX96After,
            result.initializedTicksCrossed,
            result.gasEstimate
        ) = sushiswapQuoter.quoteExactInputSingle(
            sushiswapIQuoterV2.QuoteExactInputSingleParams(
                inputToken,
                outputToken,
                inputAmount,
                poolFee,
                0
            )
        );
        console.log("sushiswap price", poolFee, result.price);
        return result;
    }

    function _swapOnDex(
        uint256 dex,
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) internal returns (uint256 amountOut) {
        console.log("swap started");
        if (dex == 0) {
            amountOut = _swapOnUniswap3(amountIn, tokenIn, tokenOut, 500);
        }
        if (dex == 1) {
            amountOut = _swapOnUniswap3(amountIn, tokenIn, tokenOut, 3000);
        }
        if (dex == 2) {
            amountOut = _swapOnCamelot(amountIn, tokenIn, tokenOut);
        }
        if (dex == 3) {
            amountOut = _swapOnPancakeSwap(amountIn, tokenIn, tokenOut, 100);
        }
        if (dex == 4) {
            amountOut = _swapOnPancakeSwap(amountIn, tokenIn, tokenOut, 500);
        }
        if (dex == 5) {
            amountOut = _swapOnSushi(amountIn, tokenIn, tokenOut, 500);
        }
        if (dex == 6) {
            amountOut = _swapOnSushi(amountIn, tokenIn, tokenOut, 100);
        }
        return amountOut;
    }
    function _swapOnUniswap3(
        uint256 amountIn,
        address inputToken,
        address outputToken,
        uint24 poolFee
    ) internal returns (uint256 amountOut) {
        // Ensure the user has approved enough tokens
        console.log("amountIn:", amountIn);
        uint256 currentBalance = IERC20(inputToken).balanceOf(address(this));
        console.log("currentBalance", currentBalance);
        require(currentBalance >= amountIn, "Allowance too low");

        // Transfer tokens from msg.sender to this contract
        // IERC20(inputToken).transferFrom(msg.sender, address(this), amountIn);

        // Approve the swapRouter to spend the input token
        IERC20(inputToken).approve(address(swapRouter), amountIn);
        console.log("here");
        // Perform the swap
        amountOut = swapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: inputToken,
                tokenOut: outputToken,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp + 1 hours,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
        console.log("swap is completed");
    }

    function _swapOnCamelot(
        uint256 amountIn,
        address inputToken,
        address outputToken
    ) internal returns (uint256 amountOut) {
        // Ensure the user has approved enough tokens
        console.log("amountIn:", amountIn);
        uint256 currentBalance = IERC20(inputToken).balanceOf(address(this));
        console.log("currentBalance", currentBalance);
        require(currentBalance >= amountIn, "Allowance too low");

        // Transfer tokens from msg.sender to this contract
        // IERC20(inputToken).transferFrom(msg.sender, address(this), amountIn);

        // Approve the swapRouter to spend the input token
        IERC20(inputToken).approve(address(_camelotSwapRouter), amountIn);
        console.log("camelot here");
        // Perform the swap
        amountOut = _camelotSwapRouter.exactInputSingle(
            camelotISwapRouter.ExactInputSingleParams({
                tokenIn: inputToken,
                tokenOut: outputToken,
                recipient: address(this),
                deadline: block.timestamp + 1 hours,
                amountIn: amountIn,
                amountOutMinimum: 0,
                limitSqrtPrice: 0
            })
        );
        console.log("camelotswap is completed");
    }
    function _swapOnPancakeSwap(
        uint256 amountIn,
        address inputToken,
        address outputToken,
        uint24 poolFee
    ) internal returns (uint256 amountOut) {
        // Ensure the user has approved enough tokens
        console.log("amountIn:", amountIn);
        uint256 currentBalance = IERC20(inputToken).balanceOf(address(this));
        console.log("currentBalance", currentBalance);
        require(currentBalance >= amountIn, "Allowance too low");

        // Transfer tokens from msg.sender to this contract
        // IERC20(inputToken).transferFrom(msg.sender, address(this), amountIn);

        // Approve the swapRouter to spend the input token
        IERC20(inputToken).approve(address(pancakeSwapRouter), amountIn);
        console.log("pancake is here");
        // Perform the swap
        amountOut = pancakeSwapRouter.exactInputSingle(
            pancakeswapISwapRouter.ExactInputSingleParams({
                tokenIn: inputToken,
                tokenOut: outputToken,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp + 1 hours,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
        console.log("pancake swap is completed");
    }
    function _swapOnSushi(
        uint256 amountIn,
        address inputToken,
        address outputToken,
        uint24 poolFee
    ) internal returns (uint256 amountOut) {
        // Ensure the user has approved enough tokens
        console.log("amountIn:", amountIn);
        uint256 currentBalance = IERC20(inputToken).balanceOf(address(this));
        console.log("currentBalance", currentBalance);
        require(currentBalance >= amountIn, "Allowance too low");

        // Transfer tokens from msg.sender to this contract
        // IERC20(inputToken).transferFrom(msg.sender, address(this), amountIn);

        // Approve the swapRouter to spend the input token
        IERC20(inputToken).approve(address(sushiswapRouter), amountIn);
        console.log("sushiswap is here");
        // Perform the swap
        amountOut = sushiswapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: inputToken,
                tokenOut: outputToken,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp + 1 hours,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
        console.log("sushi swap is completed");
    }

    // Add a getter for the owner
    function getOwner() external view returns (address) {
        return owner;
    }
    function transferOwnerShip(address newOwner) external onlyOwner {
        owner = newOwner;
    }
    function transferReceiver(address newReceiver) external onlyOwner {
        receiver = newReceiver;
    }
}
