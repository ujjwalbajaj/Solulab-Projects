//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./token/ERC20/DeFiXyToken.sol";
import "./libs/access/Ownable.sol";
import "./libs/utils/ReentrancyGuard.sol";

contract DeFiXyStaking is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using Address for address;

    DeFiXyToken dfxToken;

    struct Stake {
        address stakeholder;
        uint256 amount;
        uint256 createStakeTime;
        uint256 rewardClaimTime;
        uint256 reward;
    }

    mapping(address => bool) private _isStakeholder;
    mapping(address => Stake) private _stakes;
    uint256 private _totalStakedTokens;
    uint256 private _totalRewards;
    uint256 private _rewardDeposits;

    string private _platformKey;

    address private _tokenAddress;

    /**
     * @dev Indicates that tokens were staked successfully.
     */
    event Staked(address indexed account, uint256 amount);

    /**
     * @dev Indicates that tokens were unstaked successfully.
     */
    event Unstaked(address indexed account, uint256 amount);

    /**
     * @dev Indicates that rewards were claimed successfully.
     */
    event Claimed(address indexed account, uint256 reward);

    /**
     * @dev Indicates that reward tokens were deposited successfully in the contract.
     */
    event RewardDeposited(uint256 rewardDeposits);

    /**
     * @dev Indicates that reward tokens were withdrawn successfully from contract.
     */
    event RewardWithdrawn(uint256 rewardDeposits);

    /**
     * @dev Initializes the staking platform settings.
     *      Assigns the DFX token address.
     *      Creates an instance of DFX token.
     *
     * @param tokenAddress The address of the DFX token contract.
     *
     * Requirements:
     *
     * - `tokenAddress` should be a contract address only.
     */
    constructor(address tokenAddress, string memory platformKey)
        public
        onlyContract(tokenAddress)
    {
        _rewardDeposits = 0;
        _platformKey = platformKey;
        _tokenAddress = tokenAddress;
        dfxToken = DeFiXyToken(_tokenAddress);
    }

    /**
     * @dev Throws, if called by non-contract address.
     */
    modifier onlyContract(address account) {
        require(
            account.isContract(),
            "DeFiXyStaking: The address does not contain a contract"
        );
        _;
    }

    /**
     * @dev Throws, if called by a zero address.
     */
    modifier realAddress(address addr) {
        require(
            addr != address(0),
            "DeFiXyStaking: The address is zero address"
        );
        _;
    }

    /**
     * @dev Throws, if `amount` is not positive.
     */
    modifier positiveAmount(uint256 amount) {
        require(
            amount > 0,
            "DeFiXyStaking: The amount should be a positive amount"
        );
        _;
    }

    function setPlatformKey(string memory platformKey) external onlyOwner {
        _platformKey = platformKey;
    }

    /**
     * @dev Sets the `stakeholder` address as a stake holder.
     *
     * Requirements:
     *
     * - `stakeholder` address should not be an exisitng stake holder.
     */
    function addStakeholder(address stakeholder)
        internal
        realAddress(stakeholder)
    {
        require(
            !_isStakeholder[stakeholder],
            "DeFiXyStaking: You are already a stakeholder."
        );
        _isStakeholder[stakeholder] = true;
    }

    /**
     * @dev Removes the `stakeholder` address as an exisitng stake holder.
     *
     * Requirements:
     *
     * - `stakeholder` should be an exisitng stake holder.
     */
    function removeStakeholder(address stakeholder)
        internal
        realAddress(stakeholder)
    {
        require(
            _isStakeholder[stakeholder],
            "DeFiXyStaking: You are not a stakeholder."
        );
        _isStakeholder[stakeholder] = false;
    }

    /**
     * @dev Returns the total stakes of all the stakeholders.
     */
    function totalStakes() external view returns (uint256) {
        return _totalStakedTokens;
    }

    /**
     * @dev Returns the total rewards distributed to all the stakeholders.
     */
    function totalRewards() external view returns (uint256) {
        return _totalRewards;
    }

    /**
     * @dev Transfers `stakeAmount` number of tokens from sender address to contract address.
     *      Creates a new stake for the sender with initial set values.
     *      Sets the sender address as a stakeholder.
     *      Increments the total stakes by `stakeAmount`.
     *
     * @param stakeAmount Number of tokens the sender wants to stake.
     *
     * @return true, if token transfer and stake creation successful.
     *
     * Emits an {Transfer} event indicating that tokens have been transferred.
     * Emits an {Staked} event indicating that user stake has been created.
     *
     * Requirements:
     *
     * - `stakeAmount` should be a postive number.
     * - `sender` cannot be a zero address.
     * - `sender` should not be an existing stakeholder.
     * - `sender` balance should be greater than 'stakeAmount'
     */
    function createStake(uint256 stakeAmount, string memory key)
        external
        nonReentrant
        realAddress(msg.sender)
        positiveAmount(stakeAmount)
        returns (bool)
    {
        require(
            !_isStakeholder[msg.sender],
            "DeFiXyStaking: You are already a stakeholder"
        );
        require(
            keccak256(bytes(_platformKey)) == keccak256(bytes(key)),
            "DeFiXyStaking: Bad Request From External"
        );
        uint256 balance = dfxToken.balanceOf(msg.sender);
        require(balance >= stakeAmount, "DeFiXyStaking: Insufficient balance");

        Stake memory newStake = Stake({
            stakeholder: msg.sender,
            amount: stakeAmount,
            createStakeTime: now,
            rewardClaimTime: 0,
            reward: 0
        });

        addStakeholder(msg.sender);
        _stakes[msg.sender] = newStake;
        _totalStakedTokens = _totalStakedTokens.add(stakeAmount);
        emit Staked(msg.sender, stakeAmount);
        bool result = dfxToken.stakeTransfer(
            msg.sender,
            address(this),
            stakeAmount
        );
        return result;
    }

    /**
     * @dev Transfers the staked tokens from contract address to sender address.
     *      Sender address is removed as a stakeholder.
     *      Stake of sender address is removed.
     *      Decrements the total stakes by `stakeAmount` of user.
     *
     * @param key Unique key used to verify the stake of the sender.
     *
     * @return true, if token transfer and stake removal are successful.
     *
     * Emits an {Transfer} event indicating that tokens have been transferred.
     * Emits an {Unstaked} event indicating that user stake has been removed.
     *
     * Requirements:
     *
     * - `sender` cannot be a zero address.
     * - `sender` should be an existing stakeholder.
     * - `key` should match with platformKey.
     */
    function removeStake(string memory key)
        external
        nonReentrant
        realAddress(msg.sender)
        returns (bool)
    {
        require(
            _isStakeholder[msg.sender],
            "DeFiXyStaking: You are not a stakeholder"
        );
        require(
            keccak256(bytes(_platformKey)) == keccak256(bytes(key)),
            "DeFiXyStaking: Bad Request From External"
        );

        Stake storage stake = _stakes[msg.sender];

        uint256 stakeAmount = stake.amount;
        removeStakeholder(msg.sender);
        delete _stakes[msg.sender];
        _totalStakedTokens = _totalStakedTokens.sub(stakeAmount);
        emit Unstaked(msg.sender, stakeAmount);
        bool result = dfxToken.transfer(msg.sender, stakeAmount);
        return result;
    }

    /**
     * @dev Returns the stake details of the `stakeholder`.
     *
     * @param stakeholder Address of which stake details are required.
     *
     * @return number of staked tokens.
     * @return time elapsed, in minutes, since stake creation.
     *
     * Requirements:
     *
     * - `stakeholder` cannot be a zero address.
     * - `stakeholder` should be an existing stakeholder.
     */
    function getStakedUsersDetails(address stakeholder)
        external
        view
        realAddress(stakeholder)
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        require(
            _isStakeholder[msg.sender],
            "DeFiXyStaking: You are not a stakeholder"
        );

        uint256 tokenNum = _stakes[stakeholder].amount;
        uint256 timeElapsed = (now - _stakes[stakeholder].createStakeTime) /
            1 minutes;
        uint256 stakeTime = _stakes[stakeholder].createStakeTime;
        return (tokenNum, timeElapsed, stakeTime);
    }

    /**
     * @dev Transfers the reward tokens from contract address to sender address.
     *      `rewardDeposits` is decremented by `reward` amount.
     *      Stake details of sender address are updated.
     *      `_totalRewards` is incremented by `reward` amount of tokens.
     *
     * @param reward Amount of reward tokens to be claimed.
     *
     * @return true, if reward token transfer is successful.
     *
     * Emits an {Transfer} event indicating that reward tokens have been transferred.
     * Emits an {Claimed} event indicating that stake rewards have been claimed.
     *
     * Requirements:
     *
     * - `sender` cannot be a zero address.
     * - `sender` should be an existing stakeholder.
     * - `reward` should be a postive amount.
     * - `key` should match with  platform key.
     * - `rewardDeposits` should have sufficient tokens for transfer to sender address.
     */
    function claimReward(uint256 reward, string memory key)
        external
        nonReentrant
        realAddress(msg.sender)
        positiveAmount(reward)
        returns (bool)
    {
        require(
            _isStakeholder[msg.sender],
            "DeFiXyStaking: You are not a stakeholder"
        );
        require(
            keccak256(bytes(_platformKey)) == keccak256(bytes(key)),
            "DeFiXyStaking: Something went wrong"
        );
        require(
            _rewardDeposits > reward && _rewardDeposits.sub(reward) >= 0,
            "DeFiXyStaking: Insufficient balance"
        );

        Stake storage stake = _stakes[msg.sender];

        _rewardDeposits = _rewardDeposits.sub(reward);
        stake.reward = stake.reward + reward;
        stake.rewardClaimTime = now;
        _totalRewards = _totalRewards.add(reward);
        stake.createStakeTime = now;
        emit Claimed(msg.sender, reward);
        bool result = dfxToken.transfer(msg.sender, reward);
        return result;
    }

    /**
     * @dev Transfers `amount` of tokens to contract address as deposit.
     *      `rewardDeposits` is incremented by `amount`
     *
     * @param amount The number of tokens to be deposited in contract address.
     *
     * @return true, if token transfer to contract address is successful.
     *
     * Emits an {Transfer} event indicating that tokens have been transferred.
     * Emits an {RewardDeposited} event indicating that `amount` tokens have been added into reward deposits.
     *
     * Requirements:
     *
     * - `sender` cannot be a zero address.
     * - `sender` should be the owner.
     * - `amount` should be a positive amount.
     * - `_tokenAddress` cannot be a zero address.
     */
    function depositReward(uint256 amount)
        external
        onlyOwner
        nonReentrant
        positiveAmount(amount)
        returns (bool)
    {
        require(
            _tokenAddress != address(0),
            "DeFiXyStaking: The Token Contract is not specified"
        );

        _rewardDeposits = _rewardDeposits.add(amount);
        emit RewardDeposited(_rewardDeposits);
        bool result = dfxToken.stakeTransfer(msg.sender, address(this), amount);
        return result;
    }

    /**
     * @dev Withdraws `amount` of tokens from contract address.
     *      `rewardDeposits` is decremented by `amount`
     *
     * @param amount The number of tokens to be withdrawn from contract address.
     *
     * @return true, if token withdrawal from contract address is successful.
     *
     * Emits an {Transfer} event indicating that tokens have been transferred.
     * Emits an {RewardWithdrawn} event indicating that `amount` tokens have been withdrawn from reward deposits.
     *
     * Requirements:
     *
     * - `sender` cannot be a zero address.
     * - `sender` should be the owner.
     * - `amount` should be a positive amount.
     * - `amount` should be less then `rewardDeposits`.
     * - `_tokenAddress` cannot be a zero address.
     */
    function withdrawReward(uint256 amount)
        external
        onlyOwner
        nonReentrant
        positiveAmount(amount)
        returns (bool)
    {
        require(
            _tokenAddress != address(0),
            "DeFiXyStaking: The Token Contract is not specified"
        );
        require(
            _rewardDeposits > amount && _rewardDeposits.sub(amount) >= 0,
            "DeFiXyStaking: Insufficient balance"
        );

        _rewardDeposits = _rewardDeposits.sub(amount);
        emit RewardWithdrawn(_rewardDeposits);
        bool result = dfxToken.transfer(msg.sender, amount);
        return result;
    }

    /**
     * @dev Returns the total rewards deposited in the contract.
     */
    function getRewardDeposits() external view onlyOwner returns (uint256) {
        return _rewardDeposits;
    }
}