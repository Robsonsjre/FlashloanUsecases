pragma solidity ^0.5.0;

import "https://github.com/mrdavey/ez-flashloan/blob/remix/contracts/aave/FlashLoanReceiverBase.sol";
import "https://github.com/mrdavey/ez-flashloan/blob/remix/contracts/aave/ILendingPool.sol";
import "https://github.com/mrdavey/ez-flashloan/blob/remix/contracts/aave/ILendingPoolAddressesProvider.sol";
import "https://github.com/aave/aave-protocol/blob/master/contracts/configuration/LendingPoolParametersProvider.sol";
import "./interfaces/UniswapInterface.sol";
import "./interfaces/KyberNetworkProxyInterface.sol";

contract ConstantAddresses is FlashLoanReceiverBase(address(0x24a42fD28C976A61Df5D00D0599C34c4f90748c8)) {
    address public constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant KYBER_INTERFACE = 0x818E6FECD516Ecc3849DAf6845e3EC868087B755;
    address public constant UNISWAP_FACTORY = 0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95;
    address public constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
}

/*
1e18 - 1000000000000000000
DAI to USDC by Uniswap
USDC to ETH by Kyber
ETH to DAI by Uniswap
*/
contract Arbitrageur is ConstantAddresses {
    ERC20 public asset;
    ILendingPool public lendingPool;
    LendingPoolParametersProvider public parametersProvider;
    UniswapFactoryInterface public uniswapFactory;
    UniswapExchangeInterface public uniswapDAIExchange;
    KyberNetworkProxyInterface public kyberNetworkProxy;
    
    constructor () public {
        kyberNetworkProxy = KyberNetworkProxyInterface(KYBER_INTERFACE);
        uniswapFactory = UniswapFactoryInterface(UNISWAP_FACTORY);
        uniswapDAIExchange = UniswapExchangeInterface(
            uniswapFactory.getExchange(DAI_ADDRESS)
        );
        
        asset = ERC20(DAI_ADDRESS);
        
        lendingPool = ILendingPool(
            addressesProvider.getLendingPool()
        );
        
        parametersProvider = LendingPoolParametersProvider(
            addressesProvider.getLendingPoolParametersProvider()
        );
    }
    
    /* 
     * Start the arbitrage
     */
    function makeArbitrage(uint256 _amount) public onlyOwner {
        bytes memory data = "";

        lendingPool.flashLoan(address(this), DAI_ADDRESS, _amount, data);
    }
    
    /* 
     * Called by lending pool to settle the loan operation
     */
    function executeOperation(
        address _reserve,
        uint256 _amount,
        uint256 _fee,
        bytes calldata _params
    )
        external
    {
        require(_amount <= getBalanceInternal(address(this), _reserve), "Invalid balance, was the flashLoan successful?");
        require(asset.transferFrom(msg.sender, address(this), _fee), "Could not pay for fees");

        swapDAIToUSDC();
        swapUSDCtoETH();
        swapETHToDAI();

        // Time to transfer the funds back
        uint totalDebt = _amount.add(_fee);
        transferFundsBackToPoolInternal(_reserve, totalDebt);
    }
    
    /* 
     * Calculate fee for the amount
     */
    function getFee(uint256 _amount) internal view returns (uint256) {
        (uint256 totalFeeBips,) = parametersProvider.getFlashLoanFeesInBips();
        uint256 amountFee = _amount.mul(totalFeeBips).div(10000);
        return amountFee;
    }
    
    function deadline() internal returns (uint256) {
        return block.number.add(uint256(20));
    }
    
    function swapDAIToUSDC() internal {
        uint256 daiBalance = getBalanceInternal(address(this), DAI_ADDRESS);
        
        ERC20 dai = ERC20(DAI_ADDRESS);
        
        // Mitigate ERC20 Approve front-running attack, by initially setting, allowance to 0
        require(dai.approve(address(uniswapDAIExchange), 0), "Could not approve Uniswap transfer");

        // Approve tokens so network can take them during the swap
        dai.approve(address(uniswapDAIExchange), daiBalance);
        
        uniswapDAIExchange.tokenToTokenSwapInput(
            daiBalance,
            1,
            1,
            deadline(),
            USDC_ADDRESS
        );
    }
    
    function swapUSDCtoETH() internal {
        uint256 usdcBalance = getBalanceInternal(address(this), USDC_ADDRESS);
        
        ERC20 usdc = ERC20(USDC_ADDRESS);
        ERC20 eth = ERC20(ETH_ADDRESS);
        
        (, uint256 minRate) = kyberNetworkProxy.getExpectedRate(usdc, eth, usdcBalance);

        // Mitigate ERC20 Approve front-running attack, by initially setting, allowance to 0
        require(usdc.approve(address(kyberNetworkProxy), 0), "Could not approve Kyber transfer");

        // Approve tokens so network can take them during the swap
        usdc.approve(address(kyberNetworkProxy), usdcBalance);

        kyberNetworkProxy.swapTokenToEther(
            usdc,
            usdcBalance,
            minRate
        );
    }

    function swapETHToDAI() internal {
        uint256 ethBalance = getBalanceInternal(address(this), ETH_ADDRESS);
        
        uniswapDAIExchange.ethToTokenSwapInput(
            ethBalance,
            deadline()
        );
    }

    /**
     */
    function getDAI() public payable {
        uniswapDAIExchange.ethToTokenTransferInput.value(msg.value)(
            1,
            deadline(),
            msg.sender
        );
    }
}