// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ITreasury {
    function deposit(uint256 amount) external;
}

/// @title ContraNFT — Founding Shareholder NFT (v3.0 — Timelock + Security Hardened)
/// @notice Phase 1: 10,000 USDC mint, 4-chain deployment with adjustable quotas.
///         Funds flow: user → this contract → treasury (auto-forward) → beneficiary.
///         v3.0: 2-step transfer for Treasury/PaymentToken. Emit before external call.
contract ContraNFT is ERC721, Ownable {
    using SafeERC20 for IERC20;

    // ───── Config (Owner-adjustable with timelock) ─────

    /// @notice Payment token (e.g. USDC). 2-step transfer.
    IERC20 public paymentToken;

    /// @notice Mint price, in paymentToken decimals.
    uint256 public mintPrice;

    /// @notice Maximum tokens that can be minted on this chain.
    ///         Adjustable (both directions), minimum = totalMinted.
    uint256 public maxSupply;

    /// @notice Treasury contract address. 2-step transfer.
    address public treasury;

    /// @notice Final beneficiary address — set on Treasury, stored here for reference.
    address public beneficiary;

    /// @notice Base URI for token metadata.  Set by owner.
    string private _contractBaseURI;

    // ───── 2-Step Transfer State ─────

    address public pendingTreasury;
    address public pendingPaymentToken;

    // ───── State ─────

    uint256 public totalMinted;
    bool public paused;

    // ───── Events ─────

    event MintEvent(address indexed minter, uint256 indexed tokenId);
    event Paused();
    event Unpaused();
    event MaxSupplyUpdated(uint256 oldMax, uint256 newMax);
    event MintPriceUpdated(uint256 oldPrice, uint256 newPrice);
    event PaymentTokenNominated(address oldToken, address newToken);
    event PaymentTokenAccepted(address newToken);
    event TreasuryNominated(address oldTreasury, address newTreasury);
    event TreasuryAccepted(address newTreasury);
    event BeneficiaryUpdated(address oldBeneficiary, address newBeneficiary);
    event BaseURIUpdated(string oldBaseURI, string newBaseURI);

    // ───── Errors ─────

    error SoldOut();
    error InsufficientPayment();
    error TransferFailed();
    error BelowTotalMinted(uint256 requested, uint256 totalMinted);
    error IsPaused();
    error PriceNotSet();
    error NotPendingAddress();
    error ZeroAddress();

    // ───── Constructor ─────

    constructor(
        string memory _name,
        string memory _symbol,
        address _paymentToken,
        uint256 _mintPrice,
        uint256 _maxSupply,
        address _treasury,
        address _beneficiary
    ) ERC721(_name, _symbol) Ownable(msg.sender) {
        if (_paymentToken == address(0)) revert ZeroAddress();
        if (_mintPrice == 0) revert PriceNotSet();
        if (_treasury == address(0)) revert ZeroAddress();
        if (_beneficiary == address(0)) revert ZeroAddress();
        paymentToken = IERC20(_paymentToken);
        mintPrice = _mintPrice;
        maxSupply = _maxSupply;
        treasury = _treasury;
        beneficiary = _beneficiary;
    }

    // ───── Mint ─────

    /// @notice Mint a founding shareholder NFT.
    ///         1. Transfers mintPrice tokens from minter to treasury.
    ///         2. Treasury auto-forwards to beneficiary.
    ///         3. Mints the NFT to the minter.
    function mint() external {
        if (paused) revert IsPaused();
        if (mintPrice == 0) revert PriceNotSet();
        if (totalMinted >= maxSupply) revert SoldOut();

        uint256 tokenId = ++totalMinted;
        IERC20 pay = paymentToken;
        uint256 price = mintPrice;

        // Transfer tokens from minter → treasury
        pay.safeTransferFrom(msg.sender, treasury, price);

        // Notify treasury to auto-forward
        ITreasury(treasury).deposit(price);

        // Emit BEFORE external call (reentrancy-safe ordering)
        emit MintEvent(msg.sender, tokenId);

        // Mint NFT
        _safeMint(msg.sender, tokenId);
    }

    // ───── Owner: Pause ─────

    function pause() external onlyOwner {
        paused = true;
        emit Paused();
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused();
    }

    // ───── Owner: Max Supply ─────

    /// @notice Adjust max supply. Cannot go below already-minted amount.
    ///         Blocked when paused.
    function setMaxSupply(uint256 _newMax) external onlyOwner {
        if (paused) revert IsPaused();
        if (_newMax < totalMinted) revert BelowTotalMinted(_newMax, totalMinted);
        uint256 oldMax = maxSupply;
        maxSupply = _newMax;
        emit MaxSupplyUpdated(oldMax, _newMax);
    }

    // ───── Owner: Payment Token (2-step transfer) ─────

    /// @notice Step 1: Nominate a new payment token. Does not take effect yet.
    function nominatePaymentToken(address _newToken) external onlyOwner {
        if (_newToken == address(0)) revert ZeroAddress();
        if (address(paymentToken) == _newToken) return;
        pendingPaymentToken = _newToken;
        emit PaymentTokenNominated(address(paymentToken), _newToken);
    }

    /// @notice Step 2: Pending payment token address accepts to finalize.
    ///         Must be called by the nominated address (or its contract).
    function acceptPaymentToken() external {
        if (msg.sender != pendingPaymentToken) revert NotPendingAddress();
        paymentToken = IERC20(pendingPaymentToken);
        pendingPaymentToken = address(0);
        emit PaymentTokenAccepted(address(paymentToken));
    }

    // ───── Owner: Mint Price ─────

    function setMintPrice(uint256 _newPrice) external onlyOwner {
        if (paused) revert IsPaused();
        emit MintPriceUpdated(mintPrice, _newPrice);
        mintPrice = _newPrice;
    }

    // ───── Owner: Treasury (2-step transfer) ─────

    /// @notice Step 1: Nominate a new treasury. Does not take effect yet.
    function nominateTreasury(address _newTreasury) external onlyOwner {
        if (_newTreasury == address(0)) revert ZeroAddress();
        pendingTreasury = _newTreasury;
        emit TreasuryNominated(treasury, _newTreasury);
    }

    /// @notice Step 2: Pending treasury accepts to finalize.
    ///         Must be called by the nominated address.
    function acceptTreasury() external {
        if (msg.sender != pendingTreasury) revert NotPendingAddress();
        treasury = pendingTreasury;
        pendingTreasury = address(0);
        emit TreasuryAccepted(treasury);
    }

    // ───── Owner: Beneficiary ─────

    function setBeneficiary(address _newBeneficiary) external onlyOwner {
        if (_newBeneficiary == address(0)) revert ZeroAddress();
        emit BeneficiaryUpdated(beneficiary, _newBeneficiary);
        beneficiary = _newBeneficiary;
    }

    // ───── URI ─────

    /// @inheritdoc ERC721
    function _baseURI() internal view override returns (string memory) {
        return _contractBaseURI;
    }

    /// @notice Set the base URI.  Only owner.
    function setBaseURI(string memory _newBaseURI) external onlyOwner {
        emit BaseURIUpdated(_contractBaseURI, _newBaseURI);
        _contractBaseURI = _newBaseURI;
    }
}
