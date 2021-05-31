// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.5.7;

import "./FlukeToken.sol";

contract FlukeTokenHPB is FlukeToken{

    constructor() public FlukeToken("Fluke HPB", "FLKHPB"){
        _minPlayCoinsForBonus = 10**18; //1 HPB
    }

    function getSecureRandomNumberSeed() internal view returns(bytes32){
        //return block.random;
        revert("block.random not enabled");
    }

}
