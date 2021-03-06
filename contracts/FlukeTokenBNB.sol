// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.5.7;

import "./FlukeToken.sol";

contract FlukeTokenBNB is FlukeToken{

    constructor() public FlukeToken("Fluke BNB", "FLKBNB"){
        _minPlayCoinsForBonus = 2*10**15; //0.002 BNB
    }
}
