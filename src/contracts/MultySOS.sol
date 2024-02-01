
// SPDX-License-Identifier: UNLICENCED
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

contract MultySOS {

    /*
        * Constants
    */

    // The game's symbols. Would prefer them as enums but this format is cheaper and easier to implement.
    byte private SYMBOL_S = "S";
    byte private SYMBOL_O = "O";
    byte private SYMBOL_DASH = "-";

    /*
        * State variables. These variables are saved in the state on the contract.
        * Every change of these variables costs gas, and so should be done with caution.
    */

    // The address of the owner.
    address payable private owner;
    // Used to lock owner's profit while a game is conducted.
    uint private ownersProfitLocked;

    // The counter of the ID increment.
    uint32 private idIncrement = 1;

    // If an open game exists, its ID is stored here.
    uint32 private openGame;

    // The game states for each game in the MultySOS.
    mapping(uint32 => SingleSOS) private states;

    /*
        *CryptoSOS Events.
    */
    event NewGame(uint32 _gameID, address _firstPlayer, address _secondPlayer);
    event MoveEvent(uint32 _gameID, address _playerAddress, uint8 _placement, uint8 _symbol);

    constructor() {
        owner = msg.sender;
    }

    /*
        * The external public API.
    */
    function play() external payable checkStateForPlay {
        address payable playerAddress = msg.sender;
        // If an open game does not exist.
        if (openGame == 0) {
            // Create the minimum state for a game.
            createGame(playerAddress);
        }
        else {
            // Join an already existing game.
            joinGame(playerAddress);
        }
    }

    function placeS(uint32 _gameID, uint8 _placement) external doesGameExist(_gameID) isInTheGame(_gameID) checkStateForPlace(_gameID, _placement) {
        place(_gameID, _placement, SYMBOL_S);
    }

    function placeO(uint32 _gameID, uint8 _placement) external doesGameExist(_gameID) isInTheGame(_gameID) checkStateForPlace(_gameID, _placement) {
        place(_gameID, _placement, SYMBOL_O);
    }

    function getGameState(uint32 _gameID) external view doesGameExist(_gameID) returns(string memory grid_) {
        grid_ = string(states[_gameID].grid);
    }
    
    function collectProfit() external isOwner {
        uint ownersProfit = address(this).balance - ownersProfitLocked;
        owner.transfer(ownersProfit);
    }

    function cancel(uint32 _gameID) external doesGameExist(_gameID) isInTheGame(_gameID) checkStateForCancel(_gameID) {
        SingleSOS memory state = states[_gameID];
        address payable firstPlayerTemp = state.firstPlayer;
        openGame = 0;
        delete states[_gameID];
        unlockTwoEther();
        // Paying should always be the last action!
        firstPlayerTemp.transfer(1 ether);
    }

    function ur2slow(uint32 _gameID) external doesGameExist(_gameID) isInTheGame(_gameID) isOpponentTurn(_gameID) hasGameStarted(_gameID)
     didTimePassed(_gameID, 60) {
        SingleSOS memory state = states[_gameID];
        address payable winningPlayerTemp = getPlayerNotPlaying(state);
        emit MoveEvent(_gameID, winningPlayerTemp, 0, 0);
        delete states[_gameID];
        // Unlock the owner's profit.
        ownersProfitLocked = 0;
        // Paying should always be the last action!
        winningPlayerTemp.transfer(1.9 ether);
    }

    /*
        * Helper Functions.
    */
    function place(uint32 _gameID, uint8 _placement, byte  _symbol) internal {
        SingleSOS storage state = states[_gameID];
        uint8 arrayPlacement = _placement - 1;
        // Check if the input corresponds to an empty grid slot. Revert if not.
        require(state.grid[arrayPlacement] == SYMBOL_DASH, "The grid slot selected was not an empty slot.");
        // Make the change to the grid.
        state.grid[arrayPlacement] = _symbol;
        // Emit a move Event.
        emit MoveEvent(_gameID, state.playerPlaying, _placement, convertFromSymbolToNumber(_symbol));
        // Check if the player won by making the move.
        if (isWinning(state, _placement)) {
            endWin(_gameID);
            return;
        }
        // Check if the game concluded with a draw.
        if (isDraw(state)) {
            endDraw(_gameID);
            return;
        }
        // Change the player playing.
        state.playerPlaying = getPlayerNotPlaying(state);
        // Reset the timer for the next turn.
        state.timer = block.timestamp;
    }

    function isWinning(SingleSOS memory _state, uint8 _placement) internal view returns (bool isWinning_) {
        if (_placement == 5) {
            return checkCross(_state) || checkDiagonals(_state);
        }
        if (_placement == 1 || _placement == 3 || _placement == 7 || _placement == 9) {
            return checkCross(_state) || checkFrame(_state);
        }
        if (_placement == 2 || _placement == 4 || _placement == 6 || _placement == 8) {
            return checkDiagonals(_state) || checkFrame(_state);
        }
    }

    function isDraw(SingleSOS memory _state) internal view returns (bool) {
        for (uint8 i=0; i<9; i++) {
            if(_state.grid[i] == SYMBOL_DASH) {
                return false;
            }
        }
        return true;
    }

    function checkCross(SingleSOS memory _state) internal view returns (bool) {
        if ((isS(_state, 1) && isO(_state, 5) && isS(_state, 9)) || (isS(_state, 3) && isO(_state, 5) && isS(_state, 7))) {
            return true;
        }
        return false;
    }

    function checkDiagonals(SingleSOS memory _state) internal view returns (bool) {
        if ((isS(_state, 2) && isO(_state, 5) && isS(_state, 8)) || (isS(_state, 4) && isO(_state, 5) && isS(_state, 6))) {
            return true;
        }
        return false;
    }

    function checkFrame(SingleSOS memory _state) internal view returns (bool) {
        if ((isS(_state, 1) && isO(_state, 2) && isS(_state, 3)) || (isS(_state, 3) && isO(_state, 6) && isS(_state, 9)) ||
         (isS(_state, 7) && isO(_state, 8) && isS(_state, 9)) || (isS(_state, 1) && isO(_state, 4) && isS(_state, 7))) {
            return true;
        }
        return false;
    }

    function endWin(uint32 _gameID) internal {
        address payable winningPlayerTemp = states[_gameID].playerPlaying;
        delete states[_gameID];
        unlockTwoEther();
        // Paying should always be the last action!
        winningPlayerTemp.transfer(1.8 ether);
    }

    function endDraw(uint32 _gameID) internal {
        address payable firstPlayerTemp = states[_gameID].firstPlayer;
        address payable secondPlayerTemp = states[_gameID].secondPlayer;
        delete states[_gameID];
        unlockTwoEther();
        // Paying should always be the last action!
        firstPlayerTemp.transfer(0.9 ether);
        secondPlayerTemp.transfer(0.9 ether);
    }

    // The first player creates a minimum game state is constructed when the first player enters.
    function createGame (address payable _firstPlayer) internal {
        lockOneEther();
        SingleSOS memory newGame; //= SingleSOS();
        newGame.firstPlayer = _firstPlayer;
        newGame.firstPlayerJoinedTime = block.timestamp;
        newGame.grid = new bytes(9);
        uint32 gameID = generateGameID();
        states[gameID] = newGame;
        // When the first player joins the game, an event that has 0 as the second address is omited.
        emit NewGame(gameID, _firstPlayer, address(0));
        // The game is now open for another player to join.
        openGame = gameID;
    }

   // The second player completes the game state and initializes the game.
    function joinGame (address payable _secondPlayer) internal {
        lockOneEther();
        SingleSOS storage gameJoined = states[openGame];
        gameJoined.secondPlayer = _secondPlayer;
        gameJoined.playerPlaying = gameJoined.firstPlayer;
        createBoard(gameJoined.grid);
        // Initialize the timer of this game.
        gameJoined.timer = block.timestamp;
        // Now both players are present and the game begins.
        emit NewGame(openGame, gameJoined.firstPlayer, _secondPlayer);
        // The game has closed now, a new game should be created.
        openGame = 0;
    }

    function createBoard(bytes storage _grid) internal {
        for (uint8 i=0; i<9; i++) {
            _grid[i] = SYMBOL_DASH;
        }
    }

    function generateGameID() internal returns (uint32 idIncrement_){
        idIncrement_ = idIncrement;
        idIncrement++;
    }

    // Locks a player fee.
    function lockOneEther() internal {
        ownersProfitLocked = ownersProfitLocked + 1 ether;
    }

    // Unocks the game fee.
    function unlockTwoEther() internal {
        ownersProfitLocked = ownersProfitLocked - 2 ether;
    }

    function getPlayerNotPlaying(SingleSOS memory _state) internal pure returns (address payable) {
        if (_state.playerPlaying == _state.firstPlayer) {
            return _state.secondPlayer;
        }
        return _state.firstPlayer;
    }

    /*
        *Function specific modifiers
    */

    // Checks if the play function can be called for the specific caller.
    modifier checkStateForPlay() {
        // The player has already queued to play a game.
        require(states[openGame].firstPlayer != msg.sender, "You have already queued to play a game.");
        // Exacly one Ether ether is required to play, in all other cases, the function call will be reverted.
        require(msg.value == 1 ether, "The amount of Ether to participate should be 1 Ether.");
        _;
    }

    // Checks if the place functions can be called for the specific user, for the specific state of the game.
    modifier checkStateForPlace(uint32 _gameID, uint8 _placement) {
        SingleSOS memory state = states[_gameID];
        // Checks if it is this player's turn to play.
        require(msg.sender == state.playerPlaying, "It is not your turn to play.");
        // Checks if the input is out of bounce.
        require(_placement > 0 && _placement < 10, "The input given is not valid.");
        _;
    }

    modifier checkStateForCancel(uint32 _gameID) {
        SingleSOS memory state = states[_gameID];
        // Checks if the game has not been started, that is when only the first player ha joined.
        require(isEmpty(state.secondPlayer), "You can not cancel the game if it already has been started.");
        // Checks if two minutes have been passed.
        require(block.timestamp - state.firstPlayerJoinedTime > 120, "You cannot cancel the game if two minutes have not passed.");
        _;
    }

    /*
        *General purpose modifiers
    */

    // Checks if the game with the given gameID exists.
    modifier doesGameExist(uint32 _gameID) {
        SingleSOS memory state = states[_gameID];
        // A game exists only if the first player has joined it.
        require(!isEmpty(state.firstPlayer), "A game with the given gameID does not exist.");
        _;
    }

    modifier hasGameStarted(uint32 _gameID) {
        SingleSOS memory state = states[_gameID];
        // Checks if the game has not been started, that is when both players have not joined.
        require(!isEmpty(state.secondPlayer), "You can only use this function if the game has not been started.");
        _;
    }

    // Checks if the caller is participating in the game with the given gameID.
    modifier isInTheGame(uint32 _gameID) {
        SingleSOS memory state = states[_gameID];
        // Check if the caller is one of the two players.
        require(msg.sender == state.firstPlayer || msg.sender == state.secondPlayer, "You are not participating in the game with the given gameID.");
        _;
    }

    // Checks if caller is the owner.
    modifier isOwner() {
        require(msg.sender == owner, "This function can only be called by the owner of the contract.");
        _;
    }

    // Checks if a certain amount of time has passed from the last update of the timer.
    modifier didTimePassed(uint32 _gameID, uint _timePassed) {
        require(block.timestamp - states[_gameID].timer > _timePassed, "The time passed from the last update of the timer, is not enought to call this function.");
        _;
    }

    // Check if it is the opponents turn to play. Reverts in case it is not.
    modifier isOpponentTurn(uint32 _gameID) {
        SingleSOS memory state = states[_gameID];
        // A player cannot call this function if it is his turn.
        require(msg.sender != state.playerPlaying, "You cannot call this function in your turn.");
        _;
    }

    /*
        *Utility Functions.
    */

    function isS(SingleSOS memory _state, uint8 _placement) internal view returns (bool isS_) {
        isS_ = _state.grid[_placement-1] == SYMBOL_S;
    }

    function isO(SingleSOS memory _state, uint8 _placement) internal view returns (bool isO_) {
        isO_ = _state.grid[_placement-1] == SYMBOL_O;
    }
    function isEmpty(address _addressToCheck) internal pure returns (bool isEmpty_) {
        isEmpty_ =  _addressToCheck == address(0);
    }

    // This function should only be called to convert from symbol "B" to 1 or from symbol "O" to 2. 
    function convertFromSymbolToNumber(byte _symbol) internal view returns (uint8) {
        if (_symbol == SYMBOL_S) {
            return 1;
        }
        return 2;
    }

    // A struct that keeps the state of a single MultySOS game.
    struct SingleSOS {

        // The 3x3 grid of the game. It is more efficient to keep it as a byte array and cast it to string when needed externally.
        bytes grid;

        address payable firstPlayer;
        address payable secondPlayer;

        // The address of the player playing.
        address payable playerPlaying;

        // The timestamp of the block, when the first player joined.
        uint firstPlayerJoinedTime;

        // The timer for the player move.
        uint timer;
    }
}