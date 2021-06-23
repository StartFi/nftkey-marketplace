// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity >=0.8.0;
pragma abicoder v2;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interface/IStartFiStakes.sol";
import "./MarketPlaceBase.sol";


contract StartfiMarketPlaceFinance is MarketPlaceBase {
 /******************************************* decalrations go here ********************************************************* */
    using SafeMath for uint256;
    address internal _paymentToken;
    uint8 internal _feeFraction = 1;
    uint8 internal _feeBase = 100;
    uint256 bidPenaltyPercentage =1;
    uint256 public delistFeesPercentage=1;
    uint256 public listqualifyPercentage=1;
   mapping (address=>uint256) userReserves;
   address public stakeContract;
 /******************************************* constructor goes here ********************************************************* */

  constructor(
                 string memory _name ,
        address _paymentTokesnAddress
    )   MarketPlaceBase(_name){
         
       
        _paymentToken = _paymentTokesnAddress;
    }


  /******************************************* modifiers go here ********************************************************* */



  /******************************************* read state functions go here ********************************************************* */
    
    function _clacReleaseTime(uint256 startTime, uint256 duration) pure internal returns (uint256 releaseTime) {
        releaseTime= startTime.add(duration);        
    }
    function _calcFees(uint256 bidPrice) view internal returns (uint256 fees) {
        fees= bidPrice.mul(_feeFraction).div(_feeBase + _feeFraction);    
    }
    function _getListingQualAmount(uint256 listingPrice) view internal returns (uint256 amount) {
        amount= listingPrice.mul(listqualifyPercentage).div(100 + listqualifyPercentage);    
    }
    function _getDeListingQualAmount(uint256 listingPrice) view internal returns (uint256 fineAmount , uint256 remaining) {
        fineAmount= listingPrice.mul(delistFeesPercentage).div(100 + delistFeesPercentage);    
        remaining =  _getListingQualAmount( listingPrice);
    }
   function _getListingFinancialInfo(address contractAddress,uint256 tokenId, uint256 bidPrice)  view internal returns   (address issuer,uint256 royaltyAmount, uint256 fees, uint256 netPrice) {
             fees = _calcFees(bidPrice);
      netPrice = bidPrice.sub(fees);
          // royalty check
          if(_supportRoyalty(contractAddress)){
               ( issuer, royaltyAmount) =_getRoyaltyInfo( contractAddress,  tokenId, bidPrice);
               if(royaltyAmount>0 && issuer!=address(0)){
                   netPrice= netPrice.sub(royaltyAmount);
               }
          }
      
   }
    function getUserReserved(address user) external  view returns (uint256)  {
        return userReserves[user];
    }
    /// @return the value of the state variable `_feeFraction`
        function getServiceFee() external view returns (uint8) {
        return _feeFraction;
    }
    function _getAllowance(address owner) view internal returns (uint256 ) {
        return IERC20(_paymentToken).allowance( owner, address(this));
    }
    function _getStakeAllowance(address user ,uint256 prevAmount) view internal returns (uint256 ) {
        // user can bid multi time, we want to make sure we don't calc the old bid as sperated bid 
        uint256 userActualReserved= userReserves[user].sub(prevAmount);
        return IStartFiStakes(stakeContract).getReserves( user).sub(userActualReserved);
    }

      /******************************************* state functions go here ********************************************************* */

    function _safeTokenTransfer(address to, uint256 amount) internal returns (bool) {
        return IERC20(_paymentToken). transfer( to,  amount);
    }
    function _safeTokenTransferFrom(address from,address to, uint256 amount) internal returns (bool) {
        return IERC20(_paymentToken). transferFrom(from, to,  amount);
    }
    function _setUserReserves(address user, uint256 newReservedValue) internal returns (bool) {
        userReserves[user]=newReservedValue;
        return true;
    }
    function _updateUserReserves(address user, uint256 newReserves, bool isAddition) internal returns (uint256 _userReserves) {
        _userReserves=  isAddition? userReserves[user].add(newReserves): userReserves[user].sub(newReserves);
        userReserves[user]=_userReserves;
        return _userReserves;
    }
    /// @param newFees  the new fees value to be stored 
    /// @return the value of the state variable `_feeFraction`
     function changeFees(uint8 newFees) internal returns (uint8) {
         // fees is a value between 1-3 %
         require(newFees>=1 && newFees<=3,"fees invalid range");
         _feeFraction=newFees;
         return _feeFraction;
     }
    /// @param _token  the new name to be stored 
     function _changeUtiltiyToken(address _token) internal {
      _paymentToken=_token;  
     }
     function _changeBidPenaltyPercentage(uint256 newPercentage) internal {
 bidPenaltyPercentage =newPercentage;
}
function _changeDelistFeesPerentage(uint256 newPercentage) internal {
 delistFeesPercentage =newPercentage;
}
function _changeListqualifyAmount(uint256 newPercentage) internal {
 listqualifyPercentage =newPercentage;
}

} 