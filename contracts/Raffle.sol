// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol"; // gia na kaneis interact me to contract
import "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

// erros anti gia require
error Raffle__NotEnughtETHEntered();
error Raffle__TransferFailed();
error Raffle__NotOpen();
error Raffle___UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);

/**@title A sample Raffle Contract
 * @author Patrick Collins
 * @notice This contract is for creating a sample raffle contract
 * @dev This implements the Chainlink VRF Version 2
 */

contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface {
    /* Type declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    } // uint256 0 = OPEN, 1 = CALCULATING

    /* State Variable */
    // vazoume kai tis storage var
    uint256 private immutable i_entranceFee; // epeidi 8eloyme na to sosoyme (set) mia fora to kanoume constan ή imutable variable (saves gas)
    address payable[] private s_players;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant NUM_WORDS = 1;

    /* Lottery Variables */
    address private s_recentWinner;
    RaffleState private s_raffleState;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval;

    /* Events */
    event RaffleEnter(address indexed player);
    event RequestRaffleWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);

    /* Functions */

    constructor(
        address vrfCoordinatorV2, // einai add contract
        uint256 entranceFee,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        uint256 interval
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = entranceFee; //
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2); // to xreiazomaste gia na to kalesoume sto requestRandomWiners, pername to addredd mesa apo to Interface sto VRFConsumerBase
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_interval = interval;
    }

    // Gia na paroyme to coordinator contract 8a xreisimopoihsoyme to VRFCoordinatorV2Interface (to interface) kai 8a toyu perasoyme to address tou VRFcoordinator

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnughtETHEntered(); // error code
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen(); // 8eloume na mpenoun otan einai anoixta to lotary opote error gia otan einai klistei
        }
        s_players.push(payable(msg.sender)); // otan mpainei kapoios sto rafel, ginetai typecast gt to msg.sender den einai payable
        // Emit an event when we update a dynamic array or mapping
        // Named events with the function naem reversed
        emit RaffleEnter(msg.sender);
    }

    /*
     * @dev This is the function that the Chainlink Keeper nodes call
     * they look for `upkeepNeeded` to return True.
     * the following should be true for this to return true:
     * 1. The time interval has passed between raffle runs.
     * 2. The lottery is open.
     * 3. The contract has ETH.
     * 4. Implicity, your subscription is funded with LINK.
     */

    // Itan calldata kai to kaname memory giati to calldata den doulevei me strings
    function checkUpkeep(
        bytes memory /* checkData */
    ) public override returns (bool upkeepNeeded, bytes memory /* performData*/) {
        bool isOpen = (RaffleState.OPEN == s_raffleState); // einai true, isxyei otan to s_raffleState einai se OPEN state
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = (s_players.length > 0); // blepoume na exoume paixtes
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
        // (block.timestamp - last block timestamp) > interval
        // interval einai kapoios ari8mo se sec gia to poso xrono 8eloyme na perimenoyme meta3i lottery runs
        // Otan 8a epistrefei true oi chainlink nodes 8a kaliun tin performUpkeep
        // Htan extrnal (kaleitai mono apo alla SC), kanontas to public mporei na kalestei kai se auto to contract
    }

    // An sto checkUpKeep eixa data 8a pernouse aftomata sto performUpkeep giayto einai kai override

    // Otan einai o xronos na paroume random winner
    // external funxtion einai poio f8ines apo tis public
    function performUpkeep(bytes calldata /* performData */) external override {
        // Request the random number. To kaloume apo to constructor
        // Once we get it, do something wi th it
        // 2 transaction process
        (bool upkeepNeeded, ) = checkUpkeep("");
        // require(upkeepNeeded, "Upkeep not needed");
        if (!upkeepNeeded) {
            revert Raffle___UpkeepNotNeeded(
                address(this).balance, // vlepei an yparxoyn ETH
                s_players.length, // vlepei an yparxoun paixtes
                uint256(s_raffleState) // vlepei an einai anoixto
            );
        }
        s_raffleState = RaffleState.CALCULATING; // gia na min mporoun alloi na mpoun sto lorare kai na min kanoun triger allo update
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, // keyHash
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        ); // Epistrefei ena ID poios to zitaei ola ayta klp
        emit RequestRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length; // 8a mas dosei to index toy random winner
        address payable recentWinner = s_players[indexOfWinner]; // gia na paroyme tin die8insi, to poios einai
        s_recentWinner = recentWinner; // update o teleytaios nikitis
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0); // recet o pinakas me tous paixtes
        s_lastTimeStamp = block.timestamp;
        (bool success, ) = recentWinner.call{value: address(this).balance}(""); // stelnoume ta xrimata se ayto to conrtact
        // require(success)
        if (!success) {
            revert Raffle__TransferFailed();
        }
        emit WinnerPicked(recentWinner);
    }

    /* View / Pure functions */

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
        // einai se bytcode, einai const variable, texnika den diavazei apo to storage giauto einai pure kai oxi view function
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getLatestTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRequestConfiramtions() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }
}
