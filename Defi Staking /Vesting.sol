// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../escrow/TokenEscrow.sol";
import "./TokenVestingInfo.sol";

/**
 * @title TokenVesting
 * @dev TokenVesting is a base contract for managing a token vesting,
 */
contract TokenVesting is TokenEscrow {
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    // Address of the ERC20 token
    IERC20 private _token;

    // Counter of vesting rules
    uint256 private _vestingId = 0;
    uint256 private _totalPercentage = 0;

    // Map to track vesting claims
    mapping (address => mapping (uint256 => bool)) private _vestingStatus;

    EnumerableMap.UintToAddressMap private _vestings;

    event VestingAdded(uint256 vestingId_, address tokenVestingInfo);

    constructor(IERC20 token) {
        _token = token;
    }

    function claim(uint256 vestingId_, IERC20 token, address beneficiary) external returns(bool) {
        _preClaim(beneficiary, vestingId_);

        _processClaim(beneficiary, vestingId_, token);

        _updateClaim(beneficiary, vestingId_, token);

        _postClaim(beneficiary, vestingId_, token);

        return true;
    }

    /**
    * @return The totalPercentage
    */
    function totalPercentage() public view returns (uint256) {
        return _totalPercentage;
    }

    /**
    * @return The tokenVestingInfo address. 
    */
    function vestings(uint256 vestingId_) public view returns (address) {
        return _vestings.get(vestingId_);
    }

    /**
    * @return The token address. 
    */
    function getToken() public view returns (IERC20) {
        return _token;
    }

    function getTokenVestingInfoById(uint256 vestingId_) public view returns (TokenVestingInfo) {
        require(_vestings.contains(vestingId_), "TokenVesting: vestingId not found");
        return TokenVestingInfo(_vestings.get(vestingId_));
    }

    function getVestingTimeById(uint256 vestingId_) public view returns (uint256) {
        require(_vestings.contains(vestingId_), "TokenVesting: vestingId not found");
        return getTokenVestingInfoById(vestingId_).at(1);
    }

    function getVestingPercentageById(uint256 vestingId_) public view returns (uint256) {
        require(_vestings.contains(vestingId_), "TokenVesting: vestingId not found");
        return getTokenVestingInfoById(vestingId_).at(2);
    }

    function getVestingStatus(address beneficiary, uint256 vestingId_) public view returns (bool) {
        return _vestingStatus[beneficiary][vestingId_];
    }

    /**
     * @return The current vestingId count. 
     */
    function currentVestingId() public view returns (uint256) {
        return _vestingId;
    }
    
    /**
    * @dev Adds new vesting rule.
    * @param delay The delay after the listing time
    * @param percentage The percentage of the rule
    */
    function addVesting(uint256 vestingId_, uint256 delay, uint256 percentage) external {
        _preAddingVesting(vestingId_, delay, percentage);

        _totalPercentage += percentage;
        require(totalPercentage() <= 100, "TokenVesting: totalPercentage is greater than 100");

        TokenVestingInfo tokenVestingInfo = new TokenVestingInfo(vestingId_, delay, percentage);

        _processAddingVesting(vestingId_, tokenVestingInfo); 
        emit VestingAdded(vestingId_, address(tokenVestingInfo));

        _updateAddingVesting(vestingId_, delay, percentage);
        _postAddingVesting(vestingId_, delay, percentage);
    }

    /**
    * @dev Validation of adding. Use require statements to revert state when conditions are not met.
    * Use `super` in contracts that inherit from Crowdsale to extend their validations.
    * Example from CappedCrowdsale.sol's _preValidatePurchase method:
    *     super._preAddingVesting(vestingId_, delay, percentage);
    * @param vestingId_ Address performing the token purchase
    * @param delay openingtime of the claim
    * @param percentage percentage of the claim
    *
    * Requirements:
    *
    * - `vestingId_` must exist.
    * - `delay` time cannot be 0 .
    * - `percentage` time cannot be 0 
    * - max `percentage` is 100 .
    */
    function _preAddingVesting(uint256 vestingId_, uint256 delay, uint256 percentage) internal virtual view {
        require(!_vestings.contains(vestingId_), "TokenVesting: adding existing vestingId");
        require(delay != 0, "TokenVesting: delay is 0");
        require(percentage != 0, "TokenVesting: percentage is 0");
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
    }

    /**
    * @dev Validation of claim. Use require statements to revert state when conditions are not met.
    * Use `super` in contracts that inherit from Crowdsale to extend their validations.
    * Example from CappedCrowdsale.sol's _preValidatePurchase method:
    *     super._preClaim(vestingId_, delay, percentage);
    * @param vestingId_ Address performing the token purchase
    * Requirements:
    *
    * - `vestingId_` must exist.
    * - getVestingTimeById `vestingId_` must in open time.
    * - _vestingStatus `vestingId_` must be false (not claimed).
    */
    function _preClaim(address beneficiary, uint256 vestingId_)internal virtual view {
        require(_vestings.contains(vestingId_), "TokenVesting: not existing vestingId");
        require(getVestingTimeById(vestingId_) < block.timestamp, "TokenVesting: not open for claim");
        require(getVestingStatus(beneficiary, vestingId_) == false, "TokenVesting: already claimed");
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
    }

    function _processAddingVesting(uint256 vestingId_, TokenVestingInfo tokenVestingInfo) internal virtual {
        _vestings.set(vestingId_, address(tokenVestingInfo));
        _vestingId += 1; 
    }

    function _processClaim(address beneficiary, uint256 vestingId_, IERC20 token) internal virtual {
        uint256 percentage = getVestingPercentageById(vestingId_);
        uint256 amount = tokenBalanceOf(token, beneficiary);
        uint256 newAmount = amount * percentage / 100;
        _vestingStatus[beneficiary][_vestingId] = true;
        super.tokenWithdraw(token, beneficiary, newAmount);
    }

    function _updateAddingVesting(uint256 vestingId_, uint256 delay, uint256 percentage) internal virtual {
        // solhint-disable-previous-line no-empty-blocks
    }

    function _updateClaim( address beneficiary, uint256 vestingId_, IERC20 token) internal virtual {
        // solhint-disable-previous-line no-empty-blocks
    }

    function _postAddingVesting(uint256 vestingId_, uint256 delay, uint256 percentage) internal virtual view {
        // solhint-disable-previous-line no-empty-blocks
    } 

    function _postClaim( address beneficiary, uint256 vestingId_, IERC20 token) internal virtual view {
        // solhint-disable-previous-line no-empty-blocks
    }
}
