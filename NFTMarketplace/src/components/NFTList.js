import React, { Component } from 'react';
import { getName, getBalance } from '../utils/NFTFinder';

class NFTList extends Component {

    constructor(props) {
        super(props);
        this.state = {
            account: this.props.data,
            tokenContractAddresses: []
        }
        getTokenAddress(this.state.account);
    }

    getTokenAddress(accountAddress) {
        fetch(`https://api.etherscan.io/api?module=account&action=tokennfttx&address=${accountAddress}&startblock=0&endblock=999999999&sort=asc&apikey=UI66QQP8UN6EAXXNN85W8WMS565QNB398J`)
            .then(response => response.json())
            .then(result => {
                // Store all the unique contract addresses in the array tokenContractAddresses[]
            })
            .catch(e => { console.log(e) });
    }

    render() {
        return (
            <div>
                {this.state.tokenContractAddresses.map(res => (
                    <div className="nft-list">
                        <h2>{ getName(res) }</h2>
                        <p>{ getBalance(res, this.state.account) }</p>
                    </div>
                ))}
            </div>
        );
    }

}

export default NFTList;