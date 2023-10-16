// contracts/token/ERC721/sovereign/SovereignNFT.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "openzeppelin-contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/utils/CountersUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "../../extensions/ITokenCreator.sol";
import "../../extensions/ERC2981Upgradeable.sol";

/**
 * @title SovereignNFT
 * @dev This contract implements an ERC721 compliant NFT (Non-Fungible Token) with additional features.
 */

contract SovereignNFT is
    OwnableUpgradeable,
    ERC165Upgradeable,
    ERC721Upgradeable,
    ITokenCreator,
    ERC721BurnableUpgradeable,
    ERC2981Upgradeable
{
    using SafeMathUpgradeable for uint256;
    using StringsUpgradeable for uint256;
    using CountersUpgradeable for CountersUpgradeable.Counter;

    struct MintConfig {
        uint256 numberOfTokens;
        string baseURI;
        bool lockedMetadata;
    }

    bool public disabled;

    uint256 public maxTokens;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private tokenApprovals;

    // Mapping from addresses that can mint outside of the owner
    mapping(address => bool) private minterAddresses;

    // Counter to keep track of the current token id.
    CountersUpgradeable.Counter private tokenIdCounter;

    // Mint batches for batch minting
    MintConfig private mintConfig;

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    event ContractDisabled(address indexed user);

    event PrepareMint(uint256 indexed numberOfTokens, string baseURI);
    event MetadataLocked(string baseURI);
    event MetadataUpdated(string baseURI);

    /**
     * @dev Contract initialization function.
     */
    function init(
        string calldata _name,
        string calldata _symbol,
        address _creator,
        uint256 _maxTokens
    ) public initializer {
        require(_creator != address(0), "creator cannot be null address");
        _setDefaultRoyaltyPercentage(10);
        disabled = false;
        maxTokens = _maxTokens;

        __Ownable_init();
        __ERC721_init(_name, _symbol);
        __ERC165_init();
        __ERC2981__init();

        _setDefaultRoyaltyReceiver(_creator);

        super.transferOwnership(_creator);
    }
 /**
     * @dev Modifier to check if the caller is the owner of a specific token.
     */
    modifier onlyTokenOwner(uint256 _tokenId) {
        require(ownerOf(_tokenId) == msg.sender, "Must be owner of token.");
        _;
    }
 /**
     * @dev Modifier to check if the contract is not disabled.
     */
    modifier ifNotDisabled() {
        require(!disabled, "Contract must not be disabled.");
        _;
    }

    /**
     * @dev Prepare a minting batch with a specified base URI and number of tokens.
     */
    function prepareMint(
        string calldata _baseURI,
        uint256 _numberOfTokens
    ) public onlyOwner ifNotDisabled {
        _prepareMint(_baseURI, _numberOfTokens);
    }
    /**
     * @dev Prepare a minting batch with a specified base URI and number of tokens.
     */
    function prepareMintWithMinter(
        string calldata _baseURI,
        uint256 _numberOfTokens,
        address _minter
    ) public onlyOwner ifNotDisabled {
        _prepareMint(_baseURI, _numberOfTokens);
        minterAddresses[_minter] = true;
    }

    function mint(address _receiver) external ifNotDisabled {
        require(
            msg.sender == owner() || minterAddresses[msg.sender],
            "lazyMint::only owner can mint"
        );
        _createToken(
            _receiver,
            getDefaultRoyaltyPercentage(),
            getDefaultRoyaltyReceiver()
        );
    }

    function deleteToken(uint256 _tokenId) public onlyTokenOwner(_tokenId) {
        burn(_tokenId);
    }

    function tokenCreator(
        uint256
    ) public view override returns (address payable) {
        return payable(owner());
    }

    function disableContract() public onlyOwner {
        disabled = true;
        emit ContractDisabled(msg.sender);
    }

    function setDefaultRoyaltyReceiver(address _receiver) external onlyOwner {
        _setDefaultRoyaltyReceiver(_receiver);
    }

    function setRoyaltyReceiverForToken(
        address _receiver,
        uint256 _tokenId
    ) external onlyOwner {
        royaltyReceivers[_tokenId] = _receiver;
    }

    function _createToken(
        address _to,
        uint256 _royaltyPercentage,
        address _royaltyReceiver
    ) internal returns (uint256) {
        tokenIdCounter.increment();
        uint256 tokenId = tokenIdCounter.current();
        require(tokenId <= maxTokens, "_createToken::exceeded maxTokens");
        _safeMint(_to, tokenId);
        _setRoyaltyPercentage(tokenId, _royaltyPercentage);
        _setRoyaltyReceiver(tokenId, _royaltyReceiver);
        return tokenId;
    }

    /**
     * @dev Prepare a minting batch with a specified base URI and number of tokens.
     */
    function _prepareMint(
        string calldata _baseURI,
        uint256 _numberOfTokens
    ) internal  {
        require(
            _numberOfTokens <= maxTokens,
            "_prepareMint::exceeded maxTokens"
        );
        require(
            tokenIdCounter.current() == 0,
            "_prepareMint::can only prepare mint with 0 tokens"
        );
        mintConfig = MintConfig(_numberOfTokens, _baseURI, false);
        emit PrepareMint(_numberOfTokens, _baseURI);
    }

    ///////////////////////////////////////////////
    // Write Functions
    ///////////////////////////////////////////////
    function updateBatchMintBaseURI(
        uint256 _batchIndex,
        string calldata _baseURI
    ) external onlyOwner {
        require(
            !mintConfig.lockedMetadata,
            "updateBatchMintBaseURI::metadata is locked"
        );

        mintConfig.baseURI = _baseURI;
    }

    function lockBatchMintBaseURI() external onlyOwner {
        mintConfig.lockedMetadata = true;
    }

    /////////////////////////////////////////////////////////////////////////////
    // Read Functions
    /////////////////////////////////////////////////////////////////////////////
    function getMintConfig()
        public
        view
        returns (uint256 numberOfTokens, string memory baseURI)
    {
        return (mintConfig.numberOfTokens, mintConfig.baseURI);
    }

    /////////////////////////////////////////////////////////////////////////////
    // Overriding Methods to support mint config
    /////////////////////////////////////////////////////////////////////////////
    function tokenURI(
        uint256 _tokenId
    ) public view virtual override returns (string memory) {
        return
            string(
                abi.encodePacked(
                    mintConfig.baseURI,
                    "/",
                    _tokenId.toString(),
                    ".json"
                )
            );
    }

    function totalSupply() public view virtual returns (uint256) {
        return tokenIdCounter.current();
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC165Upgradeable, ERC2981Upgradeable, ERC721Upgradeable)
        returns (bool)
    {
        return
            interfaceId == type(ITokenCreator).interfaceId ||
            ERC165Upgradeable.supportsInterface(interfaceId) ||
            ERC2981Upgradeable.supportsInterface(interfaceId) ||
            ERC721Upgradeable.supportsInterface(interfaceId);
    }
}
