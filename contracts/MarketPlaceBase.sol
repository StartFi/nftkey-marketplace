// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity >=0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @author Eman Herawy StartFi Team
 *@title base cmarket place contract
 * Note: This marketplace contract is collection based. It serves one ERC721 contract only
 * Payment tokens usually is the chain native coin's wrapped token, e.g. WETH, WBNB
 */
contract MarketPlaceBase is  Ownable,ERC721Holder,Pausable {
    constructor(
        string memory marketPlaceName_,
        
        address _paymentTokenAddress
    ) public {
        _marketPlaceName = marketPlaceName_;
       
        _paymentToken = IERC20(_paymentTokenAddress);
    }

    string internal _marketPlaceName;
     IERC20 internal immutable _paymentToken;
    uint8 internal _feeFraction = 1;
    uint8 internal _feeBase = 100;
      /// @param newFees  the new fees value to be stored 
    /// @return the value of the state variable `_feeFraction`
     function changeFees(uint8 newFees) public onlyOwner whenPaused returns (uint8) {
         // fees is a value between 1-3 %
         require(newFees>=1 && newFees<=3,"fees invalid range");
         _feeFraction=newFees;
         return _feeFraction;
     }
}  

   
