// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity >=0.8.0;
pragma abicoder v2;
import "./StartfiMarketPlaceFinance.sol";
 import "./MarketPlaceListing.sol";
import "./MarketPlaceBid.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title NFTKEY MarketPlace contract V1
 * Note: This marketplace contract is collection based. It serves one ERC721 contract only
 * Payment tokens usually is the chain native coin's wrapped token, e.g. WETH, WBNB
 */
contract StartFiMarketPlace is  Ownable,Pausable, MarketPlaceListing, MarketPlaceBid,StartfiMarketPlaceFinance {
  
 /******************************************* decalrations go here ********************************************************* */
 


 /******************************************* constructor goes here ********************************************************* */

    constructor(
          string memory _marketPlaceName,
          address _paymentTokesnAddress,
          address _stakeContract
    )   StartfiMarketPlaceFinance(_marketPlaceName,_paymentTokesnAddress){
       stakeContract=_stakeContract;
    }

  /******************************************* modifiers go here ********************************************************* */

    modifier isOpenAuction(bytes32 listingId) {
        require(  _tokenListings[listingId].releaseTime> block.timestamp && _tokenListings[listingId].status!=ListingStatus.onAuction,"Auction is ended");
        _;
    }
    modifier canFullfillBid(bytes32 listingId) {
        require(  _tokenListings[listingId].releaseTime< block.timestamp && _tokenListings[listingId].status!=ListingStatus.onAuction,"Auction is ended");
        _;
    }
    modifier isOpenForSale(bytes32 listingId) {
        require(_tokenListings[listingId].status==ListingStatus.OnMarket,"Item is not for sale");
        _;
    }
modifier isNotZero(uint256 val) {
    require(val>0,"Zero Value is not allowed");
    _;
}

  /******************************************* read state functions go here ********************************************************* */

  /******************************************* state functions go here ********************************************************* */

// list
    function ListOnMarketplace( address nftAddress,
          uint256 tokenId,
            uint256 listingPrice, uint256 qualifyAmount) external isNotZero(listingPrice) returns (bytes32 listId) {
            uint256 releaseTime = _clacReleaseTime(block.timestamp,delistAfter);
            listId = keccak256(abi.encodePacked(nftAddress,tokenId,_msgSender(),releaseTime));
            // calc qualified ammount
            uint256 listQualifyAmount =_getListingQualAmount(listingPrice);

          // check that sender is qualified 
          require(_getStakeAllowance(_msgSender(), 0)>= listQualifyAmount,"Not enough reserves");
          require( _isTokenApproved(nftAddress,  tokenId) ,"Marketplace is not allowed to transfer your token");

            // transfer token to contract 
          require( _safeNFTTransfer(nftAddress,tokenId,_msgSender(),address(this)),"NFT token couldn't be transfered");

          // update reserved
            _updateUserReserves(_msgSender() ,listQualifyAmount,true);
          // list 
          require(_listOnMarketPlace( listId,nftAddress,_msgSender(),tokenId,listingPrice,releaseTime,qualifyAmount) ,"Couldn't list the item");

        
    }
// create auction
    function createAuction( address nftAddress,
          uint256 tokenId,
            uint256 listingPrice,
            uint256 qualifyAmount,
            bool sellForEnabled,
            uint256 sellFor,
            uint256 duration
            ) external isNotZero(listingPrice) returns (bytes32 listId) {
              require(duration>12 hours,"Auction should be live for more than 12 hours");
            uint256 releaseTime = _clacReleaseTime(block.timestamp,duration);
            listId = keccak256(abi.encodePacked(nftAddress,tokenId,_msgSender(),releaseTime));
            if(sellForEnabled){
              require(sellFor>0,"Zero price is not allowed");
            }
          // check that sender is qualified 
            require( _isTokenApproved(nftAddress,  tokenId) ,"Marketplace is not allowed to transfer your token");

            // transfer token to contract 
          require( _safeNFTTransfer(nftAddress,tokenId,_msgSender(),address(this)),"NFT token couldn't be transfered");

            // update reserved
            // create auction

          require(_creatAuction( listId,nftAddress,_msgSender(),tokenId,listingPrice,   sellForEnabled,sellFor,releaseTime,qualifyAmount) ,"Couldn't list the item");

        
    }
    function bid(bytes32 listingId, address tokenAddress, uint256 tokenId, uint256 bidPrice) 
        external isOpenAuction(listingId) returns (bytes32 bidId){
         bidId = keccak256(abi.encodePacked(listingId,tokenAddress,_msgSender(),tokenId));
         // bid should be more than than the mini and more than the last bid
        address lastbidder= bidToListing[listingId].bidder;
            uint256 qualifyAmount =  _tokenListings[listingId].qualifyAmount;
         if(lastbidder==address(0)){
             require(bidPrice>= _tokenListings[listingId].listingPrice,"bid price must be more than or equal the minimum price");

         }else{
            require(bidPrice>listingBids[listingId][lastbidder].bidPrice,"bid price must be more than the last bid");

                          
         }
         // if this is the bidder first bid, the price will be 0 
       uint256 prevAmount= listingBids[listingId][_msgSender()].bidPrice;
       if(prevAmount==0){
                  // check that he has reserved
         require(_getStakeAllowance(_msgSender(), 0)>= qualifyAmount,"Not enough reserves");
       
         // update user reserves
         // reserve Zero couldn't be at any case
        require( _updateUserReserves(_msgSender() ,qualifyAmount,true)>0,"Reserve Zero is not allowed");
       }
       
         // bid 
         require(_bid( bidId, listingId,  tokenAddress, _msgSender(),   tokenId,   bidPrice),"Couldn't Bid");
     
        // if bid time is less than 15 min, increase by 15 min
        // retuen bid id
    }
    function FullfillBid(bytes32 listingId) 
        external canFullfillBid(listingId) returns (address contractAddress,uint256 tokenId){
         address winnerBidder= bidToListing[listingId].bidder;
         address buyer= _tokenListings[listingId].buyer;
           contractAddress= _tokenListings[listingId]. nftAddress;
           tokenId= _tokenListings[listingId]. tokenId;
        require(winnerBidder==_msgSender(),"Caller is not the winner");
         // if it's new, the price will be 0 
        uint256 bidPrice= listingBids[listingId][winnerBidder].bidPrice;
         // check that contract is allowed to transfer tokens 
         require(_getAllowance(winnerBidder)>= bidPrice,"Marketplace is not allowed to withdraw the required amount of tokens");
        // transfer price 
    
        (address issuer,uint royaltyAmount, uint256 fees, uint256 netPrice) = _getListingFinancialInfo( contractAddress,tokenId, bidPrice) ;
      
       require(_safeTokenTransferFrom(owner(),buyer, fees),"Couldn't transfer token as fees");
       if(issuer!=address(0)){
       require(_safeTokenTransferFrom(issuer,buyer, royaltyAmount),"Couldn't transfer token to issuer");
       }

        // token value could be zero ater taking the roylty share ??? need to ask?
        require(_safeTokenTransferFrom(winnerBidder,buyer, netPrice),"Couldn't transfer token to buyer");
          // trnasfer token
        require( _safeNFTTransfer(contractAddress,tokenId,address(this), winnerBidder),"NFT token couldn't be transfered");
         // update user reserves
         // reserve nigative couldn't be at any case
        require( _updateUserReserves(winnerBidder,_tokenListings[listingId].qualifyAmount,false)>=0,"negative reserve is not allowed");
        listingBids[listingId][_msgSender()].isPurchased=true;
        // finish listing 
        _finalizeListing(listingId,winnerBidder, ListingStatus.Sold);
        // if bid time is less than 15 min, increase by 15 min
        // retuen bid id
    }
// delist
    function deList(bytes32 listingId) 
        external  returns ( address contractAddress,uint256 tokenId){
         ListingStatus status= _tokenListings[listingId].status;
         address owner= _tokenListings[listingId].buyer;
         address seller= _tokenListings[listingId].seller;
           contractAddress= _tokenListings[listingId]. nftAddress;
         uint256 releaseTime= _tokenListings[listingId]. releaseTime;
         uint256 listingPrice= _tokenListings[listingId]. listingPrice;
           tokenId= _tokenListings[listingId]. tokenId;
        require(owner==_msgSender(),"Caller is not the owner");
        require(seller==address(0),"Already bought token");
        require(status==ListingStatus.OnMarket || status==ListingStatus.onAuction,"Already bought or canceled token");
        require((releaseTime<block.timestamp && status==ListingStatus.OnMarket)|| (releaseTime>block.timestamp),"Can't delist");
        uint256 fineAmount ;
         uint256 remaining;
        // if realse time < now , pay 

        if(releaseTime<block.timestamp){
          // if it's not auction ? pay, 
         ( fineAmount ,  remaining)= _getDeListingQualAmount(listingPrice);
              //TODO: deduct the fine from his stake contract 
        }else{
       remaining=  _getListingQualAmount( listingPrice);
        }

        // trnasfer token
        require( _safeNFTTransfer(contractAddress,tokenId,address(this), owner),"NFT token couldn't be transfered");
         // update user reserves
         // reserve nigative couldn't be at any case
        require( _updateUserReserves(_msgSender() ,remaining,false)>=0,"negative reserve is not allowed");
        // finish listing 
         _finalizeListing(listingId,address(0),ListingStatus.Canceled);
        // if bid time is less than 15 min, increase by 15 min
        // retuen bid id
    }


// buynow
    function buyNow(bytes32 listingId, uint256 price) 
        external  returns (address contractAddress,uint256 tokenId){
          bool sellForEnabled= _tokenListings[listingId].sellForEnabled;
         address buyer= _tokenListings[listingId].buyer;
           contractAddress= _tokenListings[listingId]. nftAddress;
           tokenId= _tokenListings[listingId]. tokenId;
         require(price>=_tokenListings[listingId]. listingPrice,"Invalid price");
        require(_tokenListings[listingId].status==ListingStatus.OnMarket || (_tokenListings[listingId].status==ListingStatus.onAuction && sellForEnabled==true && _tokenListings[listingId].releaseTime> block.timestamp ),"Token isnot for sale ");
         // check that contract is allowed to transfer tokens 
         require(_getAllowance(_msgSender())>= price,"Marketplace is not allowed to withdraw the required amount of tokens");
        // transfer price 
    
        (address issuer,uint royaltyAmount, uint256 fees, uint256 netPrice) = _getListingFinancialInfo( contractAddress,tokenId, price) ;
      
       require(_safeTokenTransferFrom(owner(),buyer, fees),"Couldn't transfer token as fees");
       if(issuer!=address(0)){
       require(_safeTokenTransferFrom(issuer,buyer, royaltyAmount),"Couldn't transfer token to issuer");
       }

        // token value could be zero ater taking the roylty share ??? need to ask?
        require(_safeTokenTransferFrom(_msgSender(),buyer, netPrice),"Couldn't transfer token to buyer");
          // trnasfer token
        require( _safeNFTTransfer(contractAddress,tokenId,address(this), _msgSender()),"NFT token couldn't be transfered");
    
        // finish listing 
        _finalizeListing(listingId,_msgSender(), ListingStatus.Sold);
        // if bid time is less than 15 min, increase by 15 min
        // retuen bid id
    }
// dispute aucation
// after auction with winner bid 
// bidder didn't call fullfile within 3 days of auction closing 
// auction owner can call dispute to delist and punish the spam winner bidder
// fine is share between the plateform and the auction owner
    function disputeAuction(bytes32 listingId) 
        external  returns (address contractAddress,uint256 tokenId){
         address winnerBidder= bidToListing[listingId].bidder;
         address buyer= _tokenListings[listingId].buyer;
           contractAddress= _tokenListings[listingId]. nftAddress;
           tokenId= _tokenListings[listingId]. tokenId;
         require(winnerBidder!=address(0) && _tokenListings[listingId]. releaseTime>=block.timestamp,"No bids or still running auction");
       require(buyer==_msgSender(),"Caller is not the owner");
      require(!listingBids[listingId][winnerBidder].isPurchased,"Already purchased");
          // call staking contract to deduct 
          // trnasfer token
        require( _safeNFTTransfer(contractAddress,tokenId,address(this),buyer),"NFT token couldn't be transfered");
    
        // finish listing 
         _finalizeListing(listingId,address(0),ListingStatus.Canceled);
        // if bid time is less than 15 min, increase by 15 min
        // retuen bid id
    }
}