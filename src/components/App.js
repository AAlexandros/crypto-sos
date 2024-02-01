import React, { Component } from 'react';
import Web3 from 'web3'
import './App.css';
import CryptoSOS from '../objects/CryptoSOS.json'
import MultySOS from '../objects/MultySOS.json'
import grid from '../grid.png'
import update from 'immutability-helper';

const SYMBOL_S = 'sos-s'
const SYMBOL_O = 'sos-o'
const SYMBOL_BLANK = 'sos-blank'
const SYMBOL_SHINY = 'sos-shiny'
const SYMBOL_ARRAY = {'sos-s' : '/images/sos_s.png', 'sos-o' : '/images/sos_o.png', 'sos-blank' : '/images/sos_blank.png', 'sos-shiny' : '/images/sos_shiny.png'}

const BUTTON_LABEL_SELECT = 'Select a symbol to place'
const BUTTON_LABEL_S = 'Symbol "S" is selected'
const BUTTON_LABEL_O = 'Symbol "O" is selected'

const GRID_LABEL_DEFAULT = 'SOS Grid'
const GRID_LABEL_PLACE = 'Select your symbol'

const EMPTY_ADDRESS = '0x0000000000000000000000000000000000000000'

class App extends Component {

    constructor(props) {
    super(props)
    this.state = {
      contract : null,
      symbolArray: [],
      activeSymbolArray: [],
      contractAddress: 0,
      userAddress: 0,
      ipAddress: '',
      portNumber: '',
      boardState: '',
      inGame: false,
      condfiguringContract: true,
      waitingInLobby: false,
      playing: false,
      symbolSelected: 0,
      playerPlayingWith: 0,
      //used for multysos
      gameID: 0,
      gameResult: 0,
      gameEnded: false
    }
    this.handleContractAddressChange = this.handleContractAddressChange.bind(this)
    this.handleUserAddressChange = this.handleUserAddressChange.bind(this)
    this.handleIpAddressChange = this.handleIpAddressChange.bind(this)
    this.handlePortNumberChange = this.handlePortNumberChange.bind(this)
    this.handleSubmit = this.handleSubmit.bind(this)
  }

  async componentWillMount() {
     this.setState({ symbolArray: this.createBlankArray() })
     this.setState({ activeSymbolArray: this.createBlankArray() })
     this.setState({  contractAddress: 0 })
  }

  async handleSubmit(event) {
    event.preventDefault();
    const web3 = new Web3('ws://' + this.state.ipAddress + ':' + this.state.portNumber)
    var abi = CryptoSOS.abi
    var callingContract = web3.eth.Contract(abi, this.state.contractAddress)
    var isMultiSOS = await this.checkMultyAbi(callingContract)
    if (isMultiSOS===true) {
      abi = MultySOS.abi
      callingContract = web3.eth.Contract(abi, this.state.contractAddress)
    }
    this.setState({contract: callingContract})

    callingContract.events.NewGame({})
    .on('data', (event) => { this.handleNewGameEvent(event)});

    callingContract.events.MoveEvent({})
    .on('data', (event) => { this.handlePlaceEvent(event)});

    await callingContract.methods.play().send({from: this.state.userAddress, value: web3.utils.toWei('1', 'ether'), gas:3000000});
    this.setState({condfiguringContract: false})
    this.setState({waitingInLobby: true})
  }

  async handleCancel(){
    const contract = this.state.contract
    try{
      if (this.state.gameID!==0){
        await contract.methods.cancel(this.state.gameID).send({from: this.state.userAddress, gas:3000000});
      }
      else {
        await contract.methods.cancel().send({from: this.state.userAddress, gas:3000000});
      }
      window.location.reload(true)
    }
    catch (err) {
      alert('Failed to cancel. Maybe 2 minutes have not passed.')
      console.error(err)
    }
  }

  async handleUr2Slow(){
    const contract = this.state.contract
    try{
      if (this.state.gameID!==0){
        await contract.methods.ur2slow(this.state.gameID).send({from: this.state.userAddress, gas:3000000});
      }
      else {
        await contract.methods.cancel().ur2slow({from: this.state.userAddress, gas:3000000});
      }
      window.location.reload(true)
    }
    catch (err) {
      alert('Failed to call ur2Slow. Maybe 1 minute has not passed.')
      console.error(err)
    }
  }

  async handlePlace(index){
    const contract = this.state.contract
    if (this.state.symbolArray[index]!==SYMBOL_BLANK) {
      return;
    }
    if (this.state.symbolSelected===1) {
      if (this.state.gameID!==0){
        await contract.methods.placeS(this.state.gameID, index + 1).send({from: this.state.userAddress, gas:3000000})
      }
      else {
        await contract.methods.placeS(index + 1).send({from: this.state.userAddress, gas:3000000})
      }
    }
    if (this.state.symbolSelected===2) {
      if (this.state.gameID!==0){
        await contract.methods.placeO(this.state.gameID, index + 1).send({from: this.state.userAddress, gas:3000000})
      }
      else {
        await contract.methods.placeO(index + 1).send({from: this.state.userAddress, gas:3000000})
      }
    }
    this.setState({symbolSelected : 0});
    this.setState(this.state);
  }

