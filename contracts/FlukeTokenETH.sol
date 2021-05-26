// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.5.6;

import "./FlukeToken.sol";

contract FlukeTokenETH is FlukeToken{

    constructor() public FlukeToken("Fluke ETH", "FLKETH"){
        _minPlayCoinForBonus = 2*10**15; //0.00025 ETH
    }
}
