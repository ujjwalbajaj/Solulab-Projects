import React, { Component } from 'react';
import Web3 from 'web3';
import Navbar from './Navbar';
import NFTList from './NFTList';

class App extends Component {

  constructor(props) {
    super(props)
    this.state = {
      account: ''
    }
  }

  async componentWillMount() {
    await this.loadWeb3()
    await this.loadAccount()
  }

  async loadWeb3() {
    if (window.ethereum) {
      window.web3 = new Web3(window.ethereum)
      await window.ethereum.enable()
    }
    else if (window.web3) {
      window.web3 = new Web3(window.web3.currentProvider)
    }
    else {
      window.alert('Non-Ethereum browser detected. You should consider trying MetaMask!')
    }
  }

  async loadAccount() {
    const web3 = window.web3
    const accounts = await web3.eth.getAccounts()
    this.setState({ account: accounts[0] })
  }

  render() {
    return (
      <div>
        <div className="navbar">
          <Navbar data={this.state.account} />
        </div>
        <div className="content">
          <NFTList data={this.state.account} />
        </div>
      </div>
    );
  }

}

export default App;