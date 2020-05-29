pragma solidity ^0.5.0;

import "https://github.com/mrdavey/ez-flashloan/blob/remix/contracts/aave/FlashLoanReceiverBase.sol";
import "https://github.com/mrdavey/ez-flashloan/blob/remix/contracts/aave/ILendingPool.sol";
import "https://github.com/Robsonsjre/FlashloanUsecases/blob/master/contracts/interfaces/IUniswap.sol";


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
contract Arbitrageur is Addresses {
    address public constant DAI_ADDRESS = 0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD;
    address public constant BAT_ADDRESS = 0x61e4CAE3DA7FD189e52a4879C7B8067D7C2Cc0FA;
    address public constant UNISWAP_FACTORY_A = 0x54Ac34e5cE84C501165674782582ADce2FDdc8F4;
    address public constant UNISWAP_FACTORY_B = 0xECc6C0542710a0EF07966D7d1B10fA38bbb86523;

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

        require(daiBought > _amount, "Did not profit");

        // Repay loan
        uint256 totalDebt = _amount.add(_fee);
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
