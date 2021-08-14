pragma solidity ^0.4.24;

import "./NFT.sol";

import "./SafeMath.sol";
import "./AddressUtils.sol";

import "./MarketPlaceStorage.sol";

contract Marketplace is MarketPlaceStorage{
    using SafeMath for uint256;
    using AddressUtils for address;
    address MarketPlaceOwner;
    
    constructor ( address _owner, uint256 _ownerCutPerMillion) public {
        
        MarketPlaceOwner = _owner;
        
        // Fee init
        setOwnerCutPerMillion(_ownerCutPerMillion);
    
    }
    
    /**
    * @dev Guarantees msg.sender is owner of the Marketplace
    */
    modifier isOwner() {
        require(MarketPlaceOwner == msg.sender);
        _;
    }
  
    /**
    * @dev Sets the publication fee that's charged to users to publish items
    * @param _publicationFee - Fee amount in wei this contract charges to publish an item
    */
    function setPublicationFee(uint256 _publicationFee) external isOwner {
        publicationFeeInWei = _publicationFee;
        emit ChangedPublicationFee(publicationFeeInWei);
    }   
    
    /**
    * @dev Sets the share cut for the owner of the contract that's
    *  charged to the seller on a successful sale
    * @param _ownerCutPerMillion - Share amount, from 0 to 999,999
    */
    function setOwnerCutPerMillion(uint256 _ownerCutPerMillion) public isOwner {
        require(_ownerCutPerMillion < 1000000, "The owner cut should be between 0 and 999,999");

        ownerCutPerMillion = _ownerCutPerMillion;
        emit ChangedOwnerCutPerMillion(ownerCutPerMillion);
    }
    
    /**
    * @dev Creates a new order
    * @param nftAddress - Non fungible registry address
    * @param assetId - ID of the published NFT
    * @param priceInWei - Price in Wei for the supported coin
    * @param expiresAt - Duration of the order (in hours)
    */
    // msg.value - Publication Fee In Wei
    
    function createOrder(
        address nftAddress,
        uint256 assetId,
        uint256 priceInWei,
        uint256 expiresAt
    )
    public payable
    {
        require(nftAddress.isContract(), "The NFT Address should be a contract");
        
        address sender = msg.sender;
        address assetOwner = NFT(nftAddress).ownerOf(assetId);

        require(sender == assetOwner, "Only the owner can create orders");
        require(priceInWei > 0, "Price should be bigger than 0");
        require(
          NFT(nftAddress).getApproved(assetId) == address(this) || NFT(nftAddress).isApprovedForAll(assetOwner, address(this)),
          "The contract is not authorized to manage the asset"
        );
        require(expiresAt > block.timestamp.add(1 minutes), "Publication should be more than 1 minute in the future");

        bytes32 orderId = keccak256(
            abi.encodePacked(
                block.timestamp,
                assetOwner,
                assetId,
                nftAddress,
                priceInWei
            )
        );

        orderByAssetId[nftAddress][assetId] = Order({
            id: orderId,
            seller: address(uint160(assetOwner)),
            nftAddress: nftAddress,
            price: priceInWei,
            expiresAt: expiresAt
        });


        require(publicationFeeInWei == msg.value, "Transfering the publication fee to the Marketplace owner failed");
        MarketPlaceOwner.transfer(msg.value);
        
        emit OrderCreated(
            orderId,
            assetId,
            assetOwner,
            nftAddress,
            priceInWei,
            expiresAt
        );
    }
  
    /**
    * @dev Cancel an already published order
    *  can only be canceled by seller or the contract owner
    * @param nftAddress - Address of the NFT registry
    * @param assetId - ID of the published NFT
    */
    function cancelOrder(address nftAddress, uint256 assetId) public {
        address sender = msg.sender;
        Order memory order = orderByAssetId[nftAddress][assetId];
    
        require(order.id != 0, "Asset not published");
        require(order.seller == sender || sender == MarketPlaceOwner, "Unauthorized user");
    
        bytes32 orderId = order.id;
        address orderSeller = order.seller;
        address orderNftAddress = order.nftAddress;
        delete orderByAssetId[nftAddress][assetId];
    
        emit OrderCancelled(
          orderId,
          assetId,
          orderSeller,
          orderNftAddress
        );
    }
  
    /**
    * @dev Returns the sale share amount for given nft price
    * @param price - Order price
    */ 
    function getSaleShareAmount(uint256 price) public view returns(uint) {
        uint saleShareAmount = 0;
        if (ownerCutPerMillion > 0) {
            // Calculate sale share
            saleShareAmount = price.mul(ownerCutPerMillion).div(1000000);
        }
        return saleShareAmount;
    }
    
    /**
    * @dev Executes the sale for a published NFT
    * @param nftAddress - Address of the NFT registry
    * @param assetId - ID of the published NFT
    * @param price - Order price
    */
    //msg.value - saleShareAmount
    function executeOrder(
        address nftAddress,
        uint256 assetId,
        uint256 price
    )
       public payable
      {
          
        require(nftAddress.isContract(), "The NFT Address should be a contract");  
    
        address sender = msg.sender;
    
        Order memory order = orderByAssetId[nftAddress][assetId];
    
        require(order.id != 0, "Asset not published");
    
        address seller = order.seller;
    
        require(seller != address(0), "Invalid address");
        require(seller != sender, "Unauthorized user");
        require(order.price == price, "The price is not correct");
        require(block.timestamp < order.expiresAt, "The order expired");
        require(seller == NFT(nftAddress).ownerOf(assetId), "The seller is no longer the owner");
        if(ownerCutPerMillion > 0){
            require(getSaleShareAmount(price) == msg.value, "The sale share amount is not correct");        
            MarketPlaceOwner.transfer(msg.value);
        }
        
        bytes32 orderId = order.id;
        delete orderByAssetId[nftAddress][assetId];
        
        // Transfer sale amount to seller
        seller.transfer(price.sub(msg.value));
    
        //Transfer asset owner
        NFT(nftAddress).safeTransferFrom(
          seller,
          sender,
          assetId
        );
        
    
        emit OrderSuccessful(
          orderId,
          assetId,
          seller,
          nftAddress,
          price,
          sender
        );
    
      }  
}
