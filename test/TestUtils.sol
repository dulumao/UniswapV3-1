// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "../src/UniswapV3Pool.sol";

abstract contract TestUtils {
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
                UniswapV3Pool.CallbackData({
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
