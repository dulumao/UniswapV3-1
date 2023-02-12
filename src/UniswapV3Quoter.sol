// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "./interfaces/IUniswapV3Pool.sol";
import "./lib/TickMath.sol";

// This contract help us calculate swap amounts without making a swap. Users will type in the amount
// they want to sell, and we want to calculate and show them the amount they’ll get in exchange.
// To calculate swap amounts, we’ll initiate a real swap and will interrupt it in the callback function,
// grabbing the amounts calculated by Pool contract. That is, we have to simulate a real swap to calculate output amount!

// Let’s recap to better understand the algorithm:
// 1. quote calls swap of a pool with input amount and swap direction;
// 2. swap performs a real swap, it runs the loop to fill the input amount specified by user;
// 3. to get tokens from user, swap calls the swap callback on the caller;
// 4. the caller (Quote contract) implements the callback, in which it reverts with output amount, new price, and new tick;
// 5. the revert bubbles up to the initial quote call;
// 6. in quote, the revert is caught, revert reason is decoded and returned as the result of calling quote.
contract UniswapV3Quoter {
    struct QuoteParams {
        address pool;
        uint256 amountIn;
        uint160 sqrtPriceLimitX96;
        bool zeroForOne;
    }

    function quote(QuoteParams memory params)
        public
        returns (
            uint256 amountOut,
            uint160 sqrtPriceX96After,
            int24 tickAfter
        )
    {
        try
            IUniswapV3Pool(params.pool).swap(
                address(this),
                params.zeroForOne,
                params.amountIn,
                params.sqrtPriceLimitX96 == 0
                    ? (
                        params.zeroForOne
                            ? TickMath.MIN_SQRT_RATIO + 1
                            : TickMath.MAX_SQRT_RATIO - 1
                    )
                    : params.sqrtPriceLimitX96,
                // we will decode this to get pool address in uniswapV3SwapCallback
                abi.encode(params.pool)
            )
        {} catch (bytes memory reason) {
            return abi.decode(reason, (uint256, uint160, int24));
        }
    }

    // we'll collect values that we need: output amount, new price, and corresponding tick
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes memory data
    ) external view {
        address pool = abi.decode(data, (address));

        uint256 amountOut = amount0Delta > 0
            ? uint256(-amount1Delta)
            : uint256(-amount0Delta);

        (uint160 sqrtPriceX96After, int24 tickAfter) = IUniswapV3Pool(pool)
            .slot0();

        // For gas optimization, this piece is implemented in Yul, the language used for inline assembly in Solidity.
        assembly {
            let ptr := mload(0x40) // reads the pointer of the next available memory slot (memory in EVM is organized in 32 byte slots)
            mstore(ptr, amountOut) // writes amountOut
            mstore(add(ptr, 0x20), sqrtPriceX96After) // writes sqrtPriceX96After right after amountOut
            mstore(add(ptr, 0x40), tickAfter) // writes tickAfter after sqrtPriceX96After
            revert(ptr, 96) // reverts the call and returns 96 bytes (total length of the values we wrote to memory) of data at address ptr
        }
    }
}
