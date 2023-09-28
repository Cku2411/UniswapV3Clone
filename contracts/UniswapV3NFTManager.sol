// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "solmate/src/tokens/ERC721.sol";
import "./interfaces/IUniswapV3Pool.sol";
import "../lib/PoolAddress.sol";
import "../lib/LiquidityMath.sol";
import "../lib/TickMath.sol";

error SlippageCheckFailed(uint256 amount0, uint256 amount1);
error WrongToken();

contract UniswapV3NFTManager is ERC721 {
    address public immutable factory;
    uint256 public totalSupply;
    uint256 private nextTokenId;

    // struc to keep links between pool liquidity and NFTs
    struct TokenPosition {
        address pool;
        int24 lowerTick;
        int24 upperTick;
    }

    struct MintParams {
        address recipient;
        address tokenA;
        address tokenB;
        uint24 fee;
        int24 lowerTick;
        int24 upperTick;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
    }

    struct AddLiquidityInternalParams {
        IUniswapV3Pool pool;
        int24 lowerTick;
        int24 upperTick;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
    }

    struct AddLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
    }

    struct RemoveLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
    }

    // Mapping tokenId to TokenPosition
    mapping(uint256 => TokenPosition) public positions;

    // Event
    event Addliquidity(
        uint256 tokenId,
        uint160 liquidity,
        uint256 amount0,
        uint256 amoun1
    );

    // Constructor

    constructor(
        address factoryAddress
    ) ERC721("UniswapV3 NFT Positions", "UNIV3") {
        factory = factoryAddress;
    }

    // MINT NFT

    function mint(MintParams calldata params) public returns (uint256 tokenId) {
        IUniswapV3Pool pool = getPool(params.tokenA, params.tokenB, params.fee);

        (uint128 liquidity, uint256 ammount0, uint256 amount1) = _addliquidity(
            AddLiquidityInternalParams({
                pool: pool,
                lowerTick: params.lowerTick,
                upperTick: params.upperTick,
                amount0Desired: params.amount0Desired,
                amount1Desired: params.amount1Desired,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min
            })
        );

        // Mint NFT
        tokenId = nextTokenId++;
        _mint(params.recipient, tokenId);
        totalSupply++;
        // Store information about new token and new position
        TokenPosition memory tokenPosition = TokenPosition({
            pool: address(pool),
            lowerTick: params.lowerTick,
            upperTick: params.upperTick
        });
        // Mapping tokenId to tokenPosition
        positions[tokenId] = tokenPosition;
    }

    function addLiquidity(
        AddLiquidityParams calldata params
    ) public returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
        TokenPosition memory tokenPosition = positions[params.tokenId];

        // CHeck if pool address is 0x
        if (tokenPosition.pool == address(0x0)) revert WrongToken();

        (liquidity, amount0, amount1) = _addliquidity(
            AddLiquidityInternalParams({
                pool: IUniswapV3Pool(tokenPosition.pool),
                lowerTick: tokenPosition.lowerTick,
                upperTick: tokenPosition.upperTick,
                amount0Desired: params.amount0Desired,
                amount1Desired: params.amount1Desired,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min
            })
        );

        emit Addliquidity(params.tokenId, liquidity, amount0, amount1);
    }

    // function removeLiquidity(
    //     RemoveLiquidityParams calldata params
    // ) public returns (uint256 amount0, uint256 amount1) {
    //     // Get the ToeknPosition
    //     TokenPosition memory tokenPosition = positions[params.tokenId];
    //     if (tokenPosition.pool == address(0x0)) revert WrongToken();

    //     IUniswapV3Pool pool = IUniswapV3Pool(tokenPosition.pool);

    //     (uint128 availableLiquidity, ) = pool.positions(
    //         Pool
    //     )
    // }

    // Helper Function
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        return "";
    }

    function _addliquidity(
        AddLiquidityInternalParams memory params
    ) internal returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
        (uint160 sqrtPriceX96, , , , ) = params.pool.slot0();
        // (uint160 sqrtPriceX96, , , , ) = params.pool.slot0();

        liquidity = LiquidityMath.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(params.lowerTick),
            TickMath.getSqrtRatioAtTick(params.upperTick),
            params.amount0Desired,
            params.amount1Desired
        );

        // Mint liquidity
        (amount0, amount1) = params.pool.mint(
            address(this),
            params.lowerTick,
            params.upperTick,
            liquidity,
            abi.encode(
                IUniswapV3Pool.CallbackData({
                    token0: params.pool.token0(),
                    token1: params.pool.token1(),
                    player: msg.sender
                })
            )
        );

        if (amount0 < params.amount0Min || amount1 < params.amount1Min) {
            revert SlippageCheckFailed(amount0, amount1);
        }
    }

    function getPool(
        address token0,
        address token1,
        uint24 fee
    ) internal view returns (IUniswapV3Pool pool) {
        // sort tokens
        (token0, token1) = token0 < token1
            ? (token0, token1)
            : (token1, token0);

        pool = IUniswapV3Pool(
            PoolAddress.computeAddress(factory, token0, token1, fee)
        );
    }
}
