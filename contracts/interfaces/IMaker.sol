pragma solidity ^0.5.16;


interface GemLike {
  function approve(address, uint256) external;

  function transfer(address, uint256) external;

  function transferFrom(
    address,
    address,
    uint256
  ) external;

  function deposit() external payable;

  function withdraw(uint256) external;
}


interface DaiJoinLike {
  function vat() external returns (VatLike);

  function dai() external returns (GemLike);

  function join(address, uint256) external payable;

  function exit(address, uint256) external;
}


interface VatLike {
  function can(address, address) external view returns (uint256);

  function ilks(bytes32)
    external
    view
    returns (
      uint256,
      uint256,
      uint256,
      uint256,
      uint256
    );

  function dai(address) external view returns (uint256);

  function urns(bytes32, address) external view returns (uint256, uint256);

  function frob(
    bytes32,
    address,
    address,
    address,
    int256,
    int256
  ) external;

  function hope(address) external;

  function move(
    address,
    address,
    uint256
  ) external;
}


interface GemJoinLike {
  function dec() external returns (uint256);

  function gem() external returns (GemLike);

  function join(address, uint256) external payable;

  function exit(address, uint256) external;
}


interface GemJoinETHLike {
  function dec() external returns (uint256);

  function gem() external returns (GemLike);

  function join(address) external payable;

  function exit(address, uint256) external;
}


interface OasisLike {
  function sellAllAmount(
    address pay_gem,
    uint256 pay_amt,
    address buy_gem,
    uint256 min_fill_amount
  ) external returns (uint256);
}


interface ManagerLike {
  function cdpCan(
    address,
    uint256,
    address
  ) external view returns (uint256);

  function ilks(uint256) external view returns (bytes32);

  function owns(uint256) external view returns (address);

  function urns(uint256) external view returns (address);

  function vat() external view returns (address);

  function open(bytes32, address) external returns (uint256);

  function give(uint256, address) external;

  function cdpAllow(
    uint256,
    address,
    uint256
  ) external;

  function urnAllow(address, uint256) external;

  function frob(
    uint256,
    int256,
    int256
  ) external;

  function flux(
    uint256,
    address,
    uint256
  ) external;

  function move(
    uint256,
    address,
    uint256
  ) external;

  function exit(
    address,
    uint256,
    address,
    uint256
  ) external;

  function quit(uint256, address) external;

  function enter(address, uint256) external;

  function shift(uint256, uint256) external;
}
