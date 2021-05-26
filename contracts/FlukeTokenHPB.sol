// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.5.6;

import "./FlukeToken.sol";

contract FlukeTokenHPB is FlukeToken{

    constructor() public FlukeToken("Fluke HPB", "FLKHPB"){
        _minPlayCoinForBonus = 10**18; //1 HPB
    }

    function getSecureRandomNumberSeed() internal view returns(bytes32){
        return block.random;
    }

}
