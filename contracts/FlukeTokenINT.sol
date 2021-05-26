// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.5.6;

import "./FlukeToken.sol";

contract FlukeTokenINT is FlukeToken{

    constructor() public FlukeToken("Fluke INT", "FLKINT"){
        _minPlayCoinForBonus = 10**18; //1 INT
    }
}
