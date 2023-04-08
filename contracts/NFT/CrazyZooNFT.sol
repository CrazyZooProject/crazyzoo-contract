// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "hardhat/console.sol";

interface IZooToken {
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external;

    function mint(address to, uint256 amount) external;

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external;

    function transfer(address to, uint256 amount) external;

    function balanceOf(address account) external view returns (uint256);

    function totalSupply() external view returns (uint256);
}

contract CrazyZooNFT is ERC721, ERC721Burnable, AccessControl {

    using Strings for uint256;


    uint256 public lemurMinId = 1;
    uint256 public lemurMaxId = 2222;

    uint256 public rhinoMinId = 2223;
    uint256 public rhinoMaxId = 4444;

    uint256 public gorillaMinId = 4445;
    uint256 public gorillaMaxId = 6666;

    uint256 public lemurIdCounter = lemurMinId;
    uint256 public rhinoIdCounter = rhinoMinId;
    uint256 public gorillaIdCounter = gorillaMinId;

    uint256 public decimal;

    uint256 public lemurMintFee;
    uint256 public rhinoMintFee;
    uint256 public gorillaMintFee;

    IZooToken public ZooToken;
    address public feeCollector;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    bool public chargeFeeOnMint = true;
    bool public directMintEnabled = false;

    string public baseURI;
    mapping(uint256 => string) public cids;

    event NewFees(
        uint256 indexed newLemurFee,
        uint256 indexed newRhinoFee,
        uint256 indexed newGorillaFee
    );
    event NewZooToken(address indexed feeAddress);
    event DirectMinting(bool indexed enabled);
    event FeeStatusUpdated(bool indexed newStatus);
    event NewFeeCollector(address indexed newFeeCollector);
    event NewCID(uint256 indexed index, string indexed newCid);
    event NewDecimal(uint256 indexed _decimal);
    event TransferFee(address indexed sender,address indexed feeCollector,uint256 indexed fee);
    event mint(address indexed to, uint256 indexed currentId);

    constructor(
    ) ERC721("Crazy Zoo NFT", "CZN"){
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    function setRange(uint256 min, uint256 diff) public returns (bool) {
        require(min > 0, "min should be greater than 0");
        require(
            diff > min,
            "number of nfts in a single class should be greater than minimum"
        );
        lemurMinId = min;
        lemurMaxId = diff;

        rhinoMinId = lemurMaxId + 1;
        rhinoMaxId = diff * 2;

        gorillaMinId = rhinoMaxId + 1;
        gorillaMaxId = diff * 3;

        return true;
    }

    function setFees(
        uint256 _lemurFee,
        uint256 _rhinoFee,
        uint256 _gorillaFee
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            _lemurFee != 0 && _rhinoFee != 0 && _gorillaFee != 0,
            "Fee Can Not Be Zero"
        );
        lemurMintFee = _lemurFee * 1e18;
        rhinoMintFee = _rhinoFee * 1e18;
        gorillaMintFee = _gorillaFee * 1e18;

        emit NewFees(_lemurFee, _rhinoFee, _gorillaFee);
    }

    function setDecimal(uint256 _decimal) external
        onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_decimal >= 10, "should be atleast 1 decimal");
        decimal = _decimal;
        emit NewDecimal(_decimal);
    }

    function setZooToken(address newToken)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(newToken != address(0), "Address Can Not Be Zero Address");
        ZooToken = IZooToken(newToken);
        emit NewZooToken(newToken);
    }

    function setDirectMinting(bool setValue)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        directMintEnabled = setValue;
        emit DirectMinting(setValue);
    }

    function changeMintFeeStatus() external onlyRole(DEFAULT_ADMIN_ROLE) {
        chargeFeeOnMint = !chargeFeeOnMint;
        emit FeeStatusUpdated(chargeFeeOnMint);
    }

    function setFeeCollector(address _newCollector)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            _newCollector != address(0),
            "Collector Can Not Be Zero Address"
        );
        feeCollector = _newCollector;
        emit NewFeeCollector(_newCollector);
    }

    function setBaseURI(string memory _uri)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        baseURI = _uri;
    }

    function setCid(uint256 index, string memory _cid)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(index > 0 && index < 4, "Invalid CID Index");
        require(bytes(_cid).length > 0, "CID Can Not Be Empty String");
        cids[index] = _cid;

        emit NewCID(index, _cid);
    }

    //approval
    function safeMint(address to, uint256 tokenId) public {
        // checks if the provided tokenId falls within a specific range. purpose of the range is to ensure that only valid tokenIds can be minted.
        checkIdRange(tokenId);
        // checks if the caller of the safeMint function has the MINTER_ROLE role. The hasRole function is provided by the OpenZeppelin Access Control library and checks if a given address has a specific role.
        if (hasRole(MINTER_ROLE, _msgSender())) {
            // to mint the specified tokenId to the provided to address.
            // make sure that the address that receives the token implements the onERC721Received function from the ERC721 standard.
            // helps ensure that the transfer is completed safely and that the receiving contract can handle the incoming token.
            _safeMint(to, tokenId);
        } else {
            // checks if the directMintEnabled flag is set to true. If it is, then the user can mint tokens directly without the MINTER_ROLE role.
            if (directMintEnabled) {
                // checks if the chargeFeeOnMint flag is set to true. If it is, then a fee is charged to the user before the token is minted.
                if (chargeFeeOnMint) {
                    //  calculates the fee to be charged based on the provided tokenId
                    uint256 fee = getFeeForId(tokenId);

                    //usdc transfer
                    // transfer the fee from the user's account to the feeCollector account.
                    emit TransferFee(msg.sender, feeCollector, fee);
                    console.log("feeCollector", feeCollector);
                    console.log("msg.sender", msg.sender);
                    console.log("fee", fee);
                    transferFee(msg.sender, feeCollector, fee);

                    _safeMint(to, tokenId);
                } else {
                    // If the chargeFeeOnMint flag is not set to true, then this code block is executed.
                    _safeMint(to, tokenId);
                }
            } else {
                // If directMintEnabled is set to false, then this code block is executed.
                revert("You Can Not Mint Now");
            }
        }
    }

    function mintLemur(address to) public {
        require(to != address(0), "Can Not Mint To Zero Address");
        require(
            lemurIdCounter < gorillaMaxId,
            "No more Gorillas available for minting"
        );

        uint256 currentId = lemurIdCounter;

        require(
            currentId >= gorillaMinId && currentId <= gorillaMaxId,
            "Gorilla Id Out Of Range"
        );

        safeMint(to, currentId);
        lemurIdCounter = lemurIdCounter + 1;
    }

    function mintRhino(address to) public {
        require(to != address(0), "Can Not Mint To Zero Address");
        require(
            rhinoIdCounter < gorillaMaxId,
            "No more Gorillas available for minting"
        );

        uint256 currentId = rhinoIdCounter;

        require(
            currentId >= gorillaMinId && currentId <= gorillaMaxId,
            "Gorilla Id Out Of Range"
        );

        safeMint(to, currentId);
        rhinoIdCounter = rhinoIdCounter + 1;
    }

    //This function mints a new Gorilla NFT and assigns it to the specified address (to)
    function mintGorilla(address to) public {
        require(to != address(0), "Can Not Mint To Zero Address");
        require(
            gorillaIdCounter < gorillaMaxId,
            "No more Gorillas available for minting"
        );

        uint256 currentId = gorillaIdCounter;

        require(
            currentId >= gorillaMinId && currentId <= gorillaMaxId,
            "Gorilla Id Out Of Range"
        );
        
        // emit mint(to, currentId);
        safeMint(to, currentId);
        gorillaIdCounter = gorillaIdCounter + 1;
        console.log("feeCollector", feeCollector);
        console.log("msg.sender", msg.sender);
    }

    function transferFee(
        address from,
        address to,
        uint256 amount
    ) public {
        // checks if the to address is not zero
        require(to != address(0), "Can Not Transfer To Zero Address");
        // checks if the amount to be transfer is not zero
        if (amount == 0) {
            return;
        }
        //checks if the contract has been approved to spend the required amount of tokens by the from address
        require(
            // ZooToken is likely an address of a token contract that implements the IZooToken interface.
            // By passing ZooToken as an argument to IZooToken, the contract can interact with the IZooToken interface of the token contract at the specified address.
            ZooToken.allowance(from, address(this)) >= amount,
            "Approve Contract For Payment"
        );
        ZooToken.transferFrom(from, to, amount);
    }

    function getIndexForId(uint256 _id) public view returns (uint256) {
        if (_id >= lemurMinId && _id <= lemurMaxId) {
            return 1;
        } else if (_id >= rhinoMinId && _id <= rhinoMaxId) {
            return 2;
        } else if (_id >= gorillaMinId && _id <= gorillaMaxId) {
            return 3;
        } else {
            revert("Id Out Of Range");
        }
    }

    function checkIdRange(uint256 _tokenId) internal view {
        require(
            //  checks if the _tokenId falls within the range of lemurMinId to lemurMaxId.
            (_tokenId >= lemurMinId && _tokenId <= lemurMaxId) ||
                // checks if the _tokenId falls within the range of rhinoMinId to rhinoMaxId.
                (_tokenId >= rhinoMinId && _tokenId <= rhinoMaxId) ||
                // checks if the _tokenId falls within the range of gorillaMinId to gorillaMaxId.
                (_tokenId >= gorillaMinId && _tokenId <= gorillaMaxId),
            "Id Out Of Range"
        );
    }

    // checks if the _id parameter is within the range, then return the corresponding fees
    function getFeeForId(uint256 _id) public view returns (uint256) {
        if (_id >= lemurMinId && _id <= lemurMaxId) {
            return lemurMintFee;
        } else if (_id >= rhinoMinId && _id <= rhinoMaxId) {
            return rhinoMintFee;
        } else if (_id >= gorillaMinId && _id <= gorillaMaxId) {
            return gorillaMintFee;
        } else {
            revert("Id Out Of Range");
        }
    }

    function getCid(uint256 _tokenId) internal view returns (string memory) {
        string memory cid;
        if (_tokenId >= lemurMinId && _tokenId <= lemurMaxId) {
            cid = cids[1];
        } else if (_tokenId >= rhinoMinId && _tokenId <= rhinoMaxId) {
            cid = cids[2];
        } else if (_tokenId >= gorillaMinId && _tokenId <= gorillaMaxId) {
            cid = cids[3];
        }
        return cid;
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        _requireMinted(_tokenId);
        string memory tokenCid = getCid(_tokenId);

        string memory baseURI_ = _baseURI();
        return
            (bytes(baseURI).length > 0 && bytes(tokenCid).length > 0)
                ? string(
                    abi.encodePacked(
                        baseURI_,
                        tokenCid,
                        "/",
                        _tokenId.toString(),
                        ".json"
                    )
                )
                : "";
    }

    // The purpose of the supportsInterface function is to check whether a given interface is supported by the contract. In Solidity, an interface
    //is defined by its unique four-byte identifier, known as an interface ID.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
