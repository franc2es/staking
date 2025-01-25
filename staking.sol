// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract StakingWithPoolAndReward is ReentrancyGuard {
    IERC20 public stakingToken;  // 质押的ERC20代币
    IERC20 public rewardToken;   // 奖励代币
    address deployer;     // 合约部署者

    uint256 public constant lockupPeriod = 5 hours;  // 锁仓期为5个小时

    struct Staker {
        uint256 amountStaked;  // 质押的代币数量
        uint256 stakedAt;      // 用户质押的时间
        uint256 stakeCount;    // 用户质押的次数
        address deployer;     // 合约部署者
    }

    mapping(address => Staker) public stakers;
    mapping(address => mapping(address => uint256)) private _allowances; // 记录授权

    uint256 public totalStaked;  // 总质押量
    uint256 public totalRewards; // 奖励池的总奖励

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);
    event RewardClaimed(address indexed user, uint256 reward);
    event RewardsAdded(uint256 amount); // 新增奖励事件
    event TokensInitialized(IERC20 _stakingToken,IERC20 _rewardToken);

    constructor() {
        deployer = msg.sender; // 记录合约部署者
    }
    
    function initializeTokens(IERC20 _stakingToken, IERC20 _rewardToken) external {
        require(msg.sender == deployer, "Only deployer can initialize tokens");
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        emit TokensInitialized(_stakingToken, _rewardToken); // 触发代币初始化事件
    }

    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot stake 0 tokens");

        Staker storage staker = stakers[msg.sender];

        // 转移质押代币到合约
        stakingToken.transferFrom(msg.sender, address(this), amount);

        uint256 reward = 0;
        if (staker.stakeCount > 0) {
            reward = amount / 100; // 第二次及之后的质押的奖励为1%
        }

        staker.amountStaked += amount;
        staker.stakedAt = block.timestamp;
        staker.stakeCount += 1;
        totalStaked += amount;

        if (reward > 0) {
            require(rewardToken.balanceOf(address(this)) >= reward, "Insufficient reward balance in contract");
            rewardToken.transfer(msg.sender, reward);
            totalRewards -= reward; // 从奖励池中扣除已发放的奖励
            emit RewardClaimed(msg.sender, reward);
        }

        emit Staked(msg.sender, amount);
    }

    function unstake() external nonReentrant {
        Staker storage staker = stakers[msg.sender];
        uint256 amount = staker.amountStaked;
        require(amount > 0, "No staked tokens to unstake");
        require(block.timestamp >= staker.stakedAt + lockupPeriod, "Tokens are locked");

        staker.amountStaked = 0;
        staker.stakedAt = 0;
        totalStaked -= amount;

        stakingToken.transfer(msg.sender, amount);

        emit Unstaked(msg.sender, amount, 0);
    }

    function getStakedAmount(address user) external view returns (uint256) {
        return stakers[user].amountStaked;
    }

    function getStakeCount(address user) external view returns (uint256) {
        return stakers[user].stakeCount;
    }

    function getLockupPeriod() external pure returns (uint256) {
        return lockupPeriod;
    }

    function addRewards(uint256 amount) external {
        require(amount > 0, "Cannot add 0 rewards");
        rewardToken.transferFrom(msg.sender, address(this), amount);
        totalRewards += amount;
        emit RewardsAdded(amount); // 触发奖励新增事件
    }

    function getTotalStaked() external view returns (uint256) {
        return totalStaked;
    }

    function getTotalRewards() external view returns (uint256) {
        return totalRewards;
    }

    // 实现 approve 方法
    function approve(address spender, uint256 amount) external returns (bool) {
        _allowances[msg.sender][spender] = amount;
        return true;
    }

    // 实现 allowance 方法
    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    // 实现 transfer 方法
    function transfer(address to, uint256 amount) external returns (bool) {
        require(amount <= stakingToken.balanceOf(msg.sender), "Insufficient balance");
        stakingToken.transfer(to, amount);
        return true;
    }

    // 实现 transferFrom 方法
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(amount <= _allowances[from][msg.sender], "Allowance exceeded");
        require(amount <= stakingToken.balanceOf(from), "Insufficient balance");

        _allowances[from][msg.sender] -= amount;
        stakingToken.transferFrom(from, to, amount);
        return true;
    }
}
