pragma solidity >=0.5.17 < 0.8.1;

//import './UBtoken.sol';
import './ERC721.sol';

contract MarketPlace is ERC721 {
    address public core;
     uint256 public _currentTokenId = 0;
    mapping (uint256 => uint256) public saleableNFT;

    event SET_CORE(address indexed core, address indexed _core);
 constructor(string memory name, string memory symbol) public ERC721(name, symbol) {
        core = msg.sender;
    }

    modifier onlyCore() {
        require(msg.sender == core, "Not Authorized");
        _;
    }

    function setCore(address _core) public onlyCore {
        emit SET_CORE(core, _core);
        core = _core;
    }

    function mintNFT(address _to) public {
      uint256 newTokenId = _getNextTokenId();
        _mint(_to, newTokenId);
        _incrementTokenId();
    }
    
    function _getNextTokenId() private view returns (uint256) {
        return _currentTokenId + 1;
    }

    function _incrementTokenId() private {
        _currentTokenId++;
    }
    
    function BuyNFT(uint256 tokenID) public payable{
        require(_owners[tokenID]==address(this),"The NFT is not saleable");
        require(msg.value==saleableNFT[tokenID],"Enter the correct price");
        safeTransferFrom(address(this),msg.sender,tokenID);
        
    }
    
    function SellNFT(uint256 price, uint256 tokenID) public{
        require(_owners[tokenID] == msg.sender, "You dont own this art");
        approve(address(this),tokenID);
        saleableNFT[tokenID] = price;
        safeTransferFrom(msg.sender, address(this), tokenID);
    }
    
}
