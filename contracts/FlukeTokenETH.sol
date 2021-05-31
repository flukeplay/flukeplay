// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.5.7;

import "./FlukeToken.sol";

contract FlukeTokenETH is FlukeToken{

    constructor() public FlukeToken("Fluke ETH", "FLKETH"){
        _minPlayCoinsForBonus = 2*10**15; //0.00025 ETH
    }
}
