pragma solidity 0.5.11;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../../interfaces/CTokenInterface.sol";
import "../../interfaces/DTokenInterface.sol";
import "../../interfaces/ERC20Interface.sol";


// Send in underlying, receive dTokens, immediately redeem dTokens to cTokens in
// the same block
contract Scenario9Helper {
  using SafeMath for uint256;

  uint256 public underlyingUsedToMint;
  uint256 public dTokensMinted;
  uint256 public cTokensReturnedFromDTokens;
  uint256 public underlyingEquivalentOfCTokensReturned;

  uint256 private constant _SCALING_FACTOR = 1e18;

  // First approve this contract to transfer underlying for the caller.
  function phaseOne(
    CTokenInterface cToken,
    DTokenInterface dToken,
    ERC20Interface underlying
  ) external {
    ERC20Interface dTokenBalance = ERC20Interface(address(dToken));

    // ensure that this address doesn't have any underlying tokens yet.
    require(
      underlying.balanceOf(address(this)) == 0,
      "underlying balance must start at 0."
    );

    // ensure that this address doesn't have any cTokens yet.
    require(
      cToken.balanceOf(address(this)) == 0,
      "cToken balance must start at 0."
    );

    // ensure that this address doesn't have any dTokens yet.
    require(
      dTokenBalance.balanceOf(address(this)) == 0,
      "dToken balance must start at 0."
    );

    // approve cToken to transfer underlying on behalf of this contract.
    require(
      underlying.approve(address(cToken), uint256(-1)), "cToken Approval failed."
    );

    // approve dToken to transfer underlying on behalf of this contract.
    require(
      underlying.approve(address(dToken), uint256(-1)), "dToken Approval failed."
    );

    // get the underlying balance of the caller.
    uint256 underlyingBalance = underlying.balanceOf(msg.sender);

    // ensure that it is at least 1 million.
    require(
      underlyingBalance >= 1000000,
      "Underlying balance is not at least 1 million of lowest-precision units."
    );

    // pull in underlying from caller in multiples of 1 million.
    underlyingUsedToMint = (underlyingBalance / 1000000) * 1000000;
    require(
      underlying.transferFrom(msg.sender, address(this), underlyingUsedToMint),
      "Underlying transfer in failed."
    );

    // mint dTokens using underlying.
    dTokensMinted = dToken.mint(underlyingUsedToMint);
    require(
      dTokensMinted == dTokenBalance.balanceOf(address(this)),
      "dTokens minted do not match returned value."
    );

    // ensure that this address doesn't have any underlying tokens left.
    require(
      underlying.balanceOf(address(this)) == 0,
      "underlying balance in this contract must be 0 after minting."
    );

    // redeem dTokens for cTokens.
    cTokensReturnedFromDTokens = dToken.redeemToCToken(dTokensMinted);
    require(
      cTokensReturnedFromDTokens == cToken.balanceOf(address(this)),
      "cTokens redeemed from dTokens do not match returned value."
    );

    // return the cToken balance to the caller.
    require(
      cToken.transfer(msg.sender, cTokensReturnedFromDTokens),
      "cToken transfer out after dToken redeem failed."
    );

    // ensure that this address doesn't have any cTokens left.
    require(
      cToken.balanceOf(address(this)) == 0,
      "cToken balance must end at 0."
    );

    // ensure that this address doesn't have any dTokens left.
    require(
      dTokenBalance.balanceOf(address(this)) == 0,
      "dToken balance must end at 0."
    );

    // get the equivalent underlying value of the returned cTokens.
    underlyingEquivalentOfCTokensReturned = (
    cTokensReturnedFromDTokens.mul(cToken.exchangeRateCurrent())
    ).div(_SCALING_FACTOR);

    // ensure that underlying returned does not exceed underlying supplied.
    require(
      underlyingUsedToMint >= underlyingEquivalentOfCTokensReturned,
      "Underlying equivalent cTokens returned exceeds underlying supplied."
    );

    // ensure that underlying returned is at least 99.99999% of that supplied.
    require(
      (
      underlyingEquivalentOfCTokensReturned.mul(_SCALING_FACTOR)
      ).div(underlyingUsedToMint) >= _SCALING_FACTOR.sub(1e11),
      "Underlying equivalent cTokens returned < 99.99999% of underlying supplied."
    );
  }
}