// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 < 0.9.0;

import "hardhat/console.sol";


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

    using SafeMath for uint256;

    mapping(address => uint256) public balances;

    // additional variables for use if transaction fees ever became necessary
    uint256 public StakingFee = 1500000;
    uint256 public MarketingFee = 1500000;
    uint256 public ReferrarFee = 3000000;

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
    using SafeMath for uint256;

    mapping(address => mapping(address => uint256)) public allowed;

    uint256 public constant MAX_UINT = 2**256 - 1;

    event FeeMarketing(uint256 _feeMarketing);
    event FeeNftStaking(uint256 _feeNftStaking);
    event FeeReferrer(uint256 _feeReferrer);

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
    uint256 public multiplier = 1e6;
    address public upgradedAddress;
    bool public deprecated;
    mapping(address => bool) public _isMinter;

    event To(uint8 num);
    event From(uint8 num);
    event None(uint8 num);
    event checkUniswap(address _to);
    event checkFees(uint256 fee);
    event FromUniswap(address _from);
    event toUniswap(address _to);
    event NftStakingFeeAddressUpdated(address newStakingContractAddress);
    event MarketingFeeAddressUpdated(address newStakingContractAddress);
    event ReferralUpdated(address _referrer, address _referral);
    event ReferralFeeUpdated(uint256 _referralFee);
    event StakingFeeUpdated(uint256 _stakingFee);
    event MarketingFeeUpdated(uint256 _marketingFee);
    event MinterUpdated(address _minter);

    //  The contract can be initialized with a number of tokens
    //  All the tokens are deposited to the owner address
    //
    // @param _balance Initial supply of the contract
    // @param _name Token    Name
    // @param _symbol Token symbol
    // @param _decimals Token decimals
    constructor() {
        // according to the decimal variable the smallest unit of Zootoken is 0.000001.. lets assume the name of smallest is ZooStoshi.
        // 1 Zootoken = 1 million ZooStoshi
        // so, totalsupply represents the total no-of ZooSatoshi which is 4 trillion
        _totalSupply = 80000000000 * 10**6; // = 4,000,000,000,000
        name = "friday";
        symbol = "friday";
        decimals = 6;
        balances[msg.sender] = _totalSupply;
        deprecated = false;
        _isMinter[msg.sender] = true;
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
            super.transfer(_to, _value);
            
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
            super.transferFrom(_from, _to, _value);
        }
    }


    function _calculateFee(
        address _user,
        uint256 value
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
        if (
            msg.sender != owner &&
            msg.sender != StakingContractAddress &&
            msg.sender != marketingWallet
        ) {

            _StakingFees = ((StakingFee / 100) * value) / multiplier;
            _MarketingFee = ((MarketingFee / 100) * value) / multiplier;
            if (referrer[_user] != address(0)) {
                _ReferrerFee = ((ReferrarFee / 100) * value) / multiplier;
            } else {
                _ReferrerFee = 0;
            }
            _fee = _StakingFees + _MarketingFee + _ReferrerFee;
        }
    }
    function _shareFee(
        uint256 _feeNftStaking,
        uint256 _feeMarketing,
        uint256 _feeReferrer,
        address _user
    ) public {

        if (_feeMarketing > 0) {
            _transfer(msg.sender, marketingWallet, _feeMarketing);
        }
        if (_feeNftStaking > 0) {
            _transfer(msg.sender, StakingContractAddress, _feeNftStaking);
        }
        if (_feeReferrer > 0) {
            _transfer(msg.sender, referrer[_user], _feeReferrer);
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
        require(_upgradedAddress!= address(0),"upgradedAddress is undefined");
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
            _isMinter[msg.sender] || msg.sender == owner,
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

    function setMinter(address _minter) public onlyOwner {
        require(_minter!= address(0),"you are setting 0 address");
        _isMinter[_minter] = true;
        emit MinterUpdated(_minter);
    }

    

    function setStakingContractAddress(address newStakingContractAddress)
        public
        onlyOwner
    {
        require(newStakingContractAddress != address(0),"you are setting 0 address");
        StakingContractAddress = newStakingContractAddress;
        emit NftStakingFeeAddressUpdated(newStakingContractAddress);
    }

    function setMarketingWallet(address newMarketingWallet) public onlyOwner{
        require(newMarketingWallet != address(0),"you are setting 0 address");
        marketingWallet = newMarketingWallet;
        emit MarketingFeeAddressUpdated(newMarketingWallet);
    }

    function setMarketingFee(uint256 _marketingFee)
        public
        onlyOwner
    {
        require(_marketingFee > 0, "MarketingFee must be greater than 0");
        MarketingFee = _marketingFee;
        emit MarketingFeeUpdated(_marketingFee);
    }

    function setStakingFee(uint256 _stakingFee)
        public
        onlyOwner
    {
        require(_stakingFee > 0, "StakingFee must be greater than 0");
        StakingFee = _stakingFee;
        emit StakingFeeUpdated(_stakingFee);
    }

    function setReferralFee(uint256 _referralFee)
        public
        onlyOwner
    {
        require(_referralFee > 0, "ReferralFee must be greater than 0");
        ReferrarFee = _referralFee;
        emit ReferralFeeUpdated(_referralFee);
    }

    //raza
    function SetReferral(address _referrer, address _referral)
        public
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
        emit ReferralUpdated(_referrer, _referral);
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

    function myReferrer(address _myAddress) public view returns (address) {
        return referrer[_myAddress];
    }
    
    function myReferrals(address _myAddress) public view returns (address[] memory) {
        return referrals[_myAddress];
    }

    function isMinter(address _minter)public view returns(bool){
        return _isMinter[_minter];
    }


    function isDeprecated()public view returns(bool){
        return deprecated;
    }

    function getUpgradedAddress() public view returns (address) {
        return upgradedAddress;
    }
    
    function Decimal() public view returns (uint256) {
        return decimals;
    }

    function getFees() public view returns (uint256 ,uint256 ,uint256 ) {
        return (StakingFee, MarketingFee, ReferrarFee);
    }

    // deprecate current contract if favour of a new one
    function totalSupply() public view override returns (uint256) {
        if (deprecated) {
            return StandardToken(upgradedAddress).totalSupply();
        } else {
            return _totalSupply;
        }
    }


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

