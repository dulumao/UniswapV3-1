// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "abdk-math/ABDKMath64x64.sol";

import "../src/interfaces/IUniswapV3Pool.sol";
import "../src/lib/FixedPoint96.sol";
import "../src/UniswapV3Pool.sol";

import "./ERC20Mintable.sol";

abstract contract TestUtils {
    // ABDKMath64x64.sqrt takes Q64.64 numbers so we need to convert price to such number.
    // The price is expected to not have the fractional part, so we’re shifting it by 64 bits.
    // The sqrt function also returns a Q64.64 number but TickMath.getTickAtSqrtRatio takes a Q64.96 number
    // this is why we need to shift the result of the square root operation by 96 - 64 bits to the left
    function tick(uint256 price) internal pure returns (int24 tick_) {
        tick_ = TickMath.getTickAtSqrtRatio(
            uint160(
                int160(
                    ABDKMath64x64.sqrt(int128(int256(price << 64))) <<
                        (FixedPoint96.RESOLUTION - 64)
                )
            )
        );
    }

    function encodeError(string memory error)
        internal
        pure
        returns (bytes memory encoded)
    {
        encoded = abi.encodeWithSignature(error);
    }

    function encodeExtra(
        address _token0,
        address _token1,
        address payer
    ) internal pure returns (bytes memory) {
        return
            abi.encode(
                IUniswapV3Pool.CallbackData({
                    token0: _token0,
                    token1: _token1,
                    payer: payer
                })
            );
    }

    function tickBitmap(UniswapV3Pool pool, int24 tick)
        internal
        view
        returns (bool initialized)
    {
        int16 wordPos = int16(tick >> 8);
        uint8 bitPos = uint8(uint24(tick % 256));

        uint256 word = pool.tickBitmap(wordPos);

        initialized = (word & (1 << bitPos)) != 0;
    }
}
