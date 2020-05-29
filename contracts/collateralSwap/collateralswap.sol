pragma solidity ^0.5.16;

import "../interfaces/IMaker.sol";
import "../interfaces/IERC20.sol";
import "../constants/ConstantAddresses.sol";


//  ETH-A in  bytes32 0x4554482d41000000000000000000000000000000000000000000000000000000
//  BAT-A in bytes32 0x4241542d41000000000000000000000000000000000000000000000000000000

contract Collateralswap is ConstantAddresses {
  bytes32 ethA = 0x4554482d41000000000000000000000000000000000000000000000000000000;
  bytes32 batA = 0x4241542d41000000000000000000000000000000000000000000000000000000;

  IERC20 wETH = IERC20(WETH_ADDRESS);
  IERC20 DAI = IERC20(DAI_ADDRESS);
  GemJoinLike ethJoin = GemJoinLike(ETH_JOIN_ADDRESS);
  GemJoinLike daiJoin = GemJoinLike(DAI_JOIN_ADDRESS);
  VatLike Vat = VatLike(VAT_ADDRESS);
  ManagerLike cdpmanager = ManagerLike(MANAGER_ADDRESS);
  OasisLike Oasis = OasisLike(OASIS_MATCHING_MARKET);

  function payToContract() external payable returns (string memory) {
    return "done";
  }

  function getETHBalance() external view returns (uint256 balance) {
    balance = address(this).balance;
  }

  function getWETHBalance() external view returns (uint256 balance) {
    balance = wETH.balanceOf(address(this));
  }

  function getDAIBalance() external view returns (uint256 balance) {
    balance = DAI.balanceOf(address(this));
  }

  function amountOfLockedCollateral(address _owner, bytes32 _ilk) public view returns (uint256 ink, uint256 art) {
    return Vat.urns(_ilk, _owner);
  }

  function getDAIVatBalance() external view returns (uint256 balance) {
    return Vat.dai(address(this));
  }

  function MintWETH() public payable {
    //Convert ETH to WETH
    wETH.deposit.value(msg.value)();
  }

  function tradeOasis(
    address inputToken,
    uint256 inputAmount,
    address outputToken
  ) public returns (uint256) {
    // Need to check if inputToken is WETH? maybe not
    IERC20 erc20 = IERC20(inputToken);
    erc20.approve(OASIS_MATCHING_MARKET, 10000 ether);
    //Market order to sell the WETH for DAI
    uint256 outputAmount = Oasis.sellAllAmount(inputToken, inputAmount, outputToken, uint256(0));
    return outputAmount;
  }

  function getTotalDebt(bytes32 ilk) public view returns (int256 dart) {
    // Gets actual rate from the vat
    (, uint256 rate, , , ) = Vat.ilks(ilk);
    // Gets actual art value of the urn
    (, uint256 art) = Vat.urns(ilk, address(this));
    uint256 dai = Vat.dai(address(this));
    // Uses the whole dai balance in the vat to reduce the debt
    dart = int256(dai / rate);
    // Checks the calculated dart is not higher than urn.art (total debt), otherwise uses its value
    dart = uint256(dart) <= art ? -dart : -int256(art);
  }

  function freeCollateral() public returns (uint256) {
    int256 dart = getTotalDebt(ethA);
    Vat.frob(ethA, address(this), address(this), address(this), int256(0), dart);
    return address(this).balance;
  }

  function openVaultLockCollateralAndMint(int256 daiAmountToMint, uint256 daiAmountToWithdraw)
    external
    payable
    returns (string memory)
  {
    //Convert ETH to WETH
    wETH.deposit.value(msg.value)();

    //Approve EthJoin to spend wETH
    wETH.approve(ETH_JOIN_ADDRESS, 1000 ether);

    //Open the vault using the open function.
    // bytes32("ETH-A")
    // uint cdpID = cdpmanager.open(ethA, address(this));
    // address urnAddress = cdpmanager.urns(cdpID);

    // // Allocate the WETH to the vault using join
    ethJoin.join(address(this), msg.value);

    // // Lock the WETH into the vault using the frob function.
    // // Vaults are managed via frob(i, u, v, w, dink, dart),
    // // which modifies the Vault of user u,
    // // using gem from user v and creating dai for user w.
    // //Draw Dai from the vault using the frob function.

    Vat.frob(ethA, address(this), address(this), address(this), int256(msg.value), daiAmountToMint);

    // //move the Dai out of the vault.
    // Vat.move(urnAddress, address(this), 2e18);

    // //approve the DaiJoin contract to access the user's Dai balance
    Vat.hope(DAI_JOIN_ADDRESS);

    // //Mint ERC20 Dai using the exit function, which in turns call the mint function of the ERC20 Dai contract.
    daiJoin.exit(address(this), daiAmountToWithdraw);

    // DAI.transfer(msg.sender, 2e18);

    return "ok";
  }
}
