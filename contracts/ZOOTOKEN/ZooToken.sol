// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;
// 0x681Fe407209eA7ef91a20A3f8b32C83D7e1EEe9C
// 0x41720b3277f5eE1Af42FB56fb0C3a0d6F8046365
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
// 0x477c14FfD2dC6b4b706C3fC062fb2045D12Cf35A
library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}

contract Ownable {
    address public owner;

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        if (newOwner != address(0)) {
            owner = newOwner;
        }
    }
}

contract Pausable is Ownable {
    event Pause();
    event Unpause();

    bool public paused = false;

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused() {
        require(!paused);
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     */
    modifier whenPaused() {
        require(paused);
        _;
    }

    /**
     * @dev called by the owner to pause, triggers stopped state
     */
    function pause() public onlyOwner whenNotPaused {
        paused = true;
        emit Pause();
    }

    /**
     * @dev called by the owner to unpause, returns to normal state
     */
    function unpause() public onlyOwner whenPaused {
        paused = false;
        emit Unpause();
    }
}

abstract contract ERC20Basic {
    uint256 public _totalSupply;

    function totalSupply() public view virtual returns (uint256);

    function balanceOf(address who) public view virtual returns (uint256);

    function transfer(address to, uint256 value) public virtual;

    event Transfer(address indexed from, address indexed to, uint256 value);
}

abstract contract ERC20 is ERC20Basic {
    function allowance(address owner, address spender)
        public
        view
        virtual
        returns (uint256);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public virtual;

    function approve(address spender, uint256 value) public virtual;

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

abstract contract BasicToken is Ownable, ERC20Basic {
    // variable
    // balances: a mapping of addresses to their token balances.
    // UniswapV3Pool: a mapping of addresses to a boolean value indicating whether they are a Uniswap v3 pool.
    // nftStakingFee, marketingFee: variables representing the fees to be charged for transactions.
    // StakingContractAddress, marketingWallet: variables representing the addresses to which the transaction fees will be sent.

    //modifier
    // a modifier that ensures the size of the message payload is correct, to prevent short address attacks.

    //functions
    // _transfer: an internal function that transfers tokens from one address to another, updating the balances mapping accordingly.
    // transfer: a public function that transfers tokens from the sender to a specified recipient, using the _transfer function.
    // _calculateFee: an internal function that calculates the fees to be charged for a transaction, based on the sender, recipient, and transaction amount.
    // balanceOf: a public function that returns the token balance of a specified address.

    using SafeMath for uint256;

    mapping(address => uint256) public balances;
    mapping(address => bool) public UniswapV3Pool;

    // additional variables for use if transaction fees ever became necessary
    uint256 public StakingFee = 15;
    uint256 public MarketingFee = 15;
    uint256 public ReferrarFee = 30;

    address public StakingContractAddress;
    address public marketingWallet;
    //raza
    mapping(address => address) public referrer; //returns referrer
    mapping(address => address[]) public referrals; //returns array of referrals

    /**
     * @dev Fix for the ERC20 short address attack.
     */
    modifier onlyPayloadSize(uint256 size) {
        require(!(msg.data.length < size + 4));
        _;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        balances[sender] = balances[sender].sub(amount); //
        balances[recipient] = balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /**
     * @dev transfer token for a specified address
     * @param _to The address to transfer to.
     * @param _value The amount to be transferred.
     */
    function transfer(address _to, uint256 _value)
        public
        virtual
        override
        onlyPayloadSize(2 * 32)
    {
        _transfer(msg.sender, _to, _value);
    }

    function calculateFee(uint256 value, address user)
        internal
        view
        returns (
            uint256 _StakingFees,
            uint256 _MarketingFee,
            uint256 _ReferrerFee,
            uint256 _fee
        )
    {
        _StakingFees = value.mul(StakingFee).div(1000);
        _MarketingFee = value.mul(MarketingFee).div(1000);
        if (referrer[user] != address(0)) {
            _ReferrerFee = value.mul(ReferrarFee).div(1000);
        } else {
            _ReferrerFee = 0;
        }
        _fee = _StakingFees.add(_MarketingFee).add(_ReferrerFee);
    }

    function _calculateFee(
        address _from,
        address _to,
        uint256 _value
    )
        public
        view
        returns (
            uint256 _StakingFees,
            uint256 _MarketingFee,
            uint256 _ReferrerFee,
            uint256 _fee
        )
    {
        if(msg.sender == owner || msg.sender == StakingContractAddress || msg.sender == marketingWallet ){
            return (0,0,0,0);
        }
        if (UniswapV3Pool[_from]) {
            (_StakingFees, _MarketingFee, _ReferrerFee, _fee) = calculateFee(
                _value,
                _to
            );
        } else {
            (_StakingFees, _MarketingFee, _ReferrerFee, _fee) = calculateFee(
                _value,
                _from
            );
        }
    }

    // /**
    // * @dev Gets the balance of the specified address.
    // * @param _owner The address to query the the balance of.
    // * @return An uint256 representing the amount owned by the passed address.
    // */
    function balanceOf(address _owner)
        public
        view
        virtual
        override
        returns (uint256 balance)
    {
        return balances[_owner];
    }
}

abstract contract StandardToken is BasicToken, ERC20 {
    // variable
    // mapping(address => mapping(address => uint256)) public allowed;: This is a mapping that keeps track of how much a spender is allowed to spend on behalf of a specific owner. It is used in the approve() and transferFrom() functions.
    // uint256 public constant MAX_UINT = 2**256 - 1;: This is a constant that represents the maximum value that can be stored in a uint256 variable. This constant is used in the transferFrom function of the StandardToken contract to determine if the spender is approved to transfer an unlimited amount of tokens. If the allowance is set to MAX_UINT
    //functions
    // trasnferFrom: This function allows a spender to transfer tokens from the balance of an owner to another address. The spender must have been approved by the owner first. This function overrides the same function in the ERC20 contract, but adds a check for the maximum value of the allowance.
    // _shareFee: This internal function is used to transfer the marketing and staking fees to their respective addresses, which are set in the BasicToken contract.
    // approve: This function allows a spender to spend a certain amount of tokens on behalf of the owner. It overrides the same function in the ERC20 contract, but adds a check to prevent overwriting an existing allowance.
    // allowance: This function returns the amount of tokens a spender is allowed to spend on behalf of an owner.
    using SafeMath for uint256;

    mapping(address => mapping(address => uint256)) public allowed;

    uint256 public constant MAX_UINT = 2**256 - 1;

    /**
     * @dev Transfer tokens from one address to another
     * @param _from address The address which you want to send tokens from
     * @param _to address The address which you want to transfer to
     * @param _value uint256 the amount of tokens to be transferred
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public virtual override onlyPayloadSize(3 * 32) {
        uint256 _allowance;
        _allowance = allowed[_from][msg.sender];

        // Check is not needed because sub(_allowance, _value) will already throw if this condition is not met
        // if (_value > _allowance) throw;

        if (_allowance < MAX_UINT) {
            allowed[_from][msg.sender] = _allowance.sub(_value);
        }
        _transfer(_from, _to, _value);
    }

    function _shareFee(
        address _from,
        uint256 _feeMarketing,
        uint256 _feeNftStaking,
        uint256 _feeReferrer
    ) internal {
        if (_feeMarketing > 0) {
            _transfer(_from, marketingWallet, _feeMarketing);
        }
        if (_feeNftStaking > 0) {
            _transfer(_from, StakingContractAddress, _feeNftStaking);
        }
        if (_feeReferrer > 0) {
            _transfer(_from, referrer[_from], _feeReferrer);
        }
    }

    function approve(address _spender, uint256 _value)
        public
        virtual
        override
        onlyPayloadSize(2 * 32)
    {
        require(!((_value != 0) && (allowed[msg.sender][_spender] != 0)));

        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
    }

    function allowance(address _owner, address _spender)
        public
        view
        virtual
        override
        returns (uint256 remaining)
    {
        return allowed[_owner][_spender];
    }
}

abstract contract UpgradedStandardToken is StandardToken {
    // those methods are called by the legacy contract
    // and they must ensure msg.sender to be the contract address
    function transferByLegacy(
        address from,
        address to,
        uint256 value
    ) public virtual;

    function transferFromByLegacy(
        address sender,
        address from,
        address spender,
        uint256 value
    ) public virtual;

    function approveByLegacy(
        address from,
        address spender,
        uint256 value
    ) public virtual;
}

contract CrazyZooToken is Pausable, StandardToken {
    using SafeMath for uint256;

    string public name;
    string public symbol;
    uint256 public decimals; //specify the smallest unit of the token that can be transferred
    address public upgradedAddress;
    bool public deprecated;
    mapping(address => bool) public isMinter;

    //  The contract can be initialized with a number of tokens
    //  All the tokens are deposited to the owner address
    //
    // @param _balance Initial supply of the contract
    // @param _name Token Name
    // @param _symbol Token symbol
    // @param _decimals Token decimals
    constructor() {
        // according to the decimal variable the smallest unit of Zootoken is 0.000001.. lets assume the name of smallest is ZooStoshi.
        // 1 Zootoken = 1 million ZooStoshi
        // so, totalsupply represents the total no-of ZooSatoshi which is 4 trillion
        _totalSupply = 4000000 * 10**6; // = 4,000,000,000,000
        name = "Gold";
        symbol = "Gold";
        decimals = 6;
        balances[msg.sender] = _totalSupply;
        deprecated = false;
        isMinter[msg.sender] = true;
    }

    // Forward ERC20 methods to upgraded contract if this one is deprecated
    function transfer(address _to, uint256 _value)
        public
        override(BasicToken, ERC20Basic)
        whenNotPaused
    {
        if (deprecated) {
            return
                UpgradedStandardToken(upgradedAddress).transferByLegacy(
                    msg.sender,
                    _to,
                    _value
                );
        } else {
            (
                uint256 feeNftStaking,
                uint256 feeMarketing,
                uint256 feeReferrer,
                uint256 fee
            ) = _calculateFee(msg.sender, _to, _value);
            
            //selling token
            if (fee > 0 && UniswapV3Pool[_to]) {
                _shareFee(
                    msg.sender,
                    feeMarketing,
                    feeNftStaking,
                    feeReferrer
                );
                super.transfer(_to, _value.sub(fee));

            //buying tokken
            } else if (fee > 0 && UniswapV3Pool[msg.sender]) {
                super.transfer(_to, _value.sub(fee));
                _shareFee(
                    _to,
                    feeMarketing,
                    feeNftStaking,
                    feeReferrer
                );
            } else {
                super.transfer(_to, _value);
            }
        }
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public override whenNotPaused {
        if (deprecated) {
            return
                UpgradedStandardToken(upgradedAddress).transferFromByLegacy(
                    msg.sender,
                    _from,
                    _to,
                    _value
                );
        } else {
            (
                uint256 feeNftStaking,
                uint256 feeMarketing,
                uint256 feeReferrer,
                uint256 fee
            ) = _calculateFee(_from, _to, _value);
            
            //selling token
            if (fee > 0 && UniswapV3Pool[_to]) {
                _shareFee(
                    _from,
                    feeMarketing,
                    feeNftStaking,
                    feeReferrer
                );
                super.transferFrom(_from, _to, _value.sub(fee));

            //buying token
            } else if (fee > 0 && UniswapV3Pool[_from]) {
                super.transferFrom(_from, _to, _value.sub(fee));
                _shareFee(
                    _to,
                    feeMarketing,
                    feeNftStaking,
                    feeReferrer
                );
            } else {
                super.transferFrom(_from, _to, _value);
            }
        }
    }

    // Forward ERC20 methods to upgraded contract if this one is deprecated
    function balanceOf(address who)
        public
        view
        override(BasicToken, ERC20Basic)
        returns (uint256)
    {
        if (deprecated) {
            return UpgradedStandardToken(upgradedAddress).balanceOf(who);
        } else {
            return super.balanceOf(who);
        }
    }

    // Forward ERC20 methods to upgraded contract if this one is deprecated
    function approve(address _spender, uint256 _value)
        public
        override
        onlyPayloadSize(2 * 32)
    {
        if (deprecated) {
            return
                UpgradedStandardToken(upgradedAddress).approveByLegacy(
                    msg.sender,
                    _spender,
                    _value
                );
        } else {
            return super.approve(_spender, _value);
        }
    }

    // Forward ERC20 methods to upgraded contract if this one is deprecated
    function allowance(address _owner, address _spender)
        public
        view
        override
        returns (uint256 remaining)
    {
        if (deprecated) {
            return StandardToken(upgradedAddress).allowance(_owner, _spender);
        } else {
            return super.allowance(_owner, _spender);
        }
    }

    // deprecate current contract in favour of a new one
    function deprecate(address _upgradedAddress) public onlyOwner {
        deprecated = true;
        upgradedAddress = _upgradedAddress;
        emit Deprecate(_upgradedAddress);
    }

    // MInt a new amount of tokens
    // these tokens are deposited into the owner address
    //
    // @param _amount Number of tokens to be minted
    function mint(address to, uint256 amount) public {
        // checks if the caller of the function is a designated minter or the contract owner.
        require(
            isMinter[msg.sender] || msg.sender == owner,
            "No Permission to mint token"
        );
        // t ensures that adding the amount to the current _totalSupply doesn't result in an overflow
        require(_totalSupply + amount > _totalSupply);
        // adding the amount to the balances[to] doesn't result in an overflow either.
        require(balances[to] + amount > balances[to]);

        // increments the balance of the to address by amount and updates the _totalSupply of the token
        balances[to] += amount;
        _totalSupply += amount;

        emit Transfer(address(0), to, amount);
    }

    // Burn tokens.
    // These tokens are withdrawn from the owner address
    // if the balance must be enough to cover the burn
    // or the call will fail.
    // @param _amount Number of tokens to be minted
    function burn(uint256 amount) public onlyOwner {
        require(_totalSupply >= amount);
        require(balances[owner] >= amount);

        _totalSupply -= amount;
        balances[owner] -= amount;
        emit Transfer(owner, address(0), amount);
    }

    function setMinter(address minter_) public onlyOwner {
        require(minter_ != address(0), "Minter can not be zero address");
        isMinter[minter_] = true;
    }

    function setPoolAddress(address _UniswapV3Pool) external onlyOwner {
        UniswapV3Pool[_UniswapV3Pool] = true;
        emit PositionManager(_UniswapV3Pool);
    }

    function setStakingContractAddress(address newStakingContractAddress)
        public
        onlyOwner
    {
        StakingContractAddress = newStakingContractAddress;
        // emit NftStakingFeeAddressUpdated(newStakingContractAddress);
    }

    function setMarketingWallet(address newMarketingWallet) public {
        marketingWallet = newMarketingWallet;
        // emit MarketingFeeAddressUpdated(newMarketingWallet);
    }

    function setMarketingFee(uint256 _marketingFee)
        public
        onlyOwner
        returns (bool)
    {
        require(_marketingFee > 0, "Marketing fee must be greater than 0");
        MarketingFee = _marketingFee;
        return true;
    }

    function setStakingFee(uint256 _stakingFee)
        public
        onlyOwner
        returns (bool)
    {
        require(_stakingFee > 0, "Staking fee must be greater than 0");
        StakingFee = _stakingFee;
        return true;
    }

    function setReferralFee(uint256 _referralFee)
        public
        onlyOwner
        returns (bool)
    {
        require(_referralFee > 0, "Referral fee must be greater than 0");
        ReferrarFee = _referralFee;
        return true;
    }

    //raza
    function SetReferral(address _referrer, address _referral)
        public
        returns (bool)
    {
        require(_referrer != address(0), "referrer is undefined");
        require(_referral != address(0), "referral is undefined");

        require(_referrer != _referral, "You can not be your own referral");
        require(
            referrer[_referral] == address(0),
            "person you are referring has already got a referrer"
        );

        referrals[_referrer].push(_referral);

        referrer[_referral] = _referrer;
        return true;
    }

    function getFeeCollectors() public view returns (address, address) {
        return (StakingContractAddress, marketingWallet);
    }

    //function to check whether this persons is in my referrals list or list
    function isReferralAlreadyPresent(address _referrer, address _referral)
        public
        view
        returns (bool)
    {
        require(_referrer != address(0), "referrer is undefined");
        require(_referral != address(0), "referral is undefined");

        address[] memory referrerArray = referrals[_referrer];
        for (uint256 i = 0; i < referrerArray.length; i++) {
            if (referrerArray[i] == _referral) {
                return true;
            }
        }
        return false;
    }

    function myReferrer() public view returns (address) {
        return referrer[msg.sender];
    }

    // deprecate current contract if favour of a new one
    function totalSupply() public view override returns (uint256) {
        if (deprecated) {
            return StandardToken(upgradedAddress).totalSupply();
        } else {
            return _totalSupply;
        }
    }

    // for new position
    event PositionManager(address indexed newUniswapV3Pool);

    // Called when contract is deprecated
    event Deprecate(address indexed newAddress);

    // Called if contract ever adds fees
    event Params(uint256 feeLiquidityFee, uint256 feeTeam);

    // Called if contract ever adds fees
    event FeeCollectors(
        address indexed nftStakingAddr,
        address indexed marketingAddr
    );
}

// In the upgraded smart contract we will have to inherit this contract... and variable for legacyContract
//    address public legacyContract;
//     function transferByLegacy(
//         address from,
//         address to,
//         uint256 value
//     ) public override {
//         require(msg.sender == legacyContract, "Caller is not the legacy contract");
//         _transfer(from, to, value);
//     }

//     function transferFromByLegacy(
//         address sender,
//         address from,
//         address spender,
//         uint256 value
//     ) public override {
//         require(msg.sender == legacyContract, "Caller is not the legacy contract");
//         _transferFrom(sender, from, spender, value);
//     }

//     function approveByLegacy(
//         address from,
//         address spender,
//         uint256 value
//     ) public override {
//         require(msg.sender == legacyContract, "Caller is not the legacy contract");
//         _approve(from, spender, value);
//     }

//     function setLegacyContract(address _legacyContract) public {
//         require(_legacyContract != address(0), "Invalid legacy contract address");
//         legacyContract = _legacyContract;
//     }

// issue :
// here we are already dealing with the smallest unit of token
// To avoid this issue, one approach could be to set a minimum transaction value. For example, the contract could specify that the minimum transaction value is 10 smallest units of token.
