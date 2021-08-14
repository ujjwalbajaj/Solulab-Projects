pragma solidity ^0.4.24;


import "./NFT.sol";

import "./SafeMath.sol";
import "./AddressUtils.sol";

import "./ERC721BidStorage.sol";


contract ERC721Bid is ERC721BidStorage {
    using SafeMath for uint256;
    using AddressUtils for address;
    address BiddingOwner;
    /**
    * @dev Constructor of the contract.
    * @param _owner - address of the owner for the contract
    */
    constructor(address _owner, uint256 _ownerCutPerMillion) public{
	// Set owner
        BiddingOwner = _owner;
        
	// Fee init
        setOwnerCutPerMillion(_ownerCutPerMillion);
    }
    
   /**
    * @dev Guarantees msg.sender is owner of the Marketplace
    */
    modifier isOwner() {
        require(BiddingOwner == msg.sender);
        _;
    }
    
    /**
    * @dev Place a bid for an ERC721 token
    * @notice Tokens can have multiple bids by different users.
    * Users can have only one bid per token.
    * If the user places a bid and has an active bid for that token,
    * the older one will be replaced with the new one.
    * This function would be called by the bidder : Transfer msg.value to contract address
    * @param _tokenAddress - address of the ERC721 token
    * @param _tokenId - uint256 of the token id
    * @param _price - uint256 of the price for the bid
    * @param _duration - uint256 of the duration in seconds for the bid
    */
    function placeBid(
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _price,
        uint256 _duration
    )
    public payable
    {
        require(_tokenAddress.isContract(), "The Token Address should be a contract");

        address sender = msg.sender;

        require(_price > 0, "Price should be bigger than 0");
        require(_price == msg.value);

        _requireBidderBalance(sender, _price);

        require(
            _duration >= MIN_BID_DURATION,
            "The bid should be last longer than a minute"
        );

        require(
            _duration <= MAX_BID_DURATION,
            "The bid can not last longer than 6 months"
        );

        address tokenOwner = NFT(_tokenAddress).ownerOf(_tokenId);
        require(
            tokenOwner != address(0) && tokenOwner != sender,
            "The token should have an owner different from the sender"
        );

        uint256 expiresAt = block.timestamp.add(_duration);

        bytes32 bidId = keccak256(
            abi.encodePacked(
                block.timestamp,
                sender,
                _tokenAddress,
                _tokenId,
                _price,
                _duration
            )
        );

        uint256 bidIndex;

        if (_bidderHasABid(_tokenAddress, _tokenId, sender)) {
            bytes32 oldBidId;
            (bidIndex, oldBidId,,,) = getBidByBidder(_tokenAddress, _tokenId, sender);

            // Delete old bid reference
            delete bidIndexByBidId[oldBidId];
        } else {
            // Use the bid counter to assign the index if there is not an active bid.
            bidIndex = bidCounterByToken[_tokenAddress][_tokenId];
            // Increase bid counter
            bidCounterByToken[_tokenAddress][_tokenId]++;
        }

        // Set bid references
        bidIdByTokenAndBidder[_tokenAddress][_tokenId][sender] = bidId;
        bidIndexByBidId[bidId] = bidIndex;

        // Save Bid
        bidsByToken[_tokenAddress][_tokenId][bidIndex] = Bid({
            id: bidId,
            bidder: sender,
            tokenAddress: _tokenAddress,
            tokenId: _tokenId,
            price: _price,
            expiresAt: expiresAt
        });

        emit BidCreated(
            bidId,
            _tokenAddress,
            _tokenId,
            sender,
            _price,
            expiresAt
        );
    }

    /**
    * @dev Used as the only way to accept a bid.
    * The token owner should send the token to this contract using safeTransferFrom.
    * The last parameter (bytes) should be the bid id.
    * @notice  The ERC721 smart contract calls this function on the recipient
    * after a `safetransfer`. This function MAY throw to revert and reject the
    * transfer. Return of other than the magic value MUST result in the
    * transaction being reverted.
    * Note:
    * Contract address is always the message sender.
    * This method should be seen as 'acceptBid'.
    * It validates that the bid id matches an active bid for the bid token.
    * @param _from The address which previously owned the token
    * @param _tokenId The NFT identifier which is being transferred
    * @param _data Additional data with no specified format
    */

    function onERC721Received(
        address _from,
        address /*_to*/,
        uint256 _tokenId,
        bytes memory _data
    )
        public payable
    {
        bytes32 bidId = _bytesToBytes32(_data);
        uint256 bidIndex = bidIndexByBidId[bidId];

        Bid memory bid = _getBid(msg.sender, _tokenId, bidIndex);

        // Check if the bid is valid.
        require( bid.id == bidId && bid.expiresAt >= block.timestamp,
            "Invalid bid"
        );

        address bidder = bid.bidder;
        uint256 price = bid.price;

        // Check if bidder has funds
        _requireBidderBalance(bidder, price);

        // Delete bid references from contract storage
        delete bidsByToken[msg.sender][_tokenId][bidIndex];
        delete bidIndexByBidId[bidId];
        delete bidIdByTokenAndBidder[msg.sender][_tokenId][bidder];

        // Reset bid counter to invalidate other bids placed for the token
        delete bidCounterByToken[msg.sender][_tokenId];

        // Transfer token to bidder
        NFT(msg.sender).safeTransferFrom(
          address(this),
          bidder,
          _tokenId
        );
        
        uint256 saleShareAmount = 0;
        if (ownerCutPerMillion > 0) {
            // Calculate sale share
            saleShareAmount = price.mul(ownerCutPerMillion).div(ONE_MILLION);
        }

        // tranfer from contract address to _from
        _from.transfer(price.sub(saleShareAmount));

        emit BidAccepted(
            bidId,
            msg.sender,
            _tokenId,
            bidder,
            _from,
            price,
            saleShareAmount
        );

    }

    /**
    * @dev Remove expired bids
    * @param _tokenAddresses - address[] of the ERC721 tokens
    * @param _tokenIds - uint256[] of the token ids
    * @param _bidders - address[] of the bidders
    */
    function removeExpiredBids(address[] memory _tokenAddresses, uint256[] memory _tokenIds, address[] memory _bidders)
    public
    {
        uint256 loopLength = _tokenAddresses.length;

        require(loopLength == _tokenIds.length, "Parameter arrays should have the same length");
        require(loopLength == _bidders.length, "Parameter arrays should have the same length");

        for (uint256 i = 0; i < loopLength; i++) {
            _removeExpiredBid(_tokenAddresses[i], _tokenIds[i], _bidders[i]);
        }
    }

    /**
    * @dev Remove expired bid
    * @param _tokenAddress - address of the ERC721 token
    * @param _tokenId - uint256 of the token id
    * @param _bidder - address of the bidder
    */
    function _removeExpiredBid(address _tokenAddress, uint256 _tokenId, address _bidder)
    internal
    {
        (uint256 bidIndex, bytes32 bidId,,,uint256 expiresAt) = getBidByBidder(
            _tokenAddress,
            _tokenId,
            _bidder
        );

        require(expiresAt < block.timestamp, "The bid to remove should be expired");

        _cancelBid(
            bidIndex,
            bidId,
            _tokenAddress,
            _tokenId,
            _bidder
        );
    }

    /**
    * @dev Cancel a bid for an ERC721 token
    * @param _tokenAddress - address of the ERC721 token
    * @param _tokenId - uint256 of the token id
    */
    function cancelBid(address _tokenAddress, uint256 _tokenId) public {
        
        require(_tokenAddress.isContract(), "The Token Address should be a contract");
        address sender = msg.sender;
        // Get active bid
        (uint256 bidIndex, bytes32 bidId,address bidder,uint256 price,) = getBidByBidder(
            _tokenAddress,
            _tokenId,
            sender
        );
        
        require(bidder == msg.sender, "Only the bid owner can cancel the bid");
        
        _cancelBid(
            bidIndex,
            bidId,
            _tokenAddress,
            _tokenId,
            sender
        );
        
        //withdraw the bid amount
        sender.transfer(price);
    }

    /**
    * @dev Cancel a bid for an ERC721 token
    * @param _bidIndex - uint256 of the index of the bid
    * @param _bidId - bytes32 of the bid id
    * @param _tokenAddress - address of the ERC721 token
    * @param _tokenId - uint256 of the token id
    * @param _bidder - address of the bidder
    */
    function _cancelBid(
        uint256 _bidIndex,
        bytes32 _bidId,
        address _tokenAddress,
        uint256 _tokenId,
        address _bidder
    )
        internal
    {
        // Delete bid references
        delete bidIndexByBidId[_bidId];
        delete bidIdByTokenAndBidder[_tokenAddress][_tokenId][_bidder];

        // Check if the bid is at the end of the mapping
        uint256 lastBidIndex = bidCounterByToken[_tokenAddress][_tokenId].sub(1);
        if (lastBidIndex != _bidIndex) {
            // Move last bid to the removed place
            Bid storage lastBid = bidsByToken[_tokenAddress][_tokenId][lastBidIndex];
            bidsByToken[_tokenAddress][_tokenId][_bidIndex] = lastBid;
            bidIndexByBidId[lastBid.id] = _bidIndex;
        }

        // Delete empty index
        delete bidsByToken[_tokenAddress][_tokenId][lastBidIndex];

        // Decrease bids counter
        bidCounterByToken[_tokenAddress][_tokenId]--;

        // emit BidCancelled event
        emit BidCancelled(
            _bidId,
            _tokenAddress,
            _tokenId,
            _bidder
        );
    }

     /**
    * @dev Check if the bidder has a bid for an specific token.
    * @param _tokenAddress - address of the ERC721 token
    * @param _tokenId - uint256 of the token id
    * @param _bidder - address of the bidder
    * @return bool whether the bidder has an active bid
    */
    function _bidderHasABid(address _tokenAddress, uint256 _tokenId, address _bidder)
        internal
        view
        returns (bool)
    {
        bytes32 bidId = bidIdByTokenAndBidder[_tokenAddress][_tokenId][_bidder];
        uint256 bidIndex = bidIndexByBidId[bidId];
        // Bid index should be inside bounds
        if (bidIndex < bidCounterByToken[_tokenAddress][_tokenId]) {
            Bid memory bid = bidsByToken[_tokenAddress][_tokenId][bidIndex];
            return bid.bidder == _bidder;
        }
        return false;
    }

    /**
    * @dev Get the active bid id and index by a bidder and an specific token.
    * @notice If the bidder has not a valid bid, the transaction will be reverted.
    * @param _tokenAddress - address of the ERC721 token
    * @param _tokenId - uint256 of the token id
    * @param _bidder - address of the bidder
    * @return bidIndex - uint256 of the bid index to be used within bidsByToken mapping
    * @return bidId - bytes32 of the bid id
    * @return bidder - address of the bidder address
    * @return price - uint256 of the bid price
    * @return expiresAt - uint256 of the expiration time
    */
    function getBidByBidder(address _tokenAddress, uint256 _tokenId, address _bidder)
        public
        view
        returns (
            uint256 bidIndex,
            bytes32 bidId,
            address bidder,
            uint256 price,
            uint256 expiresAt
        )
    {
        bidId = bidIdByTokenAndBidder[_tokenAddress][_tokenId][_bidder];
        bidIndex = bidIndexByBidId[bidId];
        (bidId, bidder, price, expiresAt) = getBidByToken(_tokenAddress, _tokenId, bidIndex);
        if (_bidder != bidder) {
            revert("Bidder has not an active bid for this token");
        }
    }

    /**
    * @dev Get an ERC721 token bid by index
    * @param _tokenAddress - address of the ERC721 token
    * @param _tokenId - uint256 of the token id
    * @param _index - uint256 of the index
    * @return bytes32 of the bid id
    * @return address of the bidder address
    * @return uint256 of the bid price
    * @return uint256 of the expiration time
    */
    function getBidByToken(address _tokenAddress, uint256 _tokenId, uint256 _index)
        public
        view
        returns (bytes32, address, uint256, uint256)
    {

        Bid memory bid = _getBid(_tokenAddress, _tokenId, _index);
        return (
            bid.id,
            bid.bidder,
            bid.price,
            bid.expiresAt
        );
    }

    /**
    * @dev Get the active bid id and index by a bidder and an specific token.
    * @notice If the index is not valid, it will revert.
    * @param _tokenAddress - address of the ERC721 token
    * @param _tokenId - uint256 of the index
    * @param _index - uint256 of the index
    * @return Bid
    */
    function _getBid(address _tokenAddress, uint256 _tokenId, uint256 _index)
        internal
        view
        returns (Bid memory)
    {
        require(_index < bidCounterByToken[_tokenAddress][_tokenId], "Invalid index");
        return bidsByToken[_tokenAddress][_tokenId][_index];
    }

    /**
    * @dev Sets the share cut for the owner of the contract that's
    * charged to the seller on a successful sale
    * @param _ownerCutPerMillion - Share amount, from 0 to 999,999
    */
    function setOwnerCutPerMillion(uint256 _ownerCutPerMillion) public isOwner {
        require(_ownerCutPerMillion < ONE_MILLION, "The owner cut should be between 0 and 999,999");

        ownerCutPerMillion = _ownerCutPerMillion;
        emit ChangedOwnerCutPerMillion(ownerCutPerMillion);
    }

    /**
    * @dev Convert bytes to bytes32
    * @param _data - bytes
    * @return bytes32
    */
    function _bytesToBytes32(bytes memory _data) internal pure returns (bytes32) {
        require(_data.length == 32, "The data should be 32 bytes length");

        bytes32 bidId;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            bidId := mload(add(_data, 0x20))
        }
        return bidId;
    }

    /**
    * @dev Check if the bidder has balance and the contract has enough allowance
    * to use bidder MANA on his belhalf
    * @param _bidder - address of bidder
    * @param _amount - uint256 of amount
    */
    function _requireBidderBalance(address _bidder, uint256 _amount) internal view {
        require(
            _bidder.balance >= _amount,
            "Insufficient funds"
        );
    }
}