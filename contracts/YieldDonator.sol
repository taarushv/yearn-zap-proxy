// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.11;

import "./solmate/SafeTransferLib.sol";
import "./interface/IYVault.sol";
import "./interface/IWETH.sol";

contract YieldDonator {
    using SafeTransferLib for address;
    using SafeTransferLib for ERC20;

    address public immutable donationAddress;

    IYVault public immutable yearnVault;

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    mapping(address => bool) public targets;

    mapping(address => uint256) public balanceOf;

    bool public stopped;

    uint256 public totalDeployed;

    modifier pausable() {
        require(!stopped, "Paused");
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
        uint256 minTokensRec
    ) external payable pausable {
        sellAmount = _pull(sellToken, sellAmount);

        uint256 buyAmount = _execute(
            sellToken,
            buyToken,
            sellAmount,
            target,
            data
        );

        balanceOf[msg.sender] += buyAmount;

        uint256 yTokensRec = _deposit(buyToken, buyAmount);

        require(yTokensRec >= minTokensRec, "High slippage");

        totalDeployed += yTokensRec;
    }

    function withdraw() external {}

    function harvest() external {}

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
        uint256 intialBalance = yearnVault.balanceOf(address(this));

        ERC20 _depositToken = ERC20(depositToken);
        _depositToken.approve(address(yearnVault), 0);
        _depositToken.approve(address(yearnVault), depositAmount);

        yearnVault.deposit(depositAmount);

        yTokensRec = yearnVault.balanceOf(address(this)) - intialBalance;
    }
}
