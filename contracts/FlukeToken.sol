// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.5.7;

import "./ERC20Token.sol";

interface IFlukeToken{
    /*
     * @dev Emitted when a "play" move is executed
     */
    event Played(address indexed player, uint256 playedTokens, uint256 playedCoins, uint256 playedValue, uint64 index, uint256 randomSeed, uint232 ticketNumber, uint256 indexed prizeMultiplier, uint256 targetPrize, uint256 awardedCoins, uint256 awardedTokens);
    /*
     * @dev Emitted when a "breed" move is executed
     */
    event Bred(address indexed player, uint256 playedValue, uint32 factor, uint64 index, uint256 randomSeed, uint32 ticketNumber, uint256 bredTokens);
    /*
     * @dev Emitted when a player exchanges FLK for coins
     */
    event Withdrew(address indexed player, uint tokensAmount, uint256 coinsAmount);
    /*
     * @dev Emitted when a game settings have been modified
     */
    event SettingsChanged(
                address actor,
                uint256 minimumPlayCoinsForBonus,
                uint256 depositTreasuryContributionPerCoin, 
                uint256 withdrawlFeePerFlk,
                
                uint32 delayModeBlocksCount,
                uint8 delayModeSweepCount);

    /*
     * @dev Retrieve total submissions so far
     */
    function getSubmissionsCount() external view returns(uint64);
    /*
     * @dev Retrieve the minimumu amount of coins to play to qualify for full bonus.
     */
    function getMinPlayCoinsForBonus() external view returns(uint256);
    function setMinPlayCoinsForBonus(uint256 minPlayCoinsForBonus) external;
    /*
     * @dev Amount of coins in wei to be transfered from reward pool to treasury pool for each coin played.
     */
    function getDepositTreasuryContributionPerCoin() external view returns(uint256);
    function setDepositTreasuryContributionPerCoin(uint256 value) external;
    /*
     * @dev Amountof tokens in FLK tokens to be deducted as fees when 1 FLK token is exchanged for coins
     */
    function getWithdrawalFeePerToken() external view returns(uint256);
    function setWithdrawlFeePerFlk(uint256 value) external;

    /*
     * @dev Amount of coins in the reward pool
     */
    function getRewardPoolBalance() external view returns(uint256);   
    
    /*
     * @dev Amount of coins in the treasury pool
     */
    function getTreasuryPoolBalance() external view returns(uint256);

    /*
     * @dev Nominal value of 1 FLK token which is equal to the treasury pool divided by total supply of FLK.
     */
    function getTokenNominalValue() external view returns(uint256);
    /*
     * @dev Receives coins and execute a "play" move
     */
    function play() external payable;
    /*
     * @dev Value of a token when excuting a "play" move with by submitting tokens
     */
    function flunTokenValue() external view returns(uint256);
    /*
     * @dev Receives tokens and execute a "play" move
     */
    function flun(uint256 playedTokens) external;
    /*
     * @dev Execute a breed move
     */
    function breed(uint256 playedTokens, uint32 factor) external;

    /*
     * @dev Retrieves number of blocks by which an execution of a move must be delay
     */
    function getDecisionDelayBlocksCount() external view returns(uint32 value);
    function setDecisionDelayBlocksCount(uint32 value) external;
    /*
     * @dev Retrieves number of previous moves that are executed when a new move is submitted
     */
    function getPreviousSubmissionsSweepCount() external view returns(uint8 value);
    function setPreviousSubmissionsSweepCount(uint8 value) external;
    
    /*
     * @dev Number of moves in the queue to be executed in future blocks
     */
    function getQueueSize() external view returns(uint64);

    /*
     * @dev Exchanges the provided FLK tokens for coins from treasury pool
     */
    function withdraw(uint256 tokensAmount) external;

    function pause() external;
    function unpause() external;
    /*
     * @dev Terminate the game. 
     
      - Moves reward pool coins to the treasury pool 
      - Sets withdrawal fees to 0
      - Pauses the game

      After liquidation, 
      - all available coins are allocated to FLK holders in proportional to their holdings.
      - FLK holders can then exchange their FLK for their coins allocation.
      - The game is permanently paused and moves will no longer be accepted
     */
    function liquidate() external;
    /*
     * @dev Permanently destroy the game. Requires that there are no issued FLK tokens
     */
    function destroy() external;
    function getGameSettings() external view returns(
        uint256 depositTreasuryContributionPerCoin,
        uint256 withdrawalFeePerToken,
    
        uint32 decisionDelayBlocksCount, uint8 previousSubmissionsSweepCount
    );
    function getTokenValuationInfo() external view returns(
        uint256 rewardPoolBalance,
        uint256 treasuryPoolBalance,
        uint256 tokenNominalValue,
        uint256 totalSupply,
        uint256 totalBurnt,
        uint256 flunningTokenValue
    );
    function getGameState() external view returns(
        uint64 playSubmissionsCount, uint64 playWinsCount, uint256 playStatsDetails,
        
        uint256 flunningTokenValue,

        uint64 breedSubmissionsCount, 
        uint64 breedWinsCount, 
        uint256 breedTokensSubmitted, 
        uint256 bredTokens

        );
}

