# CRYPTO-SOS

A blockchain adaptation of the **[well-known SOS game](https://en.wikipedia.org/wiki/SOS_(game))**. 
The application consists of two key components: a Solidity smart contract, 
which contains the functionality for players to engage in the game and
storing the state of all players on the blockchain, and a React-based 
user interface.

## Setting up the environment

To run the application locally, it's necessary to install a blockchain simulator environment,
such as **[Ganache](https://trufflesuite.com/ganache/)**. The communication between the blockchain and the Web Application is facilitated by
the web3.js library, utilizing sockets. To enable the communication, ensure that your local blockchain environment
is configured to listen on **port 8546**.

The necessary migration scripts are provided in the **migrations** folder.
Deploying the smart contracts to Ganache is straightforward; simply execute the **truffle migrate** command.

The React-based web application requires the **Node.js** runtime environment for its execution.
Once Node.js is installed, download the needed dependencies, by running the Node command
**npm install**, in a terminal which sees the root folder of the project.
After successfully downloading the dependencies, initiate the application by running the **npm start** command.
This will launch a simple Node.js server and deploy the web application to it.

The local deployment of your application can be found at the URL (http://localhost:3000/).
To start a game, a player should simply select a symbol, either "S" or "O", and then move his/her cursor to
interact with the game board.
