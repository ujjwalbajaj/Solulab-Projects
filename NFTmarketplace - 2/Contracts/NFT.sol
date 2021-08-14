pragma solidity ^0.4.24;

import "./ERC721Token.sol";

/**
 * @title Repository of ERC721 NFTs
 * This contract contains the list of nfts registered by users.
 * This contract is used to mint and add tokens (NFT) 
 * to the repository.
 */
 
contract NFT is ERC721Token {
    
    uint256 public tokenCounter;

    /**
    * @dev Created a NFTRepository with a name and symbol
    * @param _name string represents the name of the repository
    * @param _symbol string represents the symbol of the repository
    */
    constructor(string memory _name, string memory _symbol) public ERC721Token(_name, _symbol) {
             tokenCounter = 0;
    }
    
    /**
    * @dev Public function to register a new NFT
    * @dev Call the ERC721Token minter
    * @param _tokenId uint256 represents a specific NFT
    * @param _uri string containing metadata/uri
    */
    function registerNFT(uint256 _tokenId, string memory _uri) public {
        uint256 tokenId = tokenCounter;
        _mint(msg.sender, tokenId);
        addNFTMetadata(tokenId, _uri);
        tokenCounter = tokenCounter + 1;
        emit NFTRegistered(msg.sender, _tokenId);
    }

    /**
    * @dev Public function to add metadata to a NFT
    * @param _tokenId represents a specific NFT
    * @param _uri text which describes the characteristics of a given NFT
    * @return whether the NFT metadata was added to the repository
    */
    function addNFTMetadata(uint256 _tokenId, string memory _uri) public returns(bool){
        _setTokenURI(_tokenId, _uri);
        return true;
    }

    /**
    * @dev Event is triggered if NFT/token is registered
    * @param _by address of the registrar
    * @param _tokenId uint256 represents a specific NFT
    */
    event NFTRegistered(address _by, uint256 _tokenId);

}