/*
 * @dev Allows anyone to donate coins to the reward pool without playing
 */
contract FlukeTokenDonatable {
    using SafeMath for uint256;
    using SafeMath for uint32;
    
    event Donated(address indexed player, uint256 value);
    
    struct DonationsInfo{
        uint256 donationsAmount;
        uint32 donationsCount;
    }

    mapping (address => DonationsInfo) private _donors;
    DonationsInfo _donations;

    function _donate(address donor, uint256 amount) internal{
        _donors[donor].donationsAmount = _donors[donor].donationsAmount.add(amount);
        _donors[donor].donationsCount = _donors[donor].donationsCount + 1;

        _donations.donationsAmount = _donations.donationsAmount.add(amount);
        _donations.donationsCount = _donations.donationsCount + 1;

        emit Donated(donor, amount);
    }

    function donate() public payable{
        _donate(msg.sender, msg.value);
    }
    
    function donationsOf(address donor) public view returns(uint256 donationsAmount, uint32 donationsCount){
        return (_donors[donor].donationsAmount, _donors[donor].donationsCount);
    }
    
    function donations() public view returns(uint256 donationsAmount, uint32 donationsCount){
        return (_donations.donationsAmount, _donations.donationsCount);
    }

}

/*
 * @dev Maintenance of game statistics for players and total
 */
contract FlukeTokenStatistic{

    struct Statistics{
        uint64 playSubmissions;
        uint64 playWins;
        uint256 playDetails;

        uint64 breedSubmissions;
        uint64 breedWins;
        uint256 breedTokensSubmitted;
        uint256 bredTokens;
    }
    
    mapping(address => Statistics) internal _stats;
    Statistics internal _totalStats;

    function adapt(Statistics storage stats) internal view returns(
        uint64 playSubmissions,
        uint64 playWins,
        uint256 playDetails,

        uint64 breedSubmissions,
        uint64 breedWins,
        uint256 breedTokensSubmitted,
        uint256 bredTokens){
        return (
            stats.playSubmissions,
            stats.playWins,
            stats.playDetails,
            stats.breedSubmissions,
            stats.breedWins,
            stats.breedTokensSubmitted,
            stats.bredTokens);
    }

    function stats() public view returns(
        uint64 playSubmissions,
        uint64 playWins,
        uint256 playDetails,

        uint64 breedSubmissions,
        uint64 breedWins,
        uint256 breedTokensSubmitted,
        uint256 bredTokens){
        return adapt(_totalStats);
    }
 
    function statsOf(address player) public view returns(
        uint64 playSubmissions,
        uint64 playWins,
        uint256 playDetails,

        uint64 breedSubmissions,
        uint64 breedWins,
        uint256 breedTokensSubmitted,
        uint256 bredTokens){
        return adapt(_stats[player]);
    }

    function winUnit(uint32 multiplier) internal pure returns(uint256){
        if(multiplier==0){
            return 1;
        }else if(multiplier==3){
            return 1<<32;
        }else if(multiplier==10){
            return 1<<64;
        }else if(multiplier==100){
            return 1<<96;
        }else if(multiplier==500){
            return 1<<128;
        }else if(multiplier==1000){
            return 1<<160;
        }else if(multiplier==50_000){
            return 1<<192;
        }else if(multiplier==1_000_000){
            return 1<<224;
        }
    }
    
    function incrementStats(address player, uint32 multiplier) internal{
        _totalStats.playSubmissions += 1;
        _stats[player].playSubmissions += 1;
        if(multiplier>0){
            _totalStats.playWins += 1;
            _stats[player].playWins += 1;
        }
        uint256 i = winUnit(multiplier);
        _totalStats.playDetails += i;
        _stats[player].playDetails += i;
    }
    
    function incrementBreedStats(address player, uint256 submittedFlk, uint256 awardedFlk) internal {
        _totalStats.breedSubmissions += 1;
        _totalStats.breedTokensSubmitted += submittedFlk;
        _stats[player].breedSubmissions += 1;
        _stats[player].breedTokensSubmitted += submittedFlk;

        if(awardedFlk>0){
            _totalStats.breedWins += 1;
            _totalStats.bredTokens += awardedFlk;
            _stats[player].breedWins += 1;
            _stats[player].bredTokens += awardedFlk;
        }
    }

}

/*
 * @dev Provides functions for generation of tickets for players and determining rewards
 *
 */
