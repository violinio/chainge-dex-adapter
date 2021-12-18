// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

interface IChaingeDexFactory {
    function getPair(address tokenA, address tokenB, uint256[] calldata time) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);
    function createPair(address tokenA, address tokenB, uint256[] calldata time) external returns (address pair);
}

struct SliceAccount {
    address _address; //token amount
    uint256 tokenStart; //token start blockNumber or timestamp (in secs from unix epoch)
    uint256 tokenEnd; //token end blockNumber or timestamp, use MAX_UINT for timestamp, MAX_BLOCKNUMBER for blockNumber.
}

interface IERC20 {
    function balanceOf(address addr) external view returns (uint256);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
}

interface IChaingePair {
    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    // function approve(address spender, uint value) external returns (bool);
    
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (SliceAccount memory);
    function token1() external view returns (SliceAccount memory);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to, uint256[] calldata time) external returns (uint liquidity);
    function burn(address to, uint256[] calldata time) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address, uint256[] calldata) external;
}

contract WrappedPair {
    uint256 public constant MAX_TIME = 18446744073709551615;

    IChaingePair public pair;

    bool initialized = false;
    function initialize(IChaingePair _pair) external {
        require(!initialized);
        pair = _pair;
    }

    function name() external view returns (string memory) {
        return pair.name();
    }
    function symbol() external view returns (string memory) {
        return pair.symbol();
    }
    function decimals() external view returns (uint8) {
        return pair.decimals();
    }
    function totalSupply() external view returns (uint) {
        return pair.totalSupply();
    }
    function balanceOf(address owner) external view returns (uint) {
        return pair.balanceOf(owner);
    }
    function allowance(address owner, address spender) external view returns (uint) {
        return pair.allowance(owner, spender);
    }

    // function approve(address spender, uint value) external returns (bool);
    
    function transfer(address to, uint value) external returns (bool) {
        revert("not supported");
    }
    function transferFrom(address from, address to, uint value) external returns (bool) {
        revert("not supported");
    }

    function factory() external view returns (address) {
        return pair.factory();
    }
    function token0() public view returns (IERC20) {
        return IERC20(pair.token0()._address);
    }
    function token1() public view returns (IERC20) {
        return IERC20(pair.token1()._address);
    }

    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) {
        return pair.getReserves();
    }
    function price0CumulativeLast() external view returns (uint) {
        return pair.price0CumulativeLast();
    }
    function price1CumulativeLast() external view returns (uint) {
        return pair.price1CumulativeLast();
    }
    function kLast() external view returns (uint) {
        return pair.kLast();
    }

    function mint(address to) external returns (uint liquidity) {
        token0().transfer(address(pair), token0().balanceOf(address(this)));
        token1().transfer(address(pair), token1().balanceOf(address(this)));
    
        return pair.mint(to, getTime());
    }
    function burn(address to) external returns (uint amount0, uint amount1) {
        pair.transfer(address(pair), pair.balanceOf(address(this)));
        return pair.burn(to, getTime());
    }
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external {
        token0().transfer(address(pair), token0().balanceOf(address(this)));
        token1().transfer(address(pair), token1().balanceOf(address(this)));
        pair.swap(amount0Out, amount1Out, to, data);
    }
    function skim(address to) external {
        revert("not supported");
    }
    function sync() external {
        revert("not supported");
    }

    function getTime() internal pure returns (uint256[] memory) {        
        uint256[] memory time = new uint256[](4);
        time[0] = 0;
        time[1] = MAX_TIME;
        time[2] = 0;
        time[3] = MAX_TIME;
        return time;
    }  
}

contract ChaingeDexFactory {
    IChaingeDexFactory public factory;

    mapping(address => mapping (address => address)) wrappedPairs;

    constructor(IChaingeDexFactory _factory) {
        factory = _factory;
    }

    uint256 public constant MAX_TIME = 18446744073709551615;

    event Wrapped(address indexed tokenA, address indexed tokenB, address indexed wrappedPair);

    function wrapPair(address tokenA, address tokenB) external {
        require(wrappedPairs[tokenA][tokenB] == address(0), "already exists");
        address pair = getPair(tokenA, tokenB);
        require(pair != address(0), "underlying pair does not exist");

        WrappedPair wrappedPair = new WrappedPair();
        wrappedPair.initialize(IChaingePair(pair));
        wrappedPairs[tokenA][tokenB] = address(wrappedPair);
        wrappedPairs[tokenB][tokenA] = address(wrappedPair);

        emit Wrapped(tokenA, tokenB, address(wrappedPair));
    }

    function getPair(address tokenA, address tokenB) public view returns(address) {
        if (tokenA > tokenB) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }

        address wrappedPair = wrappedPairs[tokenA][tokenB];
        if(wrappedPair != address(0)) {
            return wrappedPair;
        }

        uint256[] memory time = new uint256[](4);
        time[0] = 0;
        time[1] = MAX_TIME;
        time[2] = 0;
        time[3] = MAX_TIME;
        return factory.getPair(tokenA, tokenB, time);
    }
}
