// SPDX-License-Identifier: UNLICENCED
pragma solidity 0.7.6;

contract CryptoSOS {

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

    // The 3x3 grid of the game. It is more efficient to keep it as a byte array and cast it to string when needed externally.
    bytes private grid;

    address payable private owner;
    // Used to lock owner's profit while a game is conducted.
    uint private ownersProfitLocked;

    address payable private firstPlayer;
    address payable private secondPlayer;

    // The address of the player playing.
    address payable private playerPlaying;

    // The timestamp of the block, when the first player joined.
    uint private firstPlayerJoinedTime;

    // The timer for the player move.
    uint private timer;

    /*
        *CryptoSOS Events.
    */
    event NewGame(address _firstPlayer, address _secondPlayer);
    event MoveEvent(address _playerAddress, uint8 _placement, uint8 _symbol);

    constructor() {
        owner = msg.sender;
        constructGame();
    }

    /*
        * The external public API.
    */
    function play() external payable checkStateForPlay {
        address payable playerAddress = msg.sender;
        // The first player joins the game.
        if (isEmpty(firstPlayer)) {
            // Lock the ether of the first player.
            ownersProfitLocked = 1 ether;
            // Record the time of the block when the first player joined, needed for the cancel method.
            firstPlayerJoinedTime = block.timestamp;
            firstPlayer = playerAddress;
            // When the first player joins the game, an event that has 0 as the second address is omited.
            emit NewGame(firstPlayer, address(0));
        } 
        // The second player joins the game.
        else if (isEmpty(secondPlayer)) {
            // Lock another ether for the second player.
            ownersProfitLocked = ownersProfitLocked + 1 ether;
            // Initialize the timer of this game.
            timer = block.timestamp;
            secondPlayer = playerAddress;
            // Now both players are present and the game begins.
            emit NewGame(firstPlayer, secondPlayer);
            playerPlaying = firstPlayer;
        }
        // This case should have been caught by the modifier.
        // If the code enters this, something has gone really wrong.
        else {
            revert ("Illegal state reached.");
        }
    }

    function placeS(uint8 _placement) external isInTheGame checkStateForPlace(_placement) {
        place(_placement, SYMBOL_S);
    }

    function placeO(uint8 _placement) external isInTheGame checkStateForPlace(_placement) {
        place(_placement, SYMBOL_O);
    }

    function getGameState() external view returns(string memory grid_) {
        grid_ = string(grid);
    }
    
    function collectProfit() external isOwner {
        uint ownersProfit = address(this).balance - ownersProfitLocked;
        owner.transfer(ownersProfit);
    }

    function cancel() external isInTheGame checkStateForCancel {
        address payable firstPlayerTemp = firstPlayer;
        firstPlayer = address(0);
        // Unlock the owner's profit.
        ownersProfitLocked = 0;
        // Paying should always be the last action!
        firstPlayerTemp.transfer(1 ether);
    }

    function ur2slow() external isInTheGame hasGameStarted didTimePassed(60) checkStateForUr2slow {
        address payable winningPlayerTemp = getPlayerNotPlaying();
        emit MoveEvent(winningPlayerTemp, 0, 0);
        clearAddresses();
        clearBoard();
        // Unlock the owner's profit.
        ownersProfitLocked = 0;
        // Paying should always be the last action!
        winningPlayerTemp.transfer(1.9 ether);
    }

    // Because the players can make the game stuck the game by not playing at all, the owner can intervene after 5 minutes.
    // After calling this method, the players are kicked and the host takes the full ether amount.
    function gameExpired() external hasGameStarted isOwner didTimePassed(300) {
        clearAddresses();
        clearBoard();
        ownersProfitLocked = 0;
    }

    /*
        * Helper Functions.
    */
    function place(uint8 _placement, byte  _symbol) internal {
        uint8 arrayPlacement = _placement - 1;
        // Check if the input corresponds to an empty grid slot. Revert if not.
        require(grid[arrayPlacement] == SYMBOL_DASH, "The grid slot selected was not an empty slot.");
        // Make the change to the grid.
        grid[arrayPlacement] = _symbol;
        // Emit a move Event.
        emit MoveEvent(playerPlaying, _placement, convertFromSymbolToNumber(_symbol));
        // Check if the player won by making the move.
        if (isWinning(_placement)) {
            endWin();
            return;
        }
        // Check if the game concluded with a draw.
        if (isDraw()) {
            endDraw();
            return;
        }
        // Change the player playing.
        playerPlaying = getPlayerNotPlaying();
        // Reset the timer for the next turn.
        timer = block.timestamp;
    }

    function isWinning(uint8 _placement) internal view returns (bool won_) {
        if (_placement == 5) {
            return checkCross() || checkDiagonals();
        }
        if (_placement == 1 || _placement == 3 || _placement == 7 || _placement == 9) {
            return checkCross() || checkFrame();
        }
        if (_placement == 2 || _placement == 4 || _placement == 6 || _placement == 8) {
            return checkDiagonals() || checkFrame();
        }
    }

    function isDraw() internal view returns (bool won_) {
        for (uint8 i=0; i<9; i++) {
            if(grid[i] == SYMBOL_DASH) {
                return false;
            }
        }
        return true;
    }

    function checkCross() internal view returns (bool won_) {
        if ((isS(1) && isO(5) && isS(9)) || (isS(3) && isO(5) && isS(7))){
            return true;
        }
        return false;
    }

    function checkDiagonals() internal view returns (bool won_) {
        if ((isS(2) && isO(5) && isS(8)) || (isS(4) && isO(5) && isS(6))){
            return true;
        }
        return false;
    }

    function checkFrame() internal view returns (bool won_) {
        if ((isS(1) && isO(2) && isS(3)) || (isS(3) && isO(6) && isS(9)) || (isS(7) && isO(8) && isS(9)) || (isS(1) && isO(4) && isS(7))){
            return true;
        }
        return false;
    }

    function endWin() internal {
        address payable winningPlayerTemp = playerPlaying;
        clearAddresses();
        clearBoard();
        // Unlock the owner's profit.
        ownersProfitLocked = 0;
        // Paying should always be the last action!
        winningPlayerTemp.transfer(1.8 ether);
    }

    function endDraw() internal {
        address payable firstPlayerTemp = firstPlayer;
        address payable secondPlayerTemp = secondPlayer;
        clearAddresses();
        clearBoard();
        // Unlock the owner's profit.
        ownersProfitLocked = 0;
        // Paying should always be the last action!
        firstPlayerTemp.transfer(0.9 ether);
        secondPlayerTemp.transfer(0.9 ether);
    }

    function constructGame() internal {
        grid = new bytes(9);
        clearBoard();
    }

    function clearAddresses() internal {
        firstPlayer = address(0);
        secondPlayer = address(0);
        playerPlaying = address(0);
    }

    function clearBoard() internal {
        for (uint8 i=0; i<9; i++) {
            grid[i] = SYMBOL_DASH;
        }
    }

    function getPlayerNotPlaying() internal view returns (address payable player_) {
        if (playerPlaying == firstPlayer) {
            return secondPlayer;
        }
        return firstPlayer;
    }

    /*
        *Function specific modifiers
    */

    // Checks if the play function can be called for the specific caller.
    modifier checkStateForPlay() {
        // Check if there is an available slot.
        require(isEmpty(firstPlayer) || isEmpty(secondPlayer), "The game has already started.");
        // Check if the player has already queued as first player.
        require(msg.sender != firstPlayer, "You have already queued to play.");
        // Exacly one Ether ether is required to play, in all other cases, the function call will be reverted.
        require(msg.value == 1 ether, "The amount of Ether to participate should be 1 Ether.");
        _;
    }

    // Checks if the place functions can be called for the specific user, for the specific state of the game.
    modifier checkStateForPlace(uint8 _placement) {
        // Checks if it is this player's turn to play.
        require(msg.sender == playerPlaying, "It is not your turn to play.");
        // Checks if the input is out of bounce.
        require(_placement > 0 && _placement < 10, "The input given is not valid.");
        _;
    }

    modifier checkStateForCancel() {
        // Checks if the game has been started, that is when both players have joined.
        require(isEmpty(secondPlayer), "You can not cancel the game if it already has been started.");
        // Checks if two minutes have been passed.
        require(block.timestamp - firstPlayerJoinedTime > 120, "You cannot cancel the game if two minutes have not passed.");
        _;
    }

    modifier checkStateForUr2slow() {
        // A player cannot call this function if it is his turn.
        require(msg.sender != playerPlaying, "You cannot call the ur2slow function in your turn.");
        _;
    }

    // Checks if the game has not been started, that is when both players have not joined.
    modifier hasGameStarted() {
        require(!isEmpty(secondPlayer), "You can only use this function if the game has not been started.");
        _;
    }

    /*
        *General purpose modifiers
    */

    // Checks if the caller is participating in the current game.
    modifier isInTheGame() {
        // Check if there is an available slot.
        require(msg.sender == firstPlayer || msg.sender == secondPlayer, "You are not participating in the current game.");
        _;
    }

    // Checks if caller is the owner.
    modifier isOwner() {
        require(msg.sender == owner, "This function can only be called by the owner.");
        _;
    }

    // Checks if a certain amount of time has passed from the last update of the timer.
    modifier didTimePassed(uint _timePassed) {
        require(block.timestamp - timer > _timePassed, string(abi.encodePacked("The time passed from the last update of the timer, is not enought to call this function.")));
        _;
    }

    /*
        *Utility Functions.
    */
    function isEmpty(address _addressToCheck) internal pure returns (bool isEmpty_) {
        isEmpty_ =  _addressToCheck == address(0);
    }

    function isS(uint8 _placement) internal view returns (bool isS_) {
        isS_ = grid[_placement-1] == SYMBOL_S;
    }

    function isO(uint8 _placement) internal view returns (bool isO_) {
        isO_ = grid[_placement-1] == SYMBOL_O;
    }

    function convertFromSymbolToNumber(byte _symbol) internal view returns (uint8) {
        if (_symbol == SYMBOL_S) {
            return 1;
        }
        return 2;
    }
}