// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
// IMport library
import "../lib/Tick.sol";
import "../lib/Position.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV3MintCallback.sol";
import "./interfaces/IUniswapV3SwapCallback.sol";
import "./interfaces/IUniswapV3FlashCallback.sol";
import "./interfaces/IUniswapV3PoolDeployer.sol";
import "../lib/TickBitmap.sol";
import "../lib/Oracle.sol";
import "../lib/Math.sol";
import "../lib/TickMath.sol";
import "../lib/SwapMath.sol";
import "../lib/LiquidityMath.sol";
import "hardhat/console.sol";

error InvalidTickRange();
error ZeroLiquidity();
error InsufficientInputAmount();
error NotEnoughLiquidity();
error InvalidPriceLimit();
error AlreadyInitialized();
error FlashLoanNotPaid();

contract UniswapV3Pool {
    // Using library
    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(bytes32 => Position.Info); //Using library for type mapping
    using Position for Position.Info; // Using library for type struc
    using TickBitmap for mapping(int16 => uint256);
    using Oracle for Oracle.Observation[65535];

    // Pool tokens
    address public immutable token0;
    address public immutable token1;
    address public immutable factory;
    uint24 public immutable tickSpacing;

    // Packing variables
    struct Slot0 {
        // Current Price
        uint160 sqrtPriceX96;
        int24 tick;
        uint16 observationIndex;
        uint16 observationCardinality; // Maximum number of observations
        uint16 observationCardinalityNext; // Next Maximum number of Observations
    }

    struct CallbackData {
        address token0;
        address token1;
        address player;
    }

    struct SwapState {
        uint256 amountSpecifiedRemaining; //track the remaing amount of tokens that needs to be bought
        uint256 amountCalculated; // AMount calculated by contract
        uint160 sqrtPriceX96;
        int24 tick;
        uint128 liquidity;
        uint256 feeGrowthGlobalX128;
    }

    // track the state of one iteration of an order filling
    struct StepState {
        uint160 sqrtPriceStartX96;
        int24 nextTick;
        uint160 sqrtPriceNext96;
        uint256 amountIn;
        uint256 amountOut;
        uint256 feeAmount;
    }

    struct ModifyPositionParams {
        address owner;
        int24 lowerTick;
        int24 upperTick;
        int128 liquidityDelta;
    }

    Slot0 public slot0;
    Oracle.Observation[65535] public observations;

    // liquidity & Fee
    uint128 public liquidity;
    uint24 public immutable fee;
    uint256 public feeGrowthGlobal0X128;
    uint256 public feeGrowthGlobal1X128;

    // MAPPING
    mapping(int24 => Tick.Info) public ticks;
    mapping(bytes32 => Position.Info) public positions;
    mapping(int16 => uint256) public tickBitmap;

    //EVENT

    event Mint(
        address msgsender,
        address owner,
        int24 lowerTick,
        int24 upperTick,
        uint128 amountLiquidity,
        uint256 indexed amount0,
        uint256 indexed amount1
    );

    event Swap(
        address sender,
        address recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    );

    event Flash(address brrower, uint256 amount0, uint256 amoun1);
    event Burn(
        address owner,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    event Collect(
        address owner,
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1
    );

    event IncreaseObservationCardinalityNext(
        uint16 observationCardinalityNextOld,
        uint16 observationCardinalityNextNew
    );

    /**-----Contructor ---- */
    constructor() {
        (factory, token0, token1, tickSpacing, fee) = IUniswapV3PoolDeployer(
            msg.sender
        ).parameters();
    }

    // INITIALIZE
    //  set Current Price and tick for POOL
    function initialize(uint160 sqrtPriceX96) public {
        if (slot0.sqrtPriceX96 != 0) revert AlreadyInitialized();
        //  set ObserVationCardinality
        (uint16 cardinality, uint16 cardinalityNext) = observations.initialize(
            _blockTimeStamp()
        );
        // set Tick
        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
        slot0 = Slot0({
            sqrtPriceX96: sqrtPriceX96,
            tick: tick,
            observationIndex: 0,
            observationCardinality: cardinality,
            observationCardinalityNext: cardinalityNext
        });
    }

    function _modifiyPosition(
        ModifyPositionParams memory params
    )
        internal
        returns (
            Position.Info storage position,
            uint256 amount0,
            uint256 amount1
        )
    {
        // Gas Optimizations
        Slot0 memory _slot0 = slot0;
        uint256 _feeGrowthGlobal0X128 = feeGrowthGlobal0X128;
        uint256 _feeGrowthGlobal1X128 = feeGrowthGlobal1X128;

        // Get the Position Info
        position = positions.get(
            params.owner,
            params.lowerTick,
            params.upperTick
        );

        bool flippedLower = ticks.update(
            params.lowerTick,
            _slot0.tick,
            int128(params.liquidityDelta),
            _feeGrowthGlobal0X128,
            _feeGrowthGlobal1X128,
            false
        );

        bool flippedUpper = ticks.update(
            params.upperTick,
            _slot0.tick,
            int128(params.liquidityDelta),
            _feeGrowthGlobal0X128,
            _feeGrowthGlobal1X128,
            false
        );

        if (flippedLower) {
            tickBitmap.flipTick(params.lowerTick, int24(tickSpacing));
        }

        if (flippedUpper) {
            tickBitmap.flipTick(params.upperTick, int24(tickSpacing));
        }

        console.log("Position update...");
        // Taking position info
        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) = ticks
            .getFeeGrowthInside(
                params.lowerTick,
                params.upperTick,
                _slot0.tick,
                _feeGrowthGlobal0X128,
                _feeGrowthGlobal1X128
            );

        position.update(
            params.liquidityDelta,
            feeGrowthInside0X128,
            feeGrowthInside1X128
        );

        if (_slot0.tick < params.lowerTick) {
            amount0 = Math.calcAmount0Delta(
                _slot0.sqrtPriceX96, //current price
                TickMath.getSqrtRatioAtTick(params.upperTick),
                uint128(params.liquidityDelta) // liquidity
            );
        } else if (_slot0.tick < params.upperTick) {
            amount0 = Math.calcAmount0Delta(
                _slot0.sqrtPriceX96, //current price
                TickMath.getSqrtRatioAtTick(params.upperTick),
                uint128(params.liquidityDelta) // liquidity
            );

            amount1 = Math.calcAmount1Delta(
                _slot0.sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(params.lowerTick),
                uint128(params.liquidityDelta) // liquidity
            );
            // Update liquidity
            liquidity = LiquidityMath.addLiquidity(
                liquidity,
                params.liquidityDelta
            );
        } else {
            amount1 = Math.calcAmount1Delta(
                TickMath.getSqrtRatioAtTick(params.lowerTick),
                TickMath.getSqrtRatioAtTick(params.upperTick),
                uint128(params.liquidityDelta) // liquidity
            );
        }
    }

    // Mint Liquidity
    function mint(
        address owner,
        int24 lowerTick, // Tick Range
        int24 upperTick, // Tick Range
        uint128 amount, // liquidity
        bytes calldata data // Calbback data
    ) external returns (uint256 amount0, uint256 amount1) {
        // Checking TIcks if ticks in the range
        if (
            lowerTick >= upperTick ||
            lowerTick < TickMath.MIN_TICK ||
            upperTick > TickMath.MAX_TICK
        ) {
            revert InvalidTickRange();
        }

        // CHecking liquidity
        if (amount == 0) revert ZeroLiquidity();

        // Modify Position
        (, uint256 amount0Int, uint256 amount1Int) = _modifiyPosition(
            ModifyPositionParams({
                owner: owner,
                lowerTick: lowerTick,
                upperTick: upperTick,
                liquidityDelta: int128(amount)
            })
        );

        amount0 = uint256(amount0Int);
        amount1 = uint256(amount1Int);

        // Transfer token from owner to the pool
        console.log(
            "Transfer token from owner to the pool  %s  %s",
            amount0,
            amount1
        );
        uint256 balance0Before;
        uint256 balance1Before;

        //
        if (amount0 > 0) balance0Before = _balance0();
        if (amount1 > 0) balance1Before = _balance1();

        //Using callback here
        IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(
            amount0,
            amount1,
            data
        );

        console.log("The ouput amount is  %s  %s", amount0, amount1);

        // Check if token transferd correctly
        if (amount0 > 0 && balance0Before + amount0 > _balance0()) {
            revert InsufficientInputAmount();
        }
        if (amount1 > 0 && balance1Before + amount1 > _balance1()) {
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

    // BURN LIQUIDITY
    function burn(
        int24 lowerTick,
        int24 upperTick,
        uint128 amount
    ) public returns (uint256 amount0, uint256 amount1) {
        // Getting Position
        (
            Position.Info storage position,
            uint256 amount0Int,
            uint256 amount1Int
        ) = _modifiyPosition(
                ModifyPositionParams({
                    owner: msg.sender,
                    lowerTick: lowerTick,
                    upperTick: upperTick,
                    liquidityDelta: -int128(amount)
                })
            );

        amount0 = uint256(amount0Int);
        amount1 = uint256(amount1Int);

        if (amount0 > 0 || amount1 > 0) {
            (position.tokensOwed0, position.tokensOwed1) = (
                position.tokensOwed0 + uint128(amount0),
                position.tokensOwed1 + uint128(amount1)
            );
        }

        emit Burn(msg.sender, lowerTick, upperTick, amount, amount0, amount1);
    }

    // SWAP
    function swap(
        address recipient,
        bool zeroForOne, //Swap direction
        uint256 amountSpecified, // amount want to sell
        uint160 sqrtPriceLimitX96, //Slippage price
        bytes calldata data
    ) public returns (int256 amount0, int256 amount1) {
        // Check input
        console.log(" amountSpecified? %s...", amountSpecified);
        console.log(" sqrtPriceLimitX96? %s...", sqrtPriceLimitX96);

        // Update slot0
        Slot0 memory _slot0 = slot0;
        uint128 _liquidity = liquidity;

        // SeT slippage price
        if (
            zeroForOne
                ? sqrtPriceLimitX96 > _slot0.sqrtPriceX96 ||
                    sqrtPriceLimitX96 < TickMath.MIN_SQRT_RATIO
                : sqrtPriceLimitX96 < _slot0.sqrtPriceX96 &&
                    sqrtPriceLimitX96 > TickMath.MAX_SQRT_RATIO
        ) revert InvalidPriceLimit();

        //----
        console.log(" Get IN swapState...");
        SwapState memory state = SwapState({
            amountSpecifiedRemaining: amountSpecified, //amout need to be swaped
            amountCalculated: 0, // amount swaped
            sqrtPriceX96: _slot0.sqrtPriceX96, // current Price
            tick: _slot0.tick, // current tick
            liquidity: _liquidity, // liquidity,
            feeGrowthGlobalX128: zeroForOne
                ? feeGrowthGlobal0X128
                : feeGrowthGlobal1X128
        });

        console.log(" Starting Loop...");

        // We loop until amountSpecifiedRemaining is 0. Swap done.abi
        while (
            state.amountSpecifiedRemaining > 0 &&
            state.sqrtPriceX96 != sqrtPriceLimitX96
        ) {
            // Create state for each step
            StepState memory step;
            step.sqrtPriceStartX96 = state.sqrtPriceX96; // Step0 curretn state = current price

            //Find tick with liquidity
            (step.nextTick, ) = tickBitmap.nextInitializedTickWithinOneWord(
                state.tick,
                int24(tickSpacing),
                zeroForOne
            );

            console.log("Okie, done find tick with liquidity");

            //Convert tick to price
            step.sqrtPriceNext96 = TickMath.getSqrtRatioAtTick(step.nextTick);

            // Calculate the amounts that can be provider by the current price range.
            (
                state.sqrtPriceX96,
                step.amountIn,
                step.amountOut,
                step.feeAmount
            ) = SwapMath.computeSwapStep(
                state.sqrtPriceX96,
                // find sqrtPriceTargetX96 =
                (
                    zeroForOne
                        ? step.sqrtPriceNext96 < sqrtPriceLimitX96
                        : step.sqrtPriceNext96 > sqrtPriceLimitX96
                )
                    ? sqrtPriceLimitX96
                    : step.sqrtPriceNext96,
                //--
                state.liquidity,
                state.amountSpecifiedRemaining,
                state.feeGrowthGlobalX128
            );

            console.log(
                "Okie, done Calculate the amounts that can be provider by the current price range"
            );

            // Update State
            state.amountSpecifiedRemaining -= step.amountIn;
            state.amountCalculated += step.amountOut;

            if (state.liquidity > 0) {
                state.feeGrowthGlobalX128 += FullMath.mulDiv(
                    step.feeAmount,
                    FixedPoint128.Q128,
                    state.liquidity
                );
            }

            // CHeck if we reached the boundary price range.
            if (state.sqrtPriceX96 == step.sqrtPriceNext96) {
                int128 liquidityDelta = ticks.cross(
                    step.nextTick,
                    (
                        zeroForOne
                            ? state.feeGrowthGlobalX128
                            : feeGrowthGlobal0X128
                    ),
                    (
                        zeroForOne
                            ? feeGrowthGlobal1X128
                            : state.feeGrowthGlobalX128
                    )
                );
                if (zeroForOne) liquidityDelta = -liquidityDelta;

                state.liquidity = LiquidityMath.addLiquidity(
                    state.liquidity,
                    liquidityDelta
                );

                if (state.liquidity == 0) revert NotEnoughLiquidity();

                state.tick = zeroForOne ? step.nextTick - 1 : step.nextTick;
            } else if (state.sqrtPriceX96 != step.sqrtPriceStartX96) {
                state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
            }
        }

        console.log(" Done Loop...");

        // Update contract's State
        // Uniswap track price beofre th first trade in block and last trade in previous block
        if (state.tick != _slot0.tick) {
            (
                uint16 observationIndex,
                uint16 observationCardinality
            ) = observations.write(
                    _slot0.observationIndex,
                    _blockTimeStamp(),
                    _slot0.tick,
                    _slot0.observationCardinality,
                    _slot0.observationCardinalityNext
                );

            (
                slot0.sqrtPriceX96,
                slot0.tick,
                slot0.observationIndex,
                slot0.observationCardinality
            ) = (
                state.sqrtPriceX96,
                state.tick,
                observationIndex,
                observationCardinality
            );
        }

        console.log(" Update StatePrice %s...", state.sqrtPriceX96);

        // console.log("Done Loop %s %s...", state.sqrtPriceX96, state.tick);

        // Update liquidity when crossing a tick
        if (_liquidity != state.liquidity) liquidity = state.liquidity;

        if (zeroForOne) {
            feeGrowthGlobal0X128 = state.feeGrowthGlobalX128;
        } else {
            feeGrowthGlobal1X128 = state.feeGrowthGlobalX128;
        }

        (amount0, amount1) = zeroForOne
            ? (
                int256(amountSpecified - state.amountSpecifiedRemaining),
                -int256(state.amountCalculated)
            )
            : (
                -int256(state.amountCalculated),
                int256(amountSpecified - state.amountSpecifiedRemaining)
            );

        // SENDING TOKEN
        if (zeroForOne) {
            // send Token1 from Pool to user.
            IERC20(token1).transfer(recipient, uint256(-amount1));
            uint256 balance0Before = _balance0();

            // Send token0 from user to pool
            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(
                amount0,
                amount1,
                data
            );

            // Check if the amount of token0 recieve is correct
            if (balance0Before + uint256(amount0) > _balance0()) {
                revert InsufficientInputAmount();
            }
        } else {
            IERC20(token0).transfer(recipient, uint256(-amount0));

            uint256 balance1Before = _balance1();

            // Using callback here
            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(
                amount0,
                amount1,
                data
            );

            if (balance1Before + uint256(amount1) < _balance1()) {
                revert InsufficientInputAmount();
            }
        }

        // emit events
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

    // COLLECT FEE
    function collect(
        address recipient,
        int24 lowerTick,
        int24 upperTick,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) public returns (uint128 amount0, uint128 amount1) {
        Position.Info storage position = positions.get(
            msg.sender,
            lowerTick,
            upperTick
        );

        // Check token amount

        amount0 = amount0Requested > position.tokensOwed0
            ? position.tokensOwed0
            : amount0Requested;

        amount1 = amount1Requested > position.tokensOwed1
            ? position.tokensOwed1
            : amount1Requested;

        // transfer Collected amount

        if (amount0 > 0) {
            position.tokensOwed0 -= amount0;
            // transfer
            IERC20(token0).transfer(recipient, amount0);
        }

        if (amount1 > 0) {
            position.tokensOwed1 -= amount1;
            // transfer
            IERC20(token1).transfer(recipient, amount1);
        }
        // fire an Event
        emit Collect(
            msg.sender,
            recipient,
            lowerTick,
            upperTick,
            amount0,
            amount1
        );
    }

    // FLASHLOAN
    function flash(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) public {
        // Collect Fee
        uint256 fee0 = FullMath.mulDivRoundingUp(amount0, fee, 1e6);
        uint256 fee1 = FullMath.mulDivRoundingUp(amount1, fee, 1e6);

        // take Balance token0, token1 of this contract
        uint256 balance0Before = IERC20(token0).balanceOf(address(this));
        uint256 balance1Before = IERC20(token1).balanceOf(address(this));

        if (amount0 > 0) {
            IERC20(token0).transfer(msg.sender, amount0);
        }
        if (amount1 > 0) IERC20(token1).transfer(msg.sender, amount1);
        // implemented flashLoan
        IUniswapV3FlashCallback(msg.sender).uniswapV3FlashCallback(
            fee0,
            fee1,
            data
        );

        // Check Balance token0, token1 of this contract

        if (IERC20(token0).balanceOf(address(this)) < balance0Before + fee0) {
            revert FlashLoanNotPaid();
        }
        if (IERC20(token1).balanceOf(address(this)) < balance1Before + fee1) {
            revert FlashLoanNotPaid();
        }

        emit Flash(msg.sender, amount0, amount1);
    }

    // Increasee Cardinality
    function increaseObservationCardinalityNext(
        uint16 observationCardinalityNext
    ) public {
        uint16 observationCardinalityNextOld = slot0.observationCardinalityNext;
        uint16 observationCardinalityNextNew = observations.grow(
            observationCardinalityNextOld,
            observationCardinalityNext
        );

        if (observationCardinalityNextNew != observationCardinalityNextOld) {
            // uodate slot0
            slot0.observationCardinalityNext = observationCardinalityNextNew;
            // fire event
            emit IncreaseObservationCardinalityNext(
                observationCardinalityNextOld,
                observationCardinalityNextNew
            );
        }
    }

    // Helper function

    function _balance0() internal view returns (uint256 balance) {
        return balance = IERC20(token0).balanceOf(address(this));
    }

    function _balance1() internal view returns (uint256 balance) {
        return balance = IERC20(token1).balanceOf(address(this));
    }

    function _blockTimeStamp() internal view returns (uint32 timestamp) {
        timestamp = uint32(block.timestamp);
    }
}

// How Cross-Tick Swaps work
// if there's no pool for a pair or tokens, then swapping is not possible.
