pragma solidity ^0.5.16;

import "./makerinterface.sol";

// "MCD_VAT": "0xbA987bDB501d131f766fEe8180Da5d81b34b69d9"
// "MCD_JOIN_DAI": "0x5AA71a3ae1C0bd6ac27A1f28e1415fFFB6F15B8c"
// "MCD_DAI": "0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa"
// "CDP_MANAGER": "0x1476483dD8C35F25e568113C5f70249D3976ba21",
// "WETH": "0xd0A1E359811322d97991E03f863a0C30C2cF029C",
// "PIP_ETH": "0x75dD74e8afE8110C8320eD397CcCff3B8134d981",
// "MCD_JOIN_ETH_A": "0x775787933e92b709f2a3C70aa87999696e74A9F8",
// "MCD_FLIP_ETH_A": "0xB40139Ea36D35d0C9F6a2e62601B616F1FfbBD1b",
// "GET_CDPS": "0x592301a23d37c591C5856f28726AF820AF8e7014",
// "PROXY_ACTIONS": "0x82ecD135Dce65Fbc6DbdD0e4237E0AF93FFD5038",
//  ETH-A in  bytes32 0x4554482d41000000000000000000000000000000000000000000000000000000

contract mintingDAI {
    
    // function openCDP() external payable {
        
    // }
    address JoinETH = 0x775787933e92b709f2a3C70aa87999696e74A9F8;
    address JoinDAI = 0x5AA71a3ae1C0bd6ac27A1f28e1415fFFB6F15B8c;
    address daiAddress = 0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa;
    address mcdVAT = 0xbA987bDB501d131f766fEe8180Da5d81b34b69d9;
    address cdpManager = 0x1476483dD8C35F25e568113C5f70249D3976ba21;
    bytes32 ethA = 0x4554482d41000000000000000000000000000000000000000000000000000000;
    
    IErc20 wETH = IErc20(0xd0A1E359811322d97991E03f863a0C30C2cF029C);
    IErc20 DAI = IErc20(0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa);
    GemJoinLike ethJoin = GemJoinLike(JoinETH);
    GemJoinLike daiJoin = GemJoinLike(JoinDAI);
    VatLike Vat = VatLike(mcdVAT);
    ManagerLike cdpmanager = ManagerLike(cdpManager);
    
    function bytes32ToStr(bytes32 _bytes32) public pure returns (string memory) {

    // string memory str = string(_bytes32);
    // TypeError: Explicit type conversion not allowed from "bytes32" to "string storage pointer"
    // thus we should fist convert bytes32 to bytes (to dynamically-sized byte array)

    bytes memory bytesArray = new bytes(32);
    for (uint256 i; i < 32; i++) {
        bytesArray[i] = _bytes32[i];
        }
    return string(bytesArray);
    }
    
    function payToContract() external payable returns(string memory){
      return "done";
    }
    
    function mintWETHandTransferBack() external payable returns(string memory) {
        //Convert ETH to WETH
        wETH.deposit.value(msg.value)();
        
        //Approve EthJoin to spend wETH
        wETH.approve(JoinETH, 10 ether);
        
        //Open the vault using the open function.
        // bytes32("ETH-A")
        // uint cdpID = cdpmanager.open(ethA, address(this));
        // address urnAddress = cdpmanager.urns(cdpID);
        
        // Allocate the WETH to the vault using join
        ethJoin.join(address(this), msg.value);
        
        // Lock the WETH into the vault using the frob function.
        // Vaults are managed via frob(i, u, v, w, dink, dart), 
        // which modifies the Vault of user u,
        // using gem from user v and creating dai for user w.
        //Draw Dai from the vault using the frob function.
        Vat.frob(ethA, address(this), address(this), address(this), 1e18, 20e18);
        
        //move the Dai out of the vault.
        // Vat.move(urnAddress, address(this), 2e18);
         
        //approve the DaiJoin contract to access the user's Dai balance
        Vat.hope(JoinDAI);
        
        //Mint ERC20 Dai using the exit function, which in turns call the mint function of the ERC20 Dai contract.
        daiJoin.exit(address(this), 2e18);
        
        DAI.transfer(msg.sender, 2e18);
        
        return "ok";
    }
}