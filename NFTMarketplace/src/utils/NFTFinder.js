const Web3 = require('web3');

const web3 = new Web3('https://mainnet.infura.io/v3/569d1f8a4e6f4fcfa2e271c2f09fbdf2');

// The minimum ABI to get ERC721 Token balance
const minABI = [
    // balanceOf
    {
        "constant": true,
        "inputs": [
            {
                "internalType": "address",
                "name": "owner",
                "type": "address"
            }
        ],
        "name": "balanceOf",
        "outputs": [
            {
                "internalType": "uint256",
                "name": "",
                "type": "uint256"
            }
        ],
        "payable": false,
        "stateMutability": "view",
        "type": "function"
    },
    // name
    {
        "constant": true,
        "inputs": [],
        "name": "name",
        "outputs": [
            {
                "internalType": "string",
                "name": "",
                "type": "string"
            }
        ],
        "payable": false,
        "stateMutability": "view",
        "type": "function"
    }
];

const getBalance = (contractAddress, accountAddress) => {
    let balance;

    // Get ERC721 Token contract instance
    const contract = new web3.eth.Contract(minABI, contractAddress);

    // Call balanceOf function
    contract.methods.balanceOf(accountAddress).call().then((result) => { balance = result });

    return balance;
}

const getName = (contractAddress) => {
    let name;

    // Get ERC721 Token contract instance
    const contract = new web3.eth.Contract(minABI, contractAddress);

    // Call name function
    contract.methods.name().call().then((result) => { name = result });

    return name;
}

module.exports = {
    getName,
    getBalance
}


