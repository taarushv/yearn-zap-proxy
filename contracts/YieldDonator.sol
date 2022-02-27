// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.11;

import "./libraries/solmate/SafeTransferLib.sol";
import "./libraries/prb-math/PRBMath.sol";
import "./libraries/oz/Ownable.sol";
import "./interface/IYVault.sol";
import "./interface/IWETH.sol";

contract YieldDonator is Ownable {
    using SafeTransferLib for address;
    using SafeTransferLib for ERC20;

    event Deposit(address indexed owner, uint256 amount);

    event Harvest(address indexed harvester, uint256 amount);

    event Withdraw(address indexed owner, uint256 amount);

    IYVault public immutable yearnVault;

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address public immutable donationAddress;

    mapping(address => bool) public acceptedDonationTokens;

    mapping(address => bool) public harvesters;

    mapping(address => bool) public targets;

    mapping(address => uint256) public balanceOf;

    uint256 public totalUnderlyingDeployed;

    bool public paused;

    bool public openHarvest;

    modifier pausable() {
        require(!paused, "Paused");
        _;
    }

    modifier onlyHarvesters() {
        require(openHarvest || harvesters[msg.sender], "Invalid harvester");
        _;
    }

    constructor(address _donationAddress, IYVault _yearnVault) {
        donationAddress = _donationAddress;
        yearnVault = _yearnVault;
        //Enable calldata execution on 0x proxy address for swaps
        targets[0xDef1C0ded9bec7F1a1670819833240f027b25EfF] = true;
    }

    function deposit(
        address sellToken,
        uint256 sellAmount,
        address buyToken,
        address target,
        bytes calldata data,
        uint256 minYTokens
    ) external payable pausable {
        require(buyToken == yearnVault.token(), "Invalid buyToken");
        sellAmount = _pull(sellToken, sellAmount);

        uint256 buyAmount = _execute(
            sellToken,
            buyToken,
            sellAmount,
            target,
            data
        );

        balanceOf[msg.sender] += buyAmount;
        totalUnderlyingDeployed += buyAmount;

        uint256 yTokensRec = _deposit(buyToken, buyAmount);

        require(yTokensRec >= minYTokens, "High slippage");
    }

    function withdraw(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        totalUnderlyingDeployed -= amount;

        uint256 vaultAssets = yearnVault.totalAssets();
        uint256 totalSupply = yearnVault.totalSupply();

        uint256 withdrawAmount = PRBMath.mulDiv(
            amount,
            totalSupply,
            vaultAssets
        );

        yearnVault.withdraw(withdrawAmount, msg.sender);
    }

    function harvest(
        address buyToken,
        address target,
        bytes calldata data,
        uint256 minBuyAmount
    ) external onlyHarvesters {
        require(acceptedDonationTokens[buyToken], "Invalid buyToken");

        uint256 vaultAssets = yearnVault.totalAssets();
        uint256 totalSupply = yearnVault.totalSupply();

        uint256 totalUnderlying = PRBMath.mulDiv(
            yearnVault.balanceOf(address(this)),
            vaultAssets,
            totalSupply
        );
        uint256 yieldEarned = totalUnderlying - totalUnderlyingDeployed;
        uint256 yieldToHarvest = PRBMath.mulDiv(
            yieldEarned,
            totalSupply,
            vaultAssets
        );

        uint256 sellAmount = yearnVault.withdraw((yieldToHarvest));

        uint256 buyAmount = _execute(
            yearnVault.token(),
            buyToken,
            sellAmount,
            target,
            data
        );

        require(buyAmount > minBuyAmount, "High slippage");

        ERC20(buyToken).safeTransfer(donationAddress, buyAmount);
    }

    function _pull(address token, uint256 quantity) internal returns (uint256) {
        if (token == address(0)) {
            require(msg.value > 0, "ETH not sent");
            return msg.value;
        }
        require(msg.value == 0, "ETH sent with token");
        ERC20(token).safeTransferFrom(msg.sender, address(this), quantity);
        return quantity;
    }

    function _execute(
        address sellToken,
        address buyToken,
        uint256 sellAmount,
        address target,
        bytes memory data
    ) internal returns (uint256 amountBought) {
        if (sellToken == buyToken) {
            return sellAmount;
        }

        if (sellToken == address(0) && buyToken == WETH) {
            IWETH(WETH).deposit{value: sellAmount}();
            return sellAmount;
        }

        if (sellToken == WETH && buyToken == address(0)) {
            IWETH(WETH).withdraw(sellAmount);
            return sellAmount;
        }

        uint256 valueToSend;
        if (sellToken == address(0)) {
            valueToSend = sellAmount;
        } else {
            ERC20(sellToken).approve(target, sellAmount);
        }

        ERC20 _buyToken = ERC20(buyToken);
        uint256 initialBalance = _buyToken.balanceOf(address(this));

        require(targets[target], "Unauthorized target");
        (bool success, bytes memory returnData) = target.call{
            value: valueToSend
        }(data);
        require(success, string(returnData));

        amountBought = _buyToken.balanceOf(address(this)) - initialBalance;

        require(amountBought > 0, "Invalid execution");
    }

    function _deposit(address depositToken, uint256 depositAmount)
        internal
        returns (uint256 yTokensRec)
    {
        ERC20 _depositToken = ERC20(depositToken);
        _depositToken.approve(address(yearnVault), 0);
        _depositToken.approve(address(yearnVault), depositAmount);

        yTokensRec = yearnVault.deposit(depositAmount);
    }

    function updateTargets(address target, bool allowed) external onlyOwner {
        targets[target] = allowed;
    }

    function updateAcceptedDonationTokens(address donationToken, bool allowed)
        external
        onlyOwner
    {
        acceptedDonationTokens[donationToken] = allowed;
    }

    function updateHarvesters(address harvester, bool allowed)
        external
        onlyOwner
    {
        harvesters[harvester] = allowed;
    }

    function togglePaused() external onlyOwner {
        paused = !paused;
    }

    function toggleOpenHarvest() external onlyOwner {
        openHarvest = !openHarvest;
    }

    receive() external payable {
        require(msg.sender != tx.origin);
    }
}
