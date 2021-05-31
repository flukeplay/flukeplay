// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.5.7;

import "./FlukeToken.sol";

contract FlukeTokenIOTX is FlukeToken{

    constructor() public FlukeToken("Fluke IOTX", "FLKIOTX"){
        _minPlayCoinsForBonus = 10**18; //1 IOTX
    }
}