  async handleNewGameEvent(event) {
    if (event.returnValues._firstPlayer===this.state.userAddress || event.returnValues._secondPlayer===this.state.userAddress) {
      if (event.returnValues._gameID!==null && event.returnValues._gameID!==undefined) {
        this.setState({gameID : event.returnValues._gameID})
      }
      if (event.returnValues._secondPlayer===EMPTY_ADDRESS) {
        this.setState({condfiguringContract : false})
        this.setState({waitingInLobby : true})
        this.setState({playing : false})
      }
      else {
        this.setState({condfiguringContract : false})
        this.setState({waitingInLobby : false})
        this.setState({playing : true})
      }
    }
  }

  async handlePlaceEvent(event) {
    if (event.returnValues._playerAddress===this.state.userAddress && event.returnValues._placement===0
      && event.returnValues._placement===0) {
      alert ('You won by calling ur2Slow. You are to fast!')
      this.setState({ gameEnded: true })
      this.setState({ gameResult: 1 })
      this.setEndgame()
      return
    }
    else if (event.returnValues._placement===0 && event.returnValues._placement===0) {
      alert ('You lost by a called ur2Slow. You are to slow!')
      this.setState({ gameEnded: true })
      this.setState({ gameResult: 2 })
      this.setEndgame()
      return
    }

    var symbolPlayed = event.returnValues._symbol===1 ? SYMBOL_S : SYMBOL_O
    var arrayIndex = event.returnValues._placement - 1
    var newImageArray = update(this.state.symbolArray, { [arrayIndex]: {$set: symbolPlayed} })
    this.setState({ symbolArray: newImageArray })
    var isWin = this.checkWin()
    if (isWin && event.returnValues._playerAddress===this.state.userAddress) {
      alert('The game has ended, you won!')
      this.setState({ gameEnded: true })
      this.setState({ gameResult: 1 })
      this.setEndgame()
    }
    else if (isWin && event.returnValues._playerAddress!==this.state.userAddress) {
      alert('The game has ended, you lost!')
      this.setState({ gameEnded: true })
      this.setState({ gameResult: 2 })
      this.setEndgame()
    }
    else if (this.checkDraw()) {
      alert('The game has ended in a draw!')
      this.setState({ gameEnded: true })
      this.setState({ gameResult: 3 })
      this.setEndgame()
    }
    else {
      alert('A move was made. If it was your move, wait for your opponent move.')
    }
  }

  // In case of MultySOS an error will be emmited in purpose, for the contract identification.
  async checkMultyAbi (contract) {
    try {
      await contract.methods.getGameState().call({from : this.state.address})
      alert('The contract corresponds to a CriptoSOS game.')
      return false
    }
    catch (err) {
      alert('The contract corresponds to a MultySOS game.')
      console.error(err)
      return true
    }
  }

  setEndgame () {
    this.setState({inGame: false, condfiguringContract: false, waitingInLobby: false, playing: false, gameEnded: true})
  }

  createBlankArray() {
    var arr = [];
    var i;
    for(i=0 ; i<9 ; i++){
      arr.push(SYMBOL_BLANK);
    }
    return arr
  }

  checkWin () {
    if ((this.isS(1) && this.isO(5) && this.isS(9)) || (this.isS(3) && this.isO(5) && this.isS(7))){
            return true
    }
    if ((this.isS(2) && this.isO(5) && this.isS(8)) || (this.isS(4) && this.isO(5) && this.isS(6))){
      return true
    }
    if ((this.isS(1) && this.isO(2) && this.isS(3)) || (this.isS(3) && this.isO(6) && this.isS(9)) || (this.isS(7) && this.isO(8) && this.isS(9)) || (this.isS(1) && this.isO(4) && this.isS(7))){
        return true
    }
    return false
  }

  checkDraw () {
    for (var i=0; i<9; i++) {
      if (this.state.symbolArray[i]===SYMBOL_BLANK) {
          return false
      }
    }
    return true
  }

  isS (placement) {
    var index = placement-1
    return this.state.symbolArray[index]===SYMBOL_S
  }

  isO (placement) {
    var index = placement-1
    return this.state.symbolArray[index]===SYMBOL_O
  }

  Config() {
    return (
      <form onSubmit={this.handleSubmit}>
        <div className="form-row">
          <div className="form-group col-md-6">
            <label htmlFor="inputContractAddress">Smart contract address</label>
            <input type="text" className="form-control" id="inputContractAddress" placeholder="Contract address" value={this.state.contractAddress} onChange={this.handleContractAddressChange}/>
          </div>
          <div className="form-group col-md-6">
            <label htmlFor="inputUserAddress">User address</label>
            <input type="text" className="form-control" id="inputUserAddress" placeholder="User address" value={this.state.userAddress} onChange={this.handleUserAddressChange}/>
          </div>
        </div>
        <div className="form-row">
          <div className="form-group col-md-6">
            <label htmlFor="ipAddress">Ip address</label>
            <input type="text" className="form-control" id="ipAddress" placeholder="IP address" value={this.state.ipAddress} onChange={this.handleIpAddressChange}/>
          </div>
          <div className="form-group col-md-6">
            <label htmlFor="portNumber">Port number</label>
            <input type="text" className="form-control" id="portNumber" placeholder="Port number" alue={this.state.portNumber} onChange={this.handlePortNumberChange}/>
          </div>
        </div>
        <button type="submit" className="btn btn-primary">Play</button>
      </form>
      )
  }

