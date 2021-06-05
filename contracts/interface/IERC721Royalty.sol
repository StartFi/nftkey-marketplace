interface IERC721Royalty {
 function royaltyInfo(uint256 _tokenId, uint256 _value) external view returns (address issuer, uint256 _royaltyAmount) ;  
}