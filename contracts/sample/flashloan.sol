pragma solidity ^0.5.0;

import "https://github.com/mrdavey/ez-flashloan/blob/remix/contracts/aave/FlashLoanReceiverBase.sol";
import "https://github.com/mrdavey/ez-flashloan/blob/remix/contracts/aave/ILendingPool.sol";
import "https://github.com/mrdavey/ez-flashloan/blob/remix/contracts/aave/ILendingPoolAddressesProvider.sol";


//DAI ADDRESS: 0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD
// PROVIDER ADDRESS: 0x506B0B2CF20FAA8f38a4E2B524EE43e1f4458Cc5
// 1000 dai = 1000000000000000000000 (Due to 18 decimal number)

contract MyfirstFlashLoan is FlashLoanReceiverBase(address(0x506B0B2CF20FAA8f38a4E2B524EE43e1f4458Cc5)) {
  function flashLoan(uint256 newamount, address _token) external {
    bytes memory _params = "0x0";
    address exchangeAddress = addressesProvider.getLendingPool();
    ILendingPool exchange = ILendingPool(exchangeAddress);

    exchange.flashLoan(address(this), _token, newamount, _params);
  }

  function executeOperation(
    address _reserve,
    uint256 _amount,
    uint256 _fee,
    bytes calldata _params
  ) external {
    // INSERT YOUR USE CASE HERE

    uint256 totalDebt = _amount.add(_fee);
    transferFundsBackToPoolInternal(_reserve, totalDebt);
  }
}
