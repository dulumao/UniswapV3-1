// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV3MintCallback.sol";
import "./interfaces/IUniswapV3SwapCallback.sol";
import "./interfaces/IUniswapV3FlashCallback.sol";
import "./interfaces/IUniswapV3Pool.sol";

import "./lib/LiquidityMath.sol";
import "./lib/Math.sol";
import "./lib/Position.sol";
import "./lib/SwapMath.sol";
import "./lib/Tick.sol";
import "./lib/TickBitmap.sol";
import "./lib/TickMath.sol";

contract UniswapV3Pool is IUniswapV3Pool {
    using Tick for mapping(int24 => Tick.Info);
    using TickBitmap for mapping(int16 => uint256);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;

    // // Each tick has an index i and corresponds to a certain price p(i) = 1.0001^i
    // // Taking powers of 1.0001 has a desi desirable property: the difference between two adjacent ticks is 0.01% or 1 basis point.
    // // Ticks are integers that can be positive and negative and, of course, they’re not infinite.
    // // Uniswap V3 stores sqrt(P) as a fixed point Q64.96 number, which is a rational number that
    // // uses 64 bits for the integer part and 96 bits for the fractional part.
    // // Thus, prices (equal to the square of P) are within the range [2^-128, 2^128].
    // // And ticks are within the range [−887272,887272]
    // int24 internal constant MIN_TICK = -887272;
    // int24 internal constant MAX_TICK = -MIN_TICK;

    // Pool tokens, immutable
    address public immutable token0;
    address public immutable token1;

    // We need to track the current price and the related tick.
    // We’ll store them in one storage slot to optimize gas consumption
    Slot0 public slot0;

    // Amount of liquidity, L
    uint128 public liquidity;

    // Ticks info
    mapping(int24 => Tick.Info) public ticks;
    // Positions info
    mapping(bytes32 => Position.Info) public positions;
    // Tick bit mapping
    mapping(int16 => uint256) public tickBitmap;

    constructor(
        address _token0,
        address _token1,
        uint160 sqrtPriceX96,
        int24 tick
    ) {
        token0 = _token0;
        token1 = _token1;

        slot0 = Slot0({sqrtPriceX96: sqrtPriceX96, tick: tick});
    }

    function mint(
        address owner,
        int24 lowerTick,
        int24 upperTick,
        uint128 amount,
        bytes calldata data
    )
        external
        returns (
            //bytes calldata data
            uint256 amount0,
            uint256 amount1
        )
    {
        if (
            lowerTick >= upperTick ||
            lowerTick < TickMath.MIN_TICK ||
            upperTick > TickMath.MAX_TICK
        ) revert InvalidTickRange();

        if (amount == 0) revert ZeroLiquidity();

        bool flippedLower = ticks.update(lowerTick, int128(amount), false);
        bool flippedUpper = ticks.update(upperTick, int128(amount), true);

        // Only flip when liquidity is added to an empty tick or
        // when entire liquidity is removed from a tick
        if (flippedLower) {
            tickBitmap.flipTick(lowerTick, 1);
        }

        if (flippedUpper) {
            tickBitmap.flipTick(upperTick, 1);
        }

        Position.Info storage position = positions.get(
            owner,
            lowerTick,
            upperTick
        );
        position.update(amount);

        Slot0 memory slot0_ = slot0;

        if (slot0_.tick < lowerTick) {
            // If the price range is above the current price, we want the liquidity to be composed of token0
            amount0 = Math.calcAmount0Delta(
                TickMath.getSqrtRatioAtTick(lowerTick),
                TickMath.getSqrtRatioAtTick(upperTick),
                amount
            );
        } else if (slot0_.tick < upperTick) {
            // When the price range includes the current price, we want both tokens in amounts proportional to the price
            amount0 = Math.calcAmount0Delta(
                slot0_.sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(upperTick),
                amount
            );

            amount1 = Math.calcAmount1Delta(
                slot0_.sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(lowerTick),
                amount
            );

            // amount is negative when removing liquidity
            liquidity = LiquidityMath.addLiquidity(liquidity, int128(amount));
        } else {
            // If the price range is below the current price, we want the range to contain only token1
            amount1 = Math.calcAmount1Delta(
                TickMath.getSqrtRatioAtTick(lowerTick),
                TickMath.getSqrtRatioAtTick(upperTick),
                amount
            );
        }

        uint256 balance0Before;
        uint256 balance1Before;

        if (amount0 > 0) balance0Before = balance0();
        if (amount1 > 0) balance1Before = balance1();

        // This is the callback. It’s expected that the caller (whoever calls mint)
        //is a contract because non-contract addresses cannot implement functions in Ethereum
        IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(
            amount0,
            amount1,
            data
        );

        // check if the token is transfered to the pool
        if (amount0 > 0 && balance0Before + amount0 > balance0()) {
            revert InsufficientInputAmount();
        }
        if (amount1 > 0 && balance1Before + amount1 > balance1()) {
            revert InsufficientInputAmount();
        }

        emit Mint(
            msg.sender,
            owner,
            lowerTick,
            upperTick,
            amount,
            amount0,
            amount1
        );
    }

    function swap(
        address recipient,
        bool zeroForOne,
        uint256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) public returns (int256 amount0, int256 amount1) {
        // Caching for gas saving
        Slot0 memory slot0_ = slot0;
        uint128 _liquidity = liquidity;

        // To protect swaps from sandwich attacks, we need to add one more sqrtPriceLimitX96 parameter to
        // swap function, we want to let user choose a stop price, a price at which swapping will stop.
        if (
            zeroForOne
                ? sqrtPriceLimitX96 > slot0_.sqrtPriceX96 ||
                    sqrtPriceLimitX96 < TickMath.MIN_SQRT_RATIO
                : sqrtPriceLimitX96 < slot0_.sqrtPriceX96 ||
                    sqrtPriceLimitX96 > TickMath.MAX_SQRT_RATIO
        ) {
            revert InvalidPriceLimit();
        }

        SwapState memory state = SwapState({
            amountSpecifiedRemaining: amountSpecified,
            amountCalculated: 0,
            sqrtPriceX96: slot0_.sqrtPriceX96,
            tick: slot0_.tick,
            liquidity: _liquidity
        });

        // We’ll loop until amountSpecifiedRemaining is 0, which will mean
        // that the pool has enough liquidity to buy amountSpecified tokens from user.
        // or when sqrtPriceX96 equals sqrtPriceLimitX96
        while (
            state.amountSpecifiedRemaining > 0 &&
            state.sqrtPriceX96 != sqrtPriceLimitX96
        ) {
            StepState memory step;

            step.sqrtPriceStartX96 = state.sqrtPriceX96;

            (step.nextTick, ) = tickBitmap.nextInitializedTickWithinOneWord(
                state.tick,
                1,
                zeroForOne
            );

            step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.nextTick);

            (state.sqrtPriceX96, step.amountIn, step.amountOut) = SwapMath
                .computeSwapStep(
                    state.sqrtPriceX96,
                    // check if sqrtPriceNextX96 exceed sqrtPriceLimitX96
                    (
                        zeroForOne // (sqrtPrice is descreased)
                            ? step.sqrtPriceNextX96 < sqrtPriceLimitX96
                            : step.sqrtPriceNextX96 > sqrtPriceLimitX96
                    )
                        ? sqrtPriceLimitX96
                        : step.sqrtPriceNextX96,
                    state.liquidity,
                    state.amountSpecifiedRemaining
                );

            state.amountSpecifiedRemaining -= step.amountIn;
            state.amountCalculated += step.amountOut;

            // current price is reaching a boundary of the price range
            if (state.sqrtPriceX96 == step.sqrtPriceNextX96) {
                int128 liquidityDelta = ticks.cross(step.nextTick);

                // By convention, crossing a tick means crossing it from left to right.
                // Thus, crossing lower ticks always adds liquidity and crossing upper ticks always removes it.
                if (zeroForOne) {
                    // when zeroForOne is true (token0 is being sold). By convention, the liquidity of upper tick is added
                    // and the liquidity of lower tick is subtracted from it.
                    // Think of it this way: if the buyer buys a token for $100, but the token is worth $110 on the current range,
                    // they have effectively added $10 in value to the pool of liquidity. This is because they now have a token
                    // that is worth $10 more than what they paid for it, and that extra value is now a part of the pool.
                    // On the other hand, when sell the token at a price that is higher than the current tick range
                    // it means that they received more value for the token than what it is currently worth. This extra value that
                    // they received by selling the token at a higher price effectively decreases the size of the pool of liquidity

                    // However, when zeroForOne is true, we negate the sign: when price goes down (toke0 is being sold),
                    // upper ticks add liquidity and lower ticks remove it
                    liquidityDelta = -liquidityDelta;
                }

                // update state liquidity of the contract
                state.liquidity = LiquidityMath.addLiquidity(
                    state.liquidity,
                    liquidityDelta
                );

                if (state.liquidity == 0) {
                    revert NotEnoughLiquidity();
                }

                // If price moves down (zeroForOne is true), we need to subtract 1 to step out of the price range.
                // When moving up (zeroForOne is false), current tick is always excluded in TickBitmap.nextInitializedTickWithinOneWord
                state.tick = zeroForOne ? step.nextTick - 1 : step.nextTick;
            } else if (state.sqrtPriceX96 != step.sqrtPriceStartX96) {
                state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
            }
        }

        // need to update the current tick and sqrtP of contract state
        if (state.tick != slot0_.tick) {
            (slot0.sqrtPriceX96, slot0.tick) = (state.sqrtPriceX96, state.tick);
        }

        // need to update global contract liquidity when crossing a tick
        if (_liquidity != state.liquidity) {
            liquidity = state.liquidity;
        }

        (amount0, amount1) = zeroForOne
            ? (
                int256(amountSpecified - state.amountSpecifiedRemaining),
                // minus sign because the amount of token after is less than before in the pool
                -int256(state.amountCalculated)
            )
            : (
                // minus sign because the amount of token after is less than before in the pool
                -int256(state.amountCalculated),
                int256(amountSpecified - state.amountSpecifiedRemaining)
            );

        if (zeroForOne) {
            // sends tokens to the recipient and lets the caller transfer the input amount into the contract
            IERC20(token1).transfer(recipient, uint256(-amount1));
            uint256 balance0Before = balance0();
            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(
                amount0,
                amount1,
                data
            );

            // check if the token is transfered to the pool
            if (balance0Before + uint256(amount0) > balance0()) {
                revert InsufficientInputAmount();
            }
        } else {
            // sends tokens to the recipient and lets the caller transfer the input amount into the contract
            IERC20(token0).transfer(recipient, uint256(-amount0));
            uint256 balance1Before = balance1();
            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(
                amount0,
                amount1,
                data
            );

            // check if the token is transfered to the pool
            if (balance1Before + uint256(amount1) > balance1()) {
                revert InsufficientInputAmount();
            }
        }

        emit Swap(
            msg.sender,
            recipient,
            amount0,
            amount1,
            slot0.sqrtPriceX96,
            liquidity,
            slot0.tick
        );
    }

    // Implement flash loans: unlimited and uncollateralized loans that must be repaid in the same transaction.
    // Pools basically give users arbitrary amounts of tokens that they request, but, by the end of the call,
    // the amounts must be repaid, with a small fee on top
    function flash(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) public {
        uint256 balance0Before = IERC20(token0).balanceOf(address(this));
        uint256 balance1Before = IERC20(token1).balanceOf(address(this));

        if (amount0 > 0) IERC20(token0).transfer(msg.sender, amount0);
        if (amount1 > 0) IERC20(token1).transfer(msg.sender, amount1);

        IUniswapV3FlashCallback(msg.sender).uniswapV3FlashCallback(data);

        require(IERC20(token0).balanceOf(address(this)) >= balance0Before);
        require(IERC20(token1).balanceOf(address(this)) >= balance1Before);

        emit Flash(msg.sender, amount0, amount1);
    }

    function balance0() internal returns (uint256 balance) {
        balance = IERC20(token0).balanceOf(address(this));
    }

    function balance1() internal returns (uint256 balance) {
        balance = IERC20(token1).balanceOf(address(this));
    }
}
