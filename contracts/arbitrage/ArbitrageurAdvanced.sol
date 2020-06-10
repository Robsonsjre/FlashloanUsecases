pragma solidity ^0.5.0;

import "https://github.com/mrdavey/ez-flashloan/blob/remix/contracts/aave/FlashLoanReceiverBase.sol";
import "https://github.com/mrdavey/ez-flashloan/blob/remix/contracts/aave/ILendingPool.sol";
import "./interfaces/UniswapInterface.sol";


contract Addresses is
    FlashLoanReceiverBase(address(0x506B0B2CF20FAA8f38a4E2B524EE43e1f4458Cc5))
{
    address public constant DAI_ADDRESS = 0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD;
    address public constant UNISWAP_FACTORY_A = 0xECc6C0542710a0EF07966D7d1B10fA38bbb86523;
    address public constant UNISWAP_FACTORY_B = 0x54Ac34e5cE84C501165674782582ADce2FDdc8F4;
}


/*
 * Arbitrageur is a contract to simulate the usage of flashloans
 * to make profit out of a market inbalacement
 *
 * For this example we deployed 2 Uniswap instances which we'll
 * call by ExchangeA and ExchangeB
 *
 * The steps happens as following:
 * 1. Borrow DAI from Aave
 * 2. Buy ETH with DAI on ExchangeA
 * 3. Sell ETH for DAI on ExchangeB
 * 4. Repay Aave loan
 * 5. Keep the profits
 */
contract Arbitrageur is Addresses {
    ILendingPool public lendingPool;
    UniswapExchangeInterface public exchangeA;
    UniswapExchangeInterface public exchangeB;
    UniswapFactoryInterface public uniswapFactoryA;
    UniswapFactoryInterface public uniswapFactoryB;

    event Profit(uint256 amount);

    constructor() public {
        uniswapFactoryA = UniswapFactoryInterface(UNISWAP_FACTORY_A);
        exchangeA = UniswapExchangeInterface(
            uniswapFactoryA.getExchange(DAI_ADDRESS)
        );

        uniswapFactoryB = UniswapFactoryInterface(UNISWAP_FACTORY_B);
        exchangeB = UniswapExchangeInterface(
            uniswapFactoryB.getExchange(DAI_ADDRESS)
        );

        lendingPool = ILendingPool(addressesProvider.getLendingPool());
    }

    /*
     * Start the arbitrage
     */
    function makeArbitrage(uint256 amount) public onlyOwner {
        bytes memory data = "";

        ERC20 dai = ERC20(DAI_ADDRESS);

        lendingPool.flashLoan(address(this), DAI_ADDRESS, amount, data);

        // Any left amount of DAI is considered profit
        uint256 profit = dai.balanceOf(address(this));
        emit Profit(profit);

        // Sending back the profits
        require(
            dai.transfer(msg.sender, profit),
            "Could not transfer back the profit"
        );
    }

    /*
     * Called by lending pool to settle the loan operation
     */
    function executeOperation(
        address _reserve,
        uint256 _amount,
        uint256 _fee,
        bytes calldata _params
    ) external {
        require(
            _amount <= getBalanceInternal(address(this), _reserve),
            "Invalid balance, was the flashLoan successful?"
        );

        // If transactions are not mined until deadline the transaction is reverted
        uint256 deadline = getDeadline();

        ERC20 dai = ERC20(DAI_ADDRESS);

        // Buying ETH at Exchange A
        require(
            dai.approve(address(exchangeA), _amount),
            "Could not approve DAI sell"
        );

        uint256 ethBought = exchangeA.tokenToEthSwapInput(_amount, 1, deadline);

        // Selling ETH at Exchange B
        uint256 daiBought = exchangeB.ethToTokenSwapInput.value(ethBought)(
            1,
            deadline
        );

        // Repay loan
        uint256 totalDebt = _amount.add(_fee);

        require(daiBought > totalDebt, "Did not profit");

        transferFundsBackToPoolInternal(_reserve, totalDebt);
    }

    function getDeadline() internal returns (uint256) {
        return now + 3000;
    }

    /*
     * Increase the price difference between both exchanges
     * so there can still be arbitrage oportunities in the
     * example
     */
    function imbalanceExchanges(uint256 _amount) external {
        ERC20 dai = ERC20(DAI_ADDRESS);
        require(
            dai.transferFrom(msg.sender, address(this), _amount),
            "Could not tranfer DAI"
        );
        require(
            dai.approve(address(exchangeB), _amount),
            "Could not approve DAI sell"
        );

        exchangeB.tokenToEthTransferInput(
            _amount,
            1,
            getDeadline(),
            msg.sender
        );
    }
}