  Wait() {
    return (
      <div className="jumbotron">
        <p>Waiting in lobby ...</p>
        <button className="btn btn-primary" onClick={() => this.handleCancel()}>Cancel</button>
      </div>
    )
  }

  Play() {
    var labelText
    if (this.state.symbolSelected===1) {
      labelText = BUTTON_LABEL_S
    }
    else if (this.state.symbolSelected===2) {
      labelText = BUTTON_LABEL_O
    }
    else {
      labelText = BUTTON_LABEL_SELECT
    }
    return (
      <div className="container">
        <p>{ labelText }</p>
        <div className="row justify-content-md-center">
          <div className="col col-lg-2"><button type="button" onClick={() => { this.setState({ symbolSelected: 1 })}} className={ this.state.symbolSelected === 1 ? "btn btn-success" : "btn btn-secondary" }>S</button></div>
          <div className="col col-lg-2"><button type="button" onClick={() => { this.setState({ symbolSelected: 2 })}} className={ this.state.symbolSelected === 2 ? "btn btn-success" : "btn btn-secondary" }>O</button></div>
        </div>
        <p>Additional actions</p>
        <div><button type="button" className="btn btn-secondary" onClick={() => this.handleUr2Slow()}>Ur2Slow</button></div>
      </div>
    )
  }

  End() {
    var message
    switch (this.state.gameResult) {
      case 1:
        message = "You won!"
        break
      case 2:
        message = "You lost!"
        break
      case 3:
        message = "The game ended in a draw!"
    }
    return (
      <div className="jumbotron">
        <h1>{message}</h1>
      </div>
    )
  }

  BoardBox(index) {
    var symbolString = this.state.activeSymbolArray[index]
    var symbolImageUrl = SYMBOL_ARRAY[symbolString]
    var image = window.location.origin + symbolImageUrl
    var newImageArray = update(this.state.symbolArray, { [index]: {$set: SYMBOL_SHINY} })
    return (
      <div className="col-4"><img key={index}  src={image} data-id={index} onMouseOver={() => ((this.state.symbolSelected!==0 && this.state.symbolArray[index]===SYMBOL_BLANK) ? this.setState({ activeSymbolArray: newImageArray }) : null)}
        onClick={() => this.handlePlace(index)}/></div>
    )
  }

  handleContractAddressChange(event) {
    this.setState({contractAddress: event.target.value});
  }

  handleUserAddressChange(event) {
    this.setState({userAddress: event.target.value});
  }

  handleIpAddressChange(event) {
    this.setState({ipAddress: event.target.value});
  }

  handlePortNumberChange(event) {
    this.setState({portNumber: event.target.value});
  }

  render() {
    return (
      <div>
        <nav className="navbar navbar-dark fixed-top bg-dark flex-md-nowrap p-0 shadow">
          <a
            className="navbar-brand col-sm-3 col-md-2 mr-0"
            target="_blank"
            rel="noopener noreferrer"
          >
          <img src={grid} width="30" height="30" className="d-inline-block align-top" alt="" />
          </a>
          <ul className="navbar-nav px-3">
            <li className="nav-item text-nowrap d-none d-sm-none d-sm-block">
              <small className="text-muted"><span id="account"></span></small>
            </li>
          </ul>
        </nav>
        <div className="container-fluid mt-5">
          <div className="row">
            <main role="main" className="col-lg-12 d-flex text-center">
              <div className="content mr-auto ml-auto">
                <h1 className="d-4">{ this.state.symbolSelected !== 0 ? GRID_LABEL_PLACE : GRID_LABEL_DEFAULT }</h1>

                <div className="container">
                  <div>
                  <div className="row">
                  {this.BoardBox(0)}
                  {this.BoardBox(1)}
                  {this.BoardBox(2)}
                  </div>
                  <div className="row">
                  {this.BoardBox(3)}
                  {this.BoardBox(4)}
                  {this.BoardBox(5)}
                  </div>
                  <div className="row">
                  {this.BoardBox(6)}
                  {this.BoardBox(7)}
                  {this.BoardBox(8)}
                  </div>
                  </div>

                  { this.state.condfiguringContract ? this.Config() : null }
                  { this.state.waitingInLobby ? this.Wait() : null }
                  { this.state.playing ? this.Play() : null }
                  { this.state.gameEnded ? this.End() : null }
                </div>

              </div>

            </main>
          </div>
        </div>
      </div>
    );
  }
}

export default App;
