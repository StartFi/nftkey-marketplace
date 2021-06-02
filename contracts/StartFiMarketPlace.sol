// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity >=0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "./interface/INFTKEYMarketPlaceV1.sol";

/**
 * @title NFTKEY MarketPlace contract V1
 * Note: This marketplace contract is collection based. It serves one ERC721 contract only
 * Payment tokens usually is the chain native coin's wrapped token, e.g. WETH, WBNB
 */
contract StartfiMarketPlace is INFTKEYMarketPlaceV1, Ownable, ReentrancyGuard,ERC721Holder {
    using SafeMath for uint256;
    using Address for address;
     using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;


    constructor(
        string memory marketPlaceName_,
        address _erc721Address,
        address _paymentTokenAddress
    ) public {
        _marketPlaceName = marketPlaceName_;
        _erc721 = IERC721(_erc721Address);
        _paymentToken = IERC20(_paymentTokenAddress);
    }

    string private _marketPlaceName;
    IERC721 private immutable _erc721;
    IERC20 private immutable _paymentToken;

    bool private _isListingAndBidEnabled = true;
    uint8 private _feeFraction = 1;
    uint8 private _feeBase = 100;
    uint256 private _actionTimeOutRangeMin = 86400; // 24 hours
    uint256 private _actionTimeOutRangeMax = 31536000; // One year - This can extend by owner is contract is working smoothly

    mapping(uint256 => Listing) private _tokenListings;
    EnumerableSet.UintSet private _tokenIdWithListing;

    mapping(uint256 => mapping(address=>Bid)) private _tokenBids;
    EnumerableSet.UintSet private _tokenIdWithBid;
//
    EnumerableSet.AddressSet private _emptyBidders; // Help initiate TokenBid struct


    /**
     * @dev only if listing and bid is enabled
     * This is to help contract migration in case of upgrade or bug
     */
    modifier onlyMarketplaceOpen() {
        require(_isListingAndBidEnabled, "Listing and bid are not enabled");
        _;
    }

    /**
     * @dev only if the entered timestamp is within the allowed range
     * This helps to not list or bid for too short or too long period of time
     */
    modifier onlyAllowedExpireTimestamp(uint256 expireTimestamp) {
        require(
            expireTimestamp.sub(block.timestamp) >= _actionTimeOutRangeMin,
            "Please enter a longer period of time"
        );
        require(
            expireTimestamp.sub(block.timestamp) <= _actionTimeOutRangeMax,
            "Please enter a shorter period of time"
        );
        _;
    }

    /**
     * @dev check if the account is the owner of this erc721 token
     */
    function _isTokenOwner(uint256 tokenId, address account) private view returns (bool) {
        try _erc721.ownerOf(tokenId) returns (address tokenOwner) {
            return tokenOwner == account;
        } catch {
            return false;
        }
    }

    /**
     * @dev check if this contract has approved to transfer this erc721 token
     */
    function _isTokenApproved(uint256 tokenId) private view returns (bool) {
        try _erc721.getApproved(tokenId) returns (address tokenOperator) {
            return tokenOperator == address(this);
        } catch {
            return false;
        }
    }

    /**
     * @dev check if this contract has approved to all of this owner's erc721 tokens
     */
    function _isAllTokenApproved(address owner) private view returns (bool) {
        return _erc721.isApprovedForAll(owner, address(this));
    }

    /**
     * @dev See {INFTKEYMarketPlaceV1-tokenAddress}.
     */
    function tokenAddress() external view override returns (address) {
        return address(_erc721);
    }

    /**
     * @dev See {INFTKEYMarketPlaceV1-paymentTokenAddress}.
     */
    function paymentTokenAddress() external view override returns (address) {
        return address(_paymentToken);
    }

    /**
     * @dev Check if a listing is valid or not
     * The seller must be the owner
     * The seller must have give this contract allowance
     * The sell price must be more than 0
     * The listing mustn't be expired
     */
    function _isListingValid(Listing memory listing) private view returns (bool) {
        if (
            _isTokenOwner(listing.tokenId, listing.seller) &&
            (_isTokenApproved(listing.tokenId) || _isAllTokenApproved(listing.seller)) &&
            listing.listingPrice > 0 &&
            listing.expireTimestamp > block.timestamp
        ) {
            return true;
        }
    }

    /**
     * @dev See {INFTKEYMarketPlaceV1-getTokenListing}.
     */
    function getTokenListing(uint256 tokenId) public view override returns (Listing memory) {
        Listing memory listing = _tokenListings[tokenId];
        if (_isListingValid(listing)) {
            return listing;
        }
    }

    /**
     * @dev See {INFTKEYMarketPlaceV1-getTokenListings}.
     */
    function getTokenListings(uint256 from, uint256 size)
        public
        view
        override
        returns (Listing[] memory)
    {
        if (from < _tokenIdWithListing.length() && size > 0) {
            uint256 querySize = size;
            if ((from + size) > _tokenIdWithListing.length()) {
                querySize = _tokenIdWithListing.length() - from;
            }
            Listing[] memory listings = new Listing[](querySize);
            for (uint256 i = 0; i < querySize; i++) {
                Listing memory listing = _tokenListings[_tokenIdWithListing.at(i + from)];
                if (_isListingValid(listing)) {
                    listings[i] = listing;
                }
            }
            return listings;
        }
    }

    /**
     * @dev See {INFTKEYMarketPlaceV1-getAllTokenListings}.
     */
    function getAllTokenListings() external view override returns (Listing[] memory) {
        return getTokenListings(0, _tokenIdWithListing.length());
    }

    /**
     * @dev Check if an bid is valid or not
     * Bidder must not be the owner
     * Bidder must give the contract allowance same or more than bid price
     * Bid price must > 0
     * Bid mustn't been expired
     */
    function _isBidValid(Bid memory bid) private view returns (bool) {
        if (
            !_isTokenOwner(bid.tokenId, bid.bidder) &&
            _paymentToken.allowance(bid.bidder, address(this)) >= bid.bidPrice &&
            bid.bidPrice > 0 &&
            bid.expireTimestamp > block.timestamp
        ) {
            return true;
        }
    }

    /**
     * @dev See {INFTKEYMarketPlaceV1-getBidderTokenBid}.
     */
    function getBidderTokenBid(uint256 tokenId, address bidder)
        public
        view
        override
        returns (Bid memory)
    {
        Bid memory bid = _tokenBids[tokenId][bidder];
        if (_isBidValid(bid)) {
            return bid;
        }
    }

  
    



    /**
     * @dev delist a token - remove token id record and remove listing from mapping
     * @param tokenId erc721 token Id
     */
    function _delistToken(uint256 tokenId) private {
        if (_tokenIdWithListing.contains(tokenId)) {
            delete _tokenListings[tokenId];
            _tokenIdWithListing.remove(tokenId);
        }
    }

    /**
     * @dev remove a bid of a bidder
     * @param tokenId erc721 token Id
     * @param bidder bidder address
     */
    function _removeBidOfBidder(uint256 tokenId, address bidder) private {
        if (_tokenBids[tokenId][bidder].bidder!=address(0)) {
            // Step 1: delete the bid and the address
            delete _tokenBids[tokenId][bidder];
        }
    }

    /**
     * @dev See {INFTKEYMarketPlaceV1-listToken}.
     * People can only list if listing is allowed
     * The timestamp set needs to be in the allowed range
     * Only token owner can list token
     * Price must be higher than 0
     * This contract must be approved to transfer this token
     */
    function listToken(
        uint256 tokenId,
        uint256 value,
        uint256 expireTimestamp
    ) external override onlyMarketplaceOpen onlyAllowedExpireTimestamp(expireTimestamp) {
        require(value > 0, "Please list for more than 0 or use the transfer function");
        require(_isTokenOwner(tokenId, msg.sender), "Only token owner can list token");
        require(
            _isTokenApproved(tokenId) || _isAllTokenApproved(msg.sender),
            "This token is not allowed to transfer by this contract"
        );

        _tokenListings[tokenId] = Listing(tokenId, value, msg.sender, expireTimestamp);
        _tokenIdWithListing.add(tokenId);

        emit TokenListed(tokenId, msg.sender, value);
    }

    /**
     * @dev See {INFTKEYMarketPlaceV1-delistToken}.
     * msg.sender must be the seller of the listing record
     */
    function delistToken(uint256 tokenId) external override {
        require(_tokenListings[tokenId].seller == msg.sender, "Only token seller can delist token");
        emit TokenDelisted(tokenId, _tokenListings[tokenId].seller);
        _delistToken(tokenId);
    }

    /**
     * @dev See {INFTKEYMarketPlaceV1-buyToken}.
     * Must have a valid listing
     * msg.sender must not the owner of token
     * token payment allowed must be at least sell price plus fees
     */


     
    // function buyToken(uint256 tokenId) external payable override nonReentrant {
    //     Listing memory listing = getTokenListing(tokenId); // Get valid listing
    //     require(listing.seller != address(0), "Token is not for sale"); // Listing not valid
    //     require(!_isTokenOwner(tokenId, msg.sender), "Token owner can't buy their own token");

    //     uint256 fees = listing.listingPrice.mul(_feeFraction).div(_feeBase);
    //     require(
    //          _paymentToken.allowance(msg.sender, address(this)) >= listing.listingPrice .add( fees),
    //         "The value send is below sale price plus fees"
    //     );

    //     // Send value to token seller and fees to contract owner
    //     uint256 valueWithoutFees =  _paymentToken.allowance(msg.sender, address(this)).sub(fees);
    //     _paymentToken.safeTransferFrom( msg.sender,listing.seller, valueWithoutFees);
    //     _paymentToken.safeTransferFrom( msg.sender, owner(), fees);
    
    //     // Send token to buyer
    //     emit TokenBought(tokenId, listing.seller, msg.sender, msg.value, valueWithoutFees, fees);
    //     _erc721.safeTransferFrom(listing.seller, msg.sender, tokenId);

    //     // Remove token listing
    //     _delistToken(tokenId);
    //     _removeBidOfBidder(tokenId, msg.sender);
    // }

    /**
     * @dev See {INFTKEYMarketPlaceV1-enterBidForToken}.
     * People can only enter bid if bid is allowed
     * The timestamp set needs to be in the allowed range
     * bid price > 0
     * must not be token owner
     * must allow this contract to spend enough payment token
     */
    function enterBidForToken(
        uint256 tokenId,
        uint256 bidPrice,
        uint256 expireTimestamp
    ) external override onlyMarketplaceOpen onlyAllowedExpireTimestamp(expireTimestamp) {
        require(bidPrice > 0, "Please bid for more than 0");
        require(!_isTokenOwner(tokenId, msg.sender), "This Token belongs to this address");
        require(
            _paymentToken.allowance(msg.sender, address(this)) >= bidPrice,
            "Need to have enough token holding to bid on this token"
        );

        Bid memory bid = Bid(tokenId, bidPrice, msg.sender, expireTimestamp);

        // if no bids of this token add a entry to both records _tokenIdWithBid and _tokenBids
        if (!_tokenIdWithBid.contains(tokenId)) {
            _tokenIdWithBid.add(tokenId);
        }

         _tokenBids[tokenId][msg.sender] = bid;

        emit TokenBidEntered(tokenId, msg.sender, bidPrice);
    }

    /**
     * @dev See {INFTKEYMarketPlaceV1-withdrawBidForToken}.
     * There must be a bid exists
     * remove this bid record
     */
    function withdrawBidForToken(uint256 tokenId) external override {
        Bid memory bid = _tokenBids[tokenId][msg.sender];
        require(bid.bidder == msg.sender, "This address doesn't have bid on this token");

        emit TokenBidWithdrawn(tokenId, bid.bidder, bid.bidPrice);
        _removeBidOfBidder(tokenId, msg.sender);
    }

    /**
     * @dev See {INFTKEYMarketPlaceV1-acceptBidForToken}.
     * Must be owner of this token
     * Must have approved this contract to transfer token
     * Must have a valid existing bid that matches the bidder address
     */
    function acceptBidForToken(uint256 tokenId, address bidder) external override nonReentrant {
        require(_isTokenOwner(tokenId, msg.sender), "Only token owner can accept bid of token");
        require(
            _isTokenApproved(tokenId) || _isAllTokenApproved(msg.sender),
            "The token is not approved to transfer by the contract"
        );

        Bid memory existingBid = getBidderTokenBid(tokenId, bidder);
        require(
            existingBid.bidPrice > 0 && existingBid.bidder == bidder,
            "This token doesn't have a matching bid"
        );

        uint256 fees = existingBid.bidPrice.mul(_feeFraction).div(_feeBase + _feeFraction);
        uint256 tokenValue = existingBid.bidPrice.sub(fees);

        _paymentToken.safeTransferFrom( existingBid.bidder, msg.sender, tokenValue);
        _paymentToken.safeTransferFrom( existingBid.bidder, owner(), fees);

        _erc721.safeTransferFrom(msg.sender, existingBid.bidder, tokenId);

        emit TokenBidAccepted(
            tokenId,
            msg.sender,
            existingBid.bidder,
            existingBid.bidPrice,
            tokenValue,
            fees
        );

        // Remove token listing
        _delistToken(tokenId);
        _removeBidOfBidder(tokenId, existingBid.bidder);
    }

    /**
     * @dev See {INFTKEYMarketPlaceV1-getInvalidListingCount}.
     */
    function getInvalidListingCount() external view override returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < _tokenIdWithListing.length(); i++) {
            if (!_isListingValid(_tokenListings[_tokenIdWithListing.at(i)])) {
                count = count.add(1);
            }
        }
        return count;
    }

 

  

   

    /**
     * @dev See {INFTKEYMarketPlaceV1-marketPlaceName}.
     */
    function marketPlaceName() external view override returns (string memory) {
        return _marketPlaceName;
    }

    /**
     * @dev See {INFTKEYMarketPlaceV1-isListingAndBidEnabled}.
     */
    function isListingAndBidEnabled() external view override returns (bool) {
        return _isListingAndBidEnabled;
    }

    /**
     * @dev Enable to disable Bids and Listing
     */
    function changeMarketplaceStatus(bool enabled) external onlyOwner {
        _isListingAndBidEnabled = enabled;
    }

    /**
     * @dev See {INFTKEYMarketPlaceV1-actionTimeOutRangeMin}.
     */
    function actionTimeOutRangeMin() external view override returns (uint256) {
        return _actionTimeOutRangeMin;
    }

    /**
     * @dev See {INFTKEYMarketPlaceV1-actionTimeOutRangeMax}.
     */
    function actionTimeOutRangeMax() external view override returns (uint256) {
        return _actionTimeOutRangeMax;
    }

    /**
     * @dev Change minimum listing and bid time range
     */
    function changeMinActionTimeLimit(uint256 timeInSec) external onlyOwner {
        _actionTimeOutRangeMin = timeInSec;
    }

    /**
     * @dev Change maximum listing and bid time range
     */
    function changeMaxActionTimeLimit(uint256 timeInSec) external onlyOwner {
        _actionTimeOutRangeMax = timeInSec;
    }

    /**
     * @dev See {INFTKEYMarketPlaceV1-serviceFee}.
     */
    function serviceFee() external view override returns (uint8, uint8) {
        return (_feeFraction, _feeBase);
    }

    /**
     * @dev Change withdrawal fee percentage.
     * If 1%, then input (1,100)
     * If 0.5%, then input (5,1000)
     * @param feeFraction_ Fraction of withdrawal fee based on feeBase_
     * @param feeBase_ Fraction of withdrawal fee base
     */
    function changeSeriveFee(uint8 feeFraction_, uint8 feeBase_) external onlyOwner {
        require(feeFraction_ <= feeBase_, "Fee fraction exceeded base.");
        uint256 percentage = (feeFraction_ * 1000) / feeBase_;
        require(percentage <= 25, "Attempt to set percentage higher than 2.5%.");

        _feeFraction = feeFraction_;
        _feeBase = feeBase_;
    }
}