contract FlukeTickets is FlukeTokenStatistic{
    
    /**
     * To be overriden by FlukeToken implementation to provide random bytes32 from secure sources.
     * */
    function getSecureRandomNumberSeed() internal view returns(bytes32){
        bytes32 seed = keccak256(abi.encodePacked(
        block.timestamp + block.difficulty +
        ((uint256(keccak256(abi.encodePacked(block.coinbase)))) / (now)) +
        block.gaslimit + 
        ((uint256(keccak256(abi.encodePacked(msg.sender)))) / (now)) +
        block.number
        ));
        return seed;
    }
    
    function generateTiketNumber(uint64 offset) internal view returns(uint32){
        uint256 seed = uint256(getSecureRandomNumberSeed());
        return generateTiketNumber(seed, offset);
    }

    function getTicketRewardMultiplier(uint32 ticketNumber) public pure returns(uint32) {
        /*
        if(ticketNumber==0){//1 of 10M
            return 1000000;
        }else if(ticketNumber < 11){ //1 of 1M
            return 50000;
        }else if(ticketNumber < 111){//1 of 100,000
            return 1000;
        }else if(ticketNumber < 1111){//1 of 10,0000
            return 500;
        }else if(ticketNumber < 11111){//1 of 1000
            return 100;
        }else if(ticketNumber < 111111){//1 of 100
            return 10;
        }else if(ticketNumber < 1111111){//1 of 10
            return 3;
        }else if(ticketNumber <= 2000000){//1 of 11
            return 3;
        }
        */
        if(ticketNumber <= 429){//1 of 10M
            return 1000000;
        }else if(ticketNumber <= 4_724){ //1 of 1M
            return 50000;
        }else if(ticketNumber <= 47_674){//1 of 100,000
            return 1000;
        }else if(ticketNumber <= 477_171){//1 of 10,0000
            return 500;
        }else if(ticketNumber <= 4_772_138){//1 of 1000
            return 100;
        }else if(ticketNumber <= 47_721_811){//1 of 100
            return 10;
        }else if(ticketNumber <= 477_218_541){//1 of 10
            return 3;
        }else if(ticketNumber <= 858_993_459){//1 of 11
            return 3;
        }
        
        return 0;
    }
    
    /*
    //xorshift
    function generateTiketNumber(uint256 seed, uint64 tweak) public pure returns(uint32){
        //use the tweek to spread requests among the 8 32bit blocks of the seed
        uint8 bit32BlockIndex = uint8(tweak % 8);
        uint32 state = uint32(seed >> bit32BlockIndex);
        uint8 rounds = uint8((tweak / 8) % 256);
        //apply xorshift to the items within a block
        for(uint8 i=0; i<rounds; i++){
            uint32 x = state;
            x ^= x << 13;
            x ^= x >> 17;
            x ^= x << 5;
            state = x;
        }
        return state;
    }
    */
    
    //https://crypto.stackexchange.com/questions/48145/xor-a-set-of-random-numbers
    function generateTiketNumber(uint256 seed, uint64 submissionIndex) public pure returns(uint32){
        //the result is an xor of some combination of the 32-bit sections of the seed
        //we have 255 combinations for the 8 sections
        //use the submissionIndex to determine the combination to use,
        uint8 combination = uint8(submissionIndex % 255)+1; //between 1 and 255 inclusive
        //now each bit in combination determines if we used the corresponding 32-bit block of the seed in xor'd result
        uint32 result = 0;
        for(uint8 i=0; i<8; i++){
            if((combination & (uint8(1) << i)) > 0){
                result ^= uint32(seed >> (i * 32)); 
            }
        }
        return result;
    }

}

library FlukeFIFOQueue {
    uint64 constant END = 2**64-1;
    
    struct Queue{
        uint64 _tail;
        uint64 _head;
        uint64 _size;
        mapping(uint64=>uint64) next;
    }

    //function newQueue() public returns(Queue memory){
    //    Queue memory result = Queue({tail: END, head: END});
    //    return result;
    //}
    function reset(Queue storage self) internal{
        self._tail = END;
        self._head = END;
    }
    function add(Queue storage self, uint64 id) internal{
        if(isEmpty(self)){
            self._tail = id;
            self._head = id;
        }else{
            self.next[self._head] = id;
            self._head = id;
        }
        self.next[id] = END;
        self._size++;
    }
    function end() internal pure returns(uint64){
        return END;
    }
    function size(Queue storage self) internal view returns(uint64){
        return self._size;
    }
    function head(Queue storage self) internal view returns(uint64){
        return self._head;
    }
    function tail(Queue storage self) internal view returns(uint64){
        return self._tail;
    }
    function peek(Queue storage self) internal view returns(uint64){
        return self._tail;
    }
    function peek(Queue storage self, uint64 depth) internal view returns(uint64){
        if(isEmpty(self)) return END;
        uint64 value = self._tail;
        for(uint8 i=0; i<depth; i++){
            value = self.next[value];
            if(value==END) return END;
        }
        return value;
    }

    function get(Queue storage self) internal returns(uint64) {
        if(isEmpty(self)) return END;
        uint64 result = self._tail;
        self._tail = self.next[result];
        if(self._tail==END){
            self._head = END;
        }
        self._size--;
        return result;
    }
    function isEmpty(Queue storage self) internal view returns(bool){
        return self._tail == END;
    }
}

