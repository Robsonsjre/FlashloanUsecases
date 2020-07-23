pragma solidity ^0.5.0;

import "https://github.com/mrdavey/ez-flashloan/blob/remix/contracts/aave/FlashLoanReceiverBase.sol";
import "https://github.com/mrdavey/ez-flashloan/blob/remix/contracts/aave/ILendingPool.sol";
import "https://github.com/Robsonsjre/FlashloanUsecases/blob/master/contracts/interfaces/IUniswap.sol";


//1 DAI = 1000000000000000000 (18 decimals)
/*
 * Arbitrageur is a contract to simulate the usage of flashloans
 * to make profit out of a market inbalacement
 *
 * For this example we deployed 2 Uniswap instances which we'll
 * call by ExchangeA and ExchangeB
 *
 * The steps happens as following:
 * 1. Borrow DAI from Aave
 * 2. Buy BAT with DAI on ExchangeA
 * 3. Sell BAT for DAI on ExchangeB
 * 4. Repay Aave loan
 * 5. Keep the profits
 */
contract Arbitrageur is
    FlashLoanReceiverBase(address(0x506B0B2CF20FAA8f38a4E2B524EE43e1f4458Cc5))
{
    address public constant DAI_ADDRESS = 0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD;
    address public constant BAT_ADDRESS = 0x2d12186Fbb9f9a8C28B3FfdD4c42920f8539D738;
    address public constant UNISWAP_FACTORY_A = 0xECc6C0542710a0EF07966D7d1B10fA38bbb86523;
    address public constant UNISWAP_FACTORY_B = 0x54Ac34e5cE84C501165674782582ADce2FDdc8F4;

    ILendingPool public lendingPool;
    IUniswapExchange public exchangeA;
    IUniswapExchange public exchangeB;
    IUniswapFactory public uniswapFactoryA;
    IUniswapFactory public uniswapFactoryB;

    constructor() public {
        // Instantiate Uniswap Factory A
        uniswapFactoryA = IUniswapFactory(UNISWAP_FACTORY_A);
        // get Exchange A Address
        address exchangeA_address = uniswapFactoryA.getExchange(DAI_ADDRESS);
        // Instantiate Exchange A
        exchangeA = IUniswapExchange(exchangeA_address);

        //Instantiate Uniswap Factory B
        uniswapFactoryB = IUniswapFactory(UNISWAP_FACTORY_B);
        // get Exchange B Address
        address exchangeB_address = uniswapFactoryB.getExchange(BAT_ADDRESS);
        //Instantiate Exchange B
        exchangeB = IUniswapExchange(exchangeB_address);
        // get lendingPoolAddress
        address lendingPoolAddress = addressesProvider.getLendingPool();
        //Instantiate Aaave Lending Pool B
        lendingPool = ILendingPool(lendingPoolAddress);
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
        // Sending back the profits
        require(
            dai.transfer(msg.sender, profit),
            "Could not transfer back the profit"
        );
    }

    function executeOperation(
        address _reserve,
        uint256 _amount,
        uint256 _fee,
        bytes calldata _params
    ) external {
        // If transactions are not mined until deadline the transaction is reverted
        uint256 deadline = getDeadline();

        ERC20 dai = ERC20(DAI_ADDRESS);
        ERC20 bat = ERC20(BAT_ADDRESS);

        // Buying ETH at Exchange A
        require(
            dai.approve(address(exchangeA), _amount),
            "Could not approve DAI sell"
        );

        uint256 tokenBought = exchangeA.tokenToTokenSwapInput(
            _amount,
            1,
            1,
            deadline,
            BAT_ADDRESS
        );

        require(
            bat.approve(address(exchangeB), tokenBought),
            "Could not approve DAI sell"
        );

        // Selling ETH at Exchange B
        uint256 daiBought = exchangeB.tokenToTokenSwapInput(
            tokenBought,
            1,
            1,
            deadline,
            DAI_ADDRESS
        );

        // Repay loan
        uint256 totalDebt = _amount.add(_fee);

        require(daiBought > totalDebt, "Did not profit");

        transferFundsBackToPoolInternal(_reserve, totalDebt);
    }

    function getDeadline() internal view returns (uint256) {
        return now + 3000;
    }
}
