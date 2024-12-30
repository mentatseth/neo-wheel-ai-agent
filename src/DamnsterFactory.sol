// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {INonfungiblePositionManager, IUniswapV3Factory, ExactInputParams, ExactOutputParams, ISwapRouter, MintParams} from "./interfaces/UniInterface.sol";
import {ILockerFactory, ILocker} from "./interfaces/LockerInterface.sol";

import {DamnsterToken} from "./DamnsterToken.sol";
import {HoldingList, IERC20} from "./HoldingList.sol";
import {IWETH9} from "./interfaces/IERC20.sol";
import {TickMath} from "./TickMath.sol";

contract DamnsterFactory is HoldingList, ReentrancyGuardUpgradeable {
    using TickMath for int24;

    error Deprecated();
    error NotAdmin(address user);
    error NotHolder(address user);
    error NotFoundToken(address token);
    error SwapFailed(uint8 cases);

    address public taxCollector;
    uint8 public taxRate;
    ILockerFactory public liquidityLocker;

    bool public deprecated;
    bool public bundleFeeSwitch;

    mapping(address => bool) public admins;

    struct DeploymentInfo {
        address token;
        address deployer;
        address pool;
        uint256 lpNftId;
        address locker;
    }

    struct DevInputInfo {
        address tokenIn;
        uint256 amountIn;
        uint256 amountOut;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    mapping(address => address[]) public tokensDeployedByUsers;
    mapping(address => DeploymentInfo) public tokenInfosDeployedByFactory;

    event TokenCreated(
        address tokenAddress,
        address pool,
        uint256 lpNftId,
        address deployer,
        uint256 fid,
        string name,
        string symbol,
        uint256 supply,
        address lockerAddress,
        string castHash
    );

    modifier onlyHolder(address deployer) {
        if(!admins[msg.sender]) {
            if (msg.sender != owner()) deployer = msg.sender;
            if (!isHolder(deployer)) {
                revert NotHolder(deployer);
            }
        }
        _;
    }

    function initialize(
        address taxCollector_,
        address locker_,
        address owner_
    ) external initializer {
        taxCollector = taxCollector_;
        liquidityLocker = ILockerFactory(locker_);
        taxRate = 25;  // 25 / 1000 -> 2.5 %

        __HoldingList__init(owner_);
    }

    function getTokensDeployedByUser(
        address user
    ) external view returns (address[] memory) {
        return tokensDeployedByUsers[user];
    }

    function deployToken(
        string calldata _name,
        string calldata _symbol,
        uint256 _supply,
        int24 _initialTick,
        uint24 _fee,
        bytes32 _salt,
        address _deployer,
        uint256 _fid,
        string memory _image,
        string memory _castHash,
        DevInputInfo memory devInputInfo
    )
        public
        payable
        onlyHolder(_deployer)
        nonReentrant
        returns (DamnsterToken token, address pool, uint256 tokenId)
    {
        if(devInputInfo.deadline != 0)
            IERC20(devInputInfo.tokenIn).permit(
                msg.sender, 
                address(this), 
                devInputInfo.amountIn, 
                devInputInfo.deadline, 
                devInputInfo.v, 
                devInputInfo.r, 
                devInputInfo.s
            );

        if (deprecated) revert Deprecated();

        ///@dev Target chain must have V3 DEX(e.g. uniswap, pancakeswap ...) Contracts
        // int24 tickSpacing = IUniswapV3Factory(uniswapV3Factory).feeAmountTickSpacing(_fee);
        // require(
        //     tickSpacing != 0 && _initialTick % tickSpacing == 0,
        //     "Invalid tick"
        // );

        token = new DamnsterToken{salt: keccak256(abi.encode(_deployer, _salt))}(
            _name,
            _symbol,
            _supply,
            _deployer,
            _fid,
            _image,
            _castHash
        );

        ///@dev Target chain must have V3 DEX(e.g. uniswap, pancakeswap ...) Contracts
        // require(address(token) < WETH, "Invalid salt");

        // uint160 sqrtPriceX96 = _initialTick.getSqrtRatioAtTick();
        // pool = IUniswapV3Factory(uniswapV3Factory).createPool(address(token), WETH, _fee);
        // IUniswapV3Factory(pool).initialize(sqrtPriceX96);

        // MintParams memory mintParams = MintParams(
        //         address(token),
        //         WETH,
        //         _fee,
        //         _initialTick,
        //         maxUsableTick(tickSpacing),
        //         _supply,
        //         0,
        //         0,
        //         0,
        //         address(this),
        //         block.timestamp
        //     );

        // token.approve(positionManager, _supply);
        // (tokenId, , , ) = INonfungiblePositionManager(positionManager).mint(mintParams);

        // address lockerAddress = liquidityLocker.deploy(
        //     positionManager,
        //     _deployer,
        //     address(this),
        //     tokenId
        // );

        // INonfungiblePositionManager(positionManager).safeTransferFrom(address(this), lockerAddress, tokenId);

        // ILocker(lockerAddress).initializer(tokenId);

        uint256 devAmount = devInputInfo.amountIn;
        if(devAmount > 0) {
            address tokenIn = devInputInfo.tokenIn;
            if(msg.value > 0 && msg.value != devAmount) {
                revert SwapFailed(1);
            }
            
            (,uint256 remainingFundsToBuyTokens) = grabToken(tokenIn, msg.sender, devAmount);
            
            bytes memory path;
            if(tokenIn == WETH) {
                path = abi.encodePacked(address(token), uint24(_fee), WETH);
            } 
            else {
                path = abi.encodePacked(address(token), uint24(_fee), WETH, uint24(3000), tokenIn);
            }

            ExactOutputParams memory swapParams = ExactOutputParams({
                path: path,
                recipient: _deployer,
                amountOut: devInputInfo.amountOut,
                amountInMaximum: remainingFundsToBuyTokens
            });

            IERC20(tokenIn).approve(swapRouter, remainingFundsToBuyTokens);
            uint256 realAmountIn = ISwapRouter(swapRouter).exactOutput(swapParams);

            if(!sendToken(tokenIn, msg.sender, remainingFundsToBuyTokens - realAmountIn)) {
                revert SwapFailed(3);
            }
        }

        ///@dev Target chain must have V3 DEX(e.g. uniswap, pancakeswap ...) Contracts
        ///@dev Locker locks V3 DEX's liquidity NFT. but theres no V3 DEX, so we does not use locker contract
        address lockerAddress = address(1);

        tokensDeployedByUsers[_deployer].push(address(token));
        tokenInfosDeployedByFactory[address(token)] = DeploymentInfo({
            token: address(token),
            deployer: _deployer,
            pool: pool,
            lpNftId: tokenId,
            locker: lockerAddress
        });

        emit TokenCreated(
            address(token),
            pool,
            tokenId,
            _deployer,
            _fid,
            _name,
            _symbol,
            _supply,
            lockerAddress,
            _castHash
        );
    }

    function swapToken(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint24 poolFee,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable nonReentrant returns(uint256 amountOut) {
        if(deadline != 0) IERC20(tokenIn).permit(msg.sender, address(this), amountIn, deadline, v, r, s);
        
        if(msg.value > 0 && msg.value != amountIn) {
            revert SwapFailed(1);
        }
        
        (, uint256 remainingFundsToBuyTokens) = grabToken(tokenIn, msg.sender, amountIn);

        DeploymentInfo memory tokenInfo = tokenInfosDeployedByFactory[tokenIn];
        if(tokenInfo.token != tokenIn) tokenInfo = tokenInfosDeployedByFactory[tokenOut];
        if(tokenInfo.token == address(0)) {
            revert NotFoundToken(address(0));
        }

        IERC20(tokenIn).approve(swapRouter, remainingFundsToBuyTokens);

        bytes memory path;
        if(tokenIn == WETH || tokenOut == WETH) {
            path = abi.encodePacked(tokenIn, uint24(poolFee), tokenOut);
        }
        else if(tokenInfo.token == tokenIn){
            path = abi.encodePacked(tokenIn, uint24(poolFee), WETH, uint24(3000), tokenOut);
        }
        else {
            path = abi.encodePacked(tokenIn, uint24(3000), WETH, uint24(poolFee), tokenOut);
        }

        ExactInputParams memory params = ExactInputParams({
            path: path,
            recipient: address(this),
            amountIn: remainingFundsToBuyTokens,
            amountOutMinimum: 0
        });

        amountOut = ISwapRouter(swapRouter).exactInput(params);
        
        if(!sendToken(tokenOut, msg.sender, amountOut)) {
            revert SwapFailed(3);
        }

        // auto fee collect for token deployer
        ILocker(tokenInfo.locker).collectFees(tokenInfo.deployer, tokenInfo.lpNftId); 
    }

    function sendToken(address token, address to, uint256 amount) internal returns (bool success) {
        if(token == WETH) {
            IWETH9(WETH).withdraw(amount);
            (success, ) = payable(to).call{value: amount}("");  
        }
        else {
            success = IERC20(token).transfer(to, amount);
        }
    }

    function grabToken(address token, address from, uint256 amount) internal returns (bool success, uint256 remained) {
        if(token == WETH && msg.value > 0) { 
            IWETH9(WETH).deposit{value: amount}();
            success = true;
        }
        else {
            success = IERC20(token).transferFrom(from, address(this), amount);
        }

        remained = amount;
        if (bundleFeeSwitch) {
            uint256 protocolFees = (amount * taxRate) / 1000;
            remained = amount - protocolFees;

            if (!sendToken(token, taxCollector, protocolFees)) {
                revert SwapFailed(2);
            }
        }
    }

    function isDamnsterToken(address token) public view returns (bool) {
        return tokenInfosDeployedByFactory[token].token == token;
    }
    
    function setAdmin(address admin, bool isAdmin) external onlyOwner{
        admins[admin] = isAdmin;
    }

    function claimFees(address token) external returns (uint256 tokenFee, uint256 wethFee) {
        DeploymentInfo memory tokenInfo = tokenInfosDeployedByFactory[token];
        if(tokenInfo.token == address(0)) revert NotFoundToken(token);
        
        return ILocker(tokenInfo.locker).collectFees(tokenInfo.deployer, tokenInfo.lpNftId);
    }

    function toggleBundleFeeSwitch(bool _enabled) external onlyOwner {
        bundleFeeSwitch = _enabled;
    }

    function setDeprecated(bool _deprecated) external onlyOwner {
        deprecated = _deprecated;
    }

    function updateTaxCollector(address newCollector) external onlyOwner {
        taxCollector = newCollector;
    }

    function updateLiquidityLocker(address newLocker) external onlyOwner {
        liquidityLocker = ILockerFactory(newLocker);
    }

    function updateTaxRate(uint8 newRate) external onlyOwner {
        taxRate = newRate;
    }

    receive() external payable {}
}

/// @notice Given a tickSpacing, compute the maximum usable tick
function maxUsableTick(int24 tickSpacing) pure returns (int24) {
    unchecked {
        return (TickMath.MAX_TICK / tickSpacing) * tickSpacing;
    }
}