/*
 * @dev Allows moves executions to be delayed for a number of blocks to prevent miners front-running.
 *
 * When {decisionDelayBlocksCount} is > 0 :
 *
 * - submitted moves will be put into a queue waiting to be executed in future blocks
 * - when a move is submitted, some moves submitted in earlier blocks are executed
 *
 */
contract FlukeDelayable is Ownable {
    using FlukeFIFOQueue for FlukeFIFOQueue.Queue;

    uint64 internal END = FlukeFIFOQueue.end();

    struct PlaySubmission{
        uint256 blockNumber;
        address payable player;
        uint256 playedTokens;
        uint256 playedCoins;
        uint256 playedValue;
        uint64 index;
    }

    struct BreedSubmission{
        uint256 blockNumber;
        address payable player;
        uint256 playedValue;
        uint32 factor;
        uint64 index;
    }

    mapping(uint64 => PlaySubmission) internal _plays;
    FlukeFIFOQueue.Queue internal _playQueue;
    mapping(uint64 => BreedSubmission) internal _breeds;
    FlukeFIFOQueue.Queue internal _breedQueue;
    uint32 internal _decisionDelayBlocksCount; //number of blocks to skip before processing entries
    uint8 internal _previousSubmissionsSweepCount;

    constructor() public {
        _playQueue.reset();
        _breedQueue.reset();
        _previousSubmissionsSweepCount = 2;
    }
    function getDecisionDelayBlocksCount() public view returns(uint32){
        return _decisionDelayBlocksCount;
    }
    function setDecisionDelayBlocksCount(uint32 value) public onlyOwner{
        _decisionDelayBlocksCount = value;
    }
    function getPreviousSubmissionsSweepCount() public view returns(uint8){
        return _previousSubmissionsSweepCount;
    }
    function setPreviousSubmissionsSweepCount(uint8 value) public onlyOwner{
        require(value>=2 && value<=10);
        _previousSubmissionsSweepCount = value;
    }
    
    function processPlaySubmission(PlaySubmission storage submission) internal{
        submission.index = 0;
        revert("processPlaySubmission must be implemented by subcontract");
    }
    function processBreedSubmission(BreedSubmission storage submission) internal{
        submission.index = 0;
        revert("processBreedSubmission must be implemented by subcontract");
    }

    function queuePlaySubmission(
        uint256 blockNumber,
        address payable player,
        uint256 playedTokens,
        uint256 playedCoins,
        uint256 playedValue,
        uint64 index) internal {
        _plays[index] = PlaySubmission({
                blockNumber: blockNumber,
                player : player,
                playedTokens : playedTokens,
                playedCoins : playedCoins,
                playedValue : playedValue,
                index : index
            });
        _playQueue.add(index);
    }

    function processQueuedPlaySubmissions(uint256 maxBlockNumber, uint8 maxSubmissions) internal returns(uint8){
        return processQueuedSubmissions(maxBlockNumber, maxSubmissions);
    }

    function queueBreedSubmission(
        uint256 blockNumber,
        address payable player,
        uint256 playedValue,
        uint32 factor,
        uint64 index) internal {
        _breeds[index] = BreedSubmission({
            blockNumber: blockNumber,
            player: player,
            playedValue: playedValue,
            factor: factor,
            index: index
            });
        _breedQueue.add(index);
    }

    function processQueuedBreedSubmissions(uint256 maxBlockNumber, uint8 maxSubmissions) internal returns(uint8){
        return processQueuedSubmissions(maxBlockNumber, maxSubmissions);
    }

    function processQueuedSubmissions(uint256 maxBlockNumber, uint8 maxSubmissions) internal returns(uint8){
        uint8 processedCount = 0;
        while(processedCount < maxSubmissions){
            uint64 breedTop = _breedQueue.peek();
            if(_breeds[breedTop].blockNumber > maxBlockNumber){
                breedTop = FlukeFIFOQueue.end();
            }
            uint64 playTop = _playQueue.peek();
            if(_plays[playTop].blockNumber > maxBlockNumber){
                playTop = FlukeFIFOQueue.end();
            }
            if(breedTop==FlukeFIFOQueue.end()){
                if(playTop==FlukeFIFOQueue.end()){
                    return processedCount;
                }
                //breedQueue is empty, process playQueue
                processPlaySubmission(_plays[_playQueue.get()]);
            }else if(playTop==FlukeFIFOQueue.end()){
                //playQueue is empty, process breeQueue
                processBreedSubmission(_breeds[_breedQueue.get()]);
            }else{
                //process etiher breed or play depending on which came first
                if(_breeds[breedTop].blockNumber <= _plays[playTop].blockNumber){
                    //process play
                    processPlaySubmission(_plays[_playQueue.get()]);
                }else{
                    //process breed
                    processBreedSubmission(_breeds[_breedQueue.get()]);
                }
            }
            processedCount++;
        }
        return processedCount;
    }
    function sweepQueuedSubmissions(uint8 maxSubmissions) public {
        processQueuedSubmissions(block.number-_decisionDelayBlocksCount, maxSubmissions);
    }

    function sweepQueuedSubmissions() public {
        processQueuedSubmissions(block.number-_decisionDelayBlocksCount, _previousSubmissionsSweepCount);
    }

    function getQueueSize() public view returns(uint64){
        return _playQueue.size() + _breedQueue.size();
    }
    function playQueueSize() public view returns(uint64){
        return _playQueue.size();
    }
    function breedQueueSize() public view returns(uint64){
        return _breedQueue.size();
    }

}

contract FlukeToken is IFlukeToken, Ownable, FlukeTickets, FlukeTokenDonatable, ERC20Token, FlukeDelayable {
    //****************LIBRARY DECLARATIONS************************/
    using SafeMath for uint256;

    //*****************GLOBAL VARIABLES***************************/
    uint256 internal constant FLK_UNIT = 10**18;//1000000000000000000;
    uint256 private constant MINIMUM_DEPOSIT_TREASURY_CONSTRIBUTION_PER_COIN = 10**16;//1%
    uint256 private constant MAXIMUM_DEPOSIT_TREASURY_CONSTRIBUTION_PER_COIN = 5*10**17;//50%
    uint256 private constant MINIMUM_GOVERNANCE_FEE_PER_FLK = 0; //0
    uint256 private constant MAXIMUM_GOVERNANCE_FEE_PER_FLK = 10**17; //10%
    uint256 private constant MINIMUM_WITHDRAWAL_FEE_PER_FLK = 5*10**16;//5%
    uint256 private constant MAXIMUM_WITHDRAWAL_FEE_PER_FLK = 2*10**17;//20%

    uint64 internal _submissionIndex;
    uint256 internal _minPlayCoinsForBonus;
    uint256 internal _depositTreasuryContributionPerCoin;
    uint256 internal _withdrawalFeePerToken;
    uint256 internal _treasuryPoolBalance;
    uint256 internal _breedBurntFlk;
    uint64 internal _breedWins;
    uint256 internal _totalWithdrawnTokens;
    uint256 internal _totalWithdrawnCoins;
    bool internal _liquidated;

    constructor(string memory name, string memory symbol) public ERC20Token(name, symbol, uint256(0)) {
        _depositTreasuryContributionPerCoin = 10**17; //10%
        _withdrawalFeePerToken = 10**17; //10%
        _submissionIndex = 0;
        _minPlayCoinsForBonus = FLK_UNIT;
    }

    function getSubmissionsCount() public view returns(uint64){
        return _submissionIndex;
    }

    function emitSettingsChanged() internal{        
        emit SettingsChanged(_msgSender(), 
                    _minPlayCoinsForBonus,
                    _depositTreasuryContributionPerCoin, 
                    _withdrawalFeePerToken,

                    _decisionDelayBlocksCount,
                    _previousSubmissionsSweepCount
                    );
    }

    function getMinPlayCoinsForBonus() public view returns(uint256){
        return _minPlayCoinsForBonus;
    }
    function setMinPlayCoinsForBonus(uint256 minPlayCoinsForBonus) public onlyOwner{
        _minPlayCoinsForBonus = minPlayCoinsForBonus;

        emitSettingsChanged();
    }
    function getDepositTreasuryContributionPerCoin() public view returns(uint256){
        return _depositTreasuryContributionPerCoin;
    }
    
    function setDepositTreasuryContributionPerCoin(uint256 value) public onlyOwner{
        require(value>=MINIMUM_DEPOSIT_TREASURY_CONSTRIBUTION_PER_COIN && value<=MAXIMUM_DEPOSIT_TREASURY_CONSTRIBUTION_PER_COIN, 
            "Invalid treasury contribution pc, must be >=1% and <=50% ");
        _depositTreasuryContributionPerCoin = value;
        
        emitSettingsChanged();
    }

    function getWithdrawalFeePerToken() public view returns(uint256){

    }

    function setWithdrawlFeePerFlk(uint256 value) public onlyOwner{
        require(value>=MINIMUM_WITHDRAWAL_FEE_PER_FLK && value<=MAXIMUM_WITHDRAWAL_FEE_PER_FLK, 
            "Invalid withdrawlFeePc, must be >=5 and <=20 ");
        _withdrawalFeePerToken = value;

        emitSettingsChanged();
    }
    
    function getRewardPoolBalance() public view returns(uint256) {
        return address(this).balance - _treasuryPoolBalance;
    }
    
    function getTreasuryPoolBalance() public view returns(uint256) {
        return _treasuryPoolBalance;
    }
            
    function getTokenNominalValue() public view returns(uint256){
        if(totalSupply()==0) return 0;
        return getTreasuryPoolBalance().mul(FLK_UNIT).div(totalSupply());
    }
    
    function getSubmissionBonusTokens(uint64 submissionsIndex) internal pure returns(uint256){
        uint submissionsPerRound = 2000;
        uint bonusRoundIndex = submissionsIndex / submissionsPerRound;
        uint256 generocity = (2**10*FLK_UNIT) >> bonusRoundIndex;
        return generocity;
    }
        
    function calculateAward(uint256 prizeTarget) internal view returns(uint256 awardedCoins, uint256 awardedTokens){
        //amount, flks,
        uint256 prize = getRewardPoolBalance().mul(90).div(100);
        if(prizeTarget<=prize){
            prize = prizeTarget;
        }
        uint256 prizeTokens  = prize.mul(totalSupply()).div(_treasuryPoolBalance);
        
        return (prize, prizeTokens);
    }

    function awardPlayer(address player, uint256 prizeTarget, uint32 prizeMultiplier) internal returns(uint32 multiplier, uint256 targetPrize, uint256 awardedCoins, uint256 awardedTokens) {
        (uint256 prize, uint256 prizeTokens) = calculateAward(prizeTarget);
        
        //move funds from reward pool to treasury pool
        _treasuryPoolBalance = _treasuryPoolBalance.add(prize);

        //issue equivalent amount of FLK token
        super._mint(player, prizeTokens);

        return (prizeMultiplier, prizeTarget, prize, prizeTokens);
    }
        
    /**
        Ensure 1 FLK is given when value of 1 FLK <= treasury contribution
        Ensure FLK equivalent of treasury contribution is given when value of 1 FLK > treasury contribution
     */
    function tokenRewardsPerPlayedCoin() internal view returns(uint256) {
        uint256 tokenValue = getTokenNominalValue();
        if(tokenValue==0) return FLK_UNIT;
        uint256 depositContributionValueInFlk = _depositTreasuryContributionPerCoin
            .mul(FLK_UNIT)
            .div(tokenValue);

        if(depositContributionValueInFlk >= FLK_UNIT){
            return FLK_UNIT;
        }else{
            return depositContributionValueInFlk; 
        }
    }

    function getFullBonusThreshold() internal view returns(uint256){
        uint256 fullBonusThreshold;
        if(_submissionIndex==0 || address(this).balance==0){
            fullBonusThreshold = _minPlayCoinsForBonus;
        }else{
            uint256 averageSubmittedAmount = address(this).balance.div(_submissionIndex+1);
            fullBonusThreshold = averageSubmittedAmount.add(_minPlayCoinsForBonus).div(2);
        }
        return fullBonusThreshold;
    }

    function receivePlayCoins(address payable sender, uint256 playedCoins) internal {
        uint256 bonus = getSubmissionBonusTokens(_submissionIndex);
        uint256 fullBonusThreshold = getFullBonusThreshold();
        if(playedCoins <fullBonusThreshold){
            bonus = bonus.mul(playedCoins).div(fullBonusThreshold);
        }
        
        //1. issue FLKs to sender and contract (1 FLK for each coin + bonus)
        uint256 submissionTokens = playedCoins.mul(tokenRewardsPerPlayedCoin()).div(FLK_UNIT)
                .add(bonus);
        
        super._mint(sender, submissionTokens);

        //2. Send a portion of the received amount to treasury, reward FLK holders
        uint256 submissionTreasuryContribution = playedCoins.mul(_depositTreasuryContributionPerCoin).div(FLK_UNIT);
        _treasuryPoolBalance += submissionTreasuryContribution;
    }

    function processPlay(address payable sender, uint256 playedTokens, uint256 playedCoins, uint256 playedValue, uint64 index, uint32 ticketNumber) internal returns(uint32 prizeMultiplier, uint256 targetPrize, uint256 awardedCoins, uint256 awardedTokens) {
        //1. Determine reward multiplier
        uint32 rewardMultiplier = getTicketRewardMultiplier(ticketNumber);
        
        //2. Give reward if any
        
        if(rewardMultiplier>0){
            //give user FLK tokens equivailent to rewardMultiplier X the coins they sent
            
            (prizeMultiplier, targetPrize, awardedCoins, awardedTokens) = 
                awardPlayer(sender, playedValue * rewardMultiplier, rewardMultiplier);
            
            emit Played(sender, playedTokens, playedCoins, playedValue, index, uint256(getSecureRandomNumberSeed()), 
                            ticketNumber, rewardMultiplier, targetPrize, awardedCoins, awardedTokens);
            
            incrementStats(sender, rewardMultiplier);

            return (prizeMultiplier, targetPrize, awardedCoins, awardedTokens);
        }else{
            //user gets no award
            emit Played(sender, playedTokens, playedCoins, playedValue, index, uint256(getSecureRandomNumberSeed()), 
                            ticketNumber, 0, 0, 0, 0);
                            
            incrementStats(sender, rewardMultiplier);
            
            return (0, 0, 0, 0);
        }
    }

    function processPlaySubmission(PlaySubmission storage submission) internal{
        uint256 seed = uint256(getSecureRandomNumberSeed());

        uint32 ticketNumber = generateTiketNumber(seed, submission.index);

        processPlay(submission.player, submission.playedTokens, submission.playedCoins, submission.playedValue, submission.index, ticketNumber);
    }

    function _requestPlay(address payable sender, uint256 playedCoins) internal
        /*returns(uint32 prizeMultiplier, uint256 targetPrize, uint256 awardedCoins, uint256 awardedTokens)*/ {
        //require(playedCoins>0, "Invalid amount");
        if(playedCoins==0){
            sweepQueuedSubmissions();
            return;
        }

        //1. handle new submission coins
        receivePlayCoins(sender, playedCoins);
        
        //2. play
        if(_decisionDelayBlocksCount==0){
            uint32 ticketNumber = generateTiketNumber(_submissionIndex);

            processPlay(sender, 0, playedCoins, playedCoins, _submissionIndex, ticketNumber);
        }else{
            queuePlaySubmission(block.number, sender, 0, playedCoins, playedCoins, _submissionIndex);

            sweepQueuedSubmissions();
        }
        _submissionIndex++;
    }
 
    /*
        Falback payable function to receive submissions and return tokens to sender
    */
    function () external payable whenNotPaused {
        _requestPlay(msg.sender, msg.value);
    }
    
    /**
     *  Receive submissions and return tokens to sender
     * */
    function play() external payable whenNotPaused {
        _requestPlay(msg.sender, msg.value);
    }

    /**
        The price of the submitted tokens when fluning
     */
    function flunTokenValue() public view returns(uint256){
        if(totalSupply()==0) return 0;
        uint256 potentialRewardPoolRevenues = getRewardPoolBalance().mul(_withdrawalFeePerToken).div(FLK_UNIT);
        return _treasuryPoolBalance
            .add(potentialRewardPoolRevenues)
            .mul(FLK_UNIT)
            .div(totalSupply());
    }

    
    /**
     *  Fluning is playing using owned FLK tokens
     */
    function flun(uint256 playedTokens) public whenNotPaused {
        if(playedTokens==0){
            sweepQueuedSubmissions();
            return;
        }
        //require(playedTokens <= balanceOf(_msgSender()), "FlukePlay: Insufficient balance");

        uint tokenPrice = flunTokenValue();

        uint256 playedCoins = playedTokens.mul(tokenPrice).div(10**18);

        _burn(_msgSender(), playedTokens);

        if(_decisionDelayBlocksCount==0){
            uint32 ticketNumber = generateTiketNumber(_submissionIndex);

            processPlay(_msgSender(), playedTokens, 0, playedCoins, _submissionIndex, ticketNumber);
            
        }else{
            queuePlaySubmission(block.number, _msgSender(), playedTokens, 0, playedCoins, _submissionIndex);

            sweepQueuedSubmissions();

        }
        _submissionIndex++;
    }
    
    function _breed(address payable player, uint256 playedTokens, uint32 factor, uint64 index, uint32 ticketNumber) internal{
        //uint256 threshold = 4294967295 / (2 * factor);
        uint256 threshold = 2147483648 / factor;

        uint256 children;
        if(ticketNumber <= threshold){
            children = playedTokens.mul(factor);
            _mint(player, children);
            _breedWins++;
        }else{
            children = 0;
        }
        
        incrementBreedStats(player, playedTokens, children);

        emit Bred(player, playedTokens, factor, 
                index, uint256(getSecureRandomNumberSeed()), 
                ticketNumber, children);
    }
    
    function processBreedSubmission(BreedSubmission storage submission) internal{
        uint256 seed = uint256(getSecureRandomNumberSeed());

        uint32 ticketNumber = generateTiketNumber(seed, submission.index);

        _breed(submission.player, submission.playedValue, submission.factor, submission.index, ticketNumber);
    }

    function _requestBreed(address payable player, uint256 playedTokens, uint32 factor) internal {
        require(playedTokens > 0, "Amount must be > 0");
        require(factor >= 2 && factor <= 1000000, "factor must be between 2 and 1000000");

        _burn(player, playedTokens);
        _breedBurntFlk += playedTokens;

        if(_decisionDelayBlocksCount==0){
            uint256 seed = uint256(getSecureRandomNumberSeed());

            uint32 ticketNumber = generateTiketNumber(seed, _submissionIndex);
        
            _breed(player, playedTokens, factor, _submissionIndex, ticketNumber);
        }else{
            queueBreedSubmission(block.number, player, playedTokens, factor, _submissionIndex);

            sweepQueuedSubmissions();

        }
        _submissionIndex++;
    }

    function breed(uint256 playedTokens, uint32 factor) public whenNotPaused {
        _requestBreed(_msgSender(), playedTokens, factor);
    }

    function pause() public onlyOwner{
        super._pause();
    }
    
    function unpause() public onlyOwner {
        require(!_liquidated, "The game has been liquidated");
        super._unpause();
    }

    function clearRewardPool() internal whenPaused onlyOwner{
        _treasuryPoolBalance = address(this).balance;
    }

    function liquidate() public onlyOwner{
        super._pause();
        clearRewardPool();
        _withdrawalFeePerToken = 0;
        _liquidated = true;
    }

    function destroy() public onlyOwner{
        require(this.totalSupply()<=balanceOf(_msgSender()), "Can not be destoryed");
        selfdestruct(_msgSender());
    }

    function getGameSettings() public view returns(
        uint256 depositTreasuryContributionPerFlk,
        uint256 withdrawalFeePerFlk,
    
        uint32 decisionDelayBlocksCount, uint8 previousSubmissionsSweepCount
    )
    {
        return (
            _depositTreasuryContributionPerCoin,
            _withdrawalFeePerToken,
                        
            _decisionDelayBlocksCount, _previousSubmissionsSweepCount);
    }

    function getTokenValuationInfo() public view returns(
        uint256 rewardPoolBalance,
        uint256 treasuryPoolBalance,
        uint256 tokenNominalValue,
        uint256 totalSupply,
        uint256 totalBurnt,
        uint256 flunningTokenValue
    ){
        return (
            this.getRewardPoolBalance(), 
            this.getTreasuryPoolBalance(),
            this.getTokenNominalValue(),
            this.totalSupply(),
            this.totalBurnt(),
            this.flunTokenValue());
    }
    
    function getGameState() public view returns(
        uint64 playSubmissionsCount, uint64 playWinsCount, uint256 playStatsDetails,
        
        uint256 flunningTokenValue,

        uint64 breedSubmissionsCount, 
        uint64 breedWinsCount, 
        uint256 breedTokensSubmitted, 
        uint256 bredTokens

        ){
        
        (
        uint64 playSubmissions,
        uint64 playWins,
        uint256 playDetails,

        uint64 breedSubmissions,
        uint64 breedWins,
        uint256 breedTokensSubmitted_,
        uint256 bredTokens_) = stats();
        
        return (playSubmissions, playWins, playDetails,
            
            this.flunTokenValue(),

            breedSubmissions, 
            breedWins, 
            breedTokensSubmitted_, 
            bredTokens_
            );
    }

    function getWithdrawalCoinsForTokens(uint256 flkAmount) public view returns(uint256){
        // treasury * (flkAmount/totalSupply)*((100-withdrawlFeePc)/100)
        uint256 withdrawalAmount = _treasuryPoolBalance
                .mul(flkAmount)  //shareholding rate
                .mul(FLK_UNIT - _withdrawalFeePerToken)
                //.mul(100-_withdrawlFeePc)
                .div(totalSupply())
                //.div(100) //deduct withdrawal fee
                .div(FLK_UNIT) //deduct withdrawal fee
                ;
        return withdrawalAmount;
    }

    function _withdraw(address sender, uint256 amount) internal{
        uint256 withdrawalCoins = getWithdrawalCoinsForTokens(amount);
        
        _totalWithdrawnTokens += amount;
        _totalWithdrawnCoins += withdrawalCoins;

        super._burn(sender, amount);
        
        _treasuryPoolBalance = _treasuryPoolBalance.sub(withdrawalCoins);
        emit Withdrew(sender, amount, withdrawalCoins);

        address payable recipient = address(uint160(sender));
        recipient.transfer(withdrawalCoins);
    }

    function withdraw(uint256 amount) public {
        _withdraw(_msgSender(), amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public whenNotPaused returns (bool) {
        require(recipient!=address(this), "Withdrawal not permitted using this method");
        return super.transferFrom(sender, recipient, amount);
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        if(recipient==address(this)){
            _withdraw(_msgSender(), amount);
            return true;
        }
        require(!paused(), "Transfer disabled while paused");
        return super.transfer(recipient, amount);
    }

}
