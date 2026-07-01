// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {ContraNFT} from "../src/ContraNFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Test USDC", "tUSDC") {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// Mock treasury that implements ITreasury.deposit
contract MockTreasury {
    uint256 public totalDeposited;
    function deposit(uint256 amount) external {
        totalDeposited += amount;
    }
}

contract ContraNFTTest is Test {
    ContraNFT public nft;
    MockUSDC public usdc;
    MockTreasury public treasury;

    address owner = makeAddr("owner");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address beneficiary = makeAddr("beneficiary");

    uint256 constant MINT_PRICE = 10000 * 1e6; // 10000 USDC
    uint256 constant MAX_SUPPLY = 100;

    function setUp() public {
        usdc = new MockUSDC();
        treasury = new MockTreasury();

        vm.startPrank(owner);
        nft = new ContraNFT(
            "Contra AI",
            "CONTRA",
            address(usdc),
            MINT_PRICE,
            MAX_SUPPLY,
            address(treasury),
            beneficiary
        );
        vm.stopPrank();

        // Fund users (enough for 100 mints)
        usdc.mint(user1, 100 * MINT_PRICE + 10000 * 1e6);
        usdc.mint(user2, 10 * MINT_PRICE);
    }

    // ───── Mint Tests ─────

    function test_Mint_Success() public {
        vm.startPrank(user1);
        usdc.approve(address(nft), MINT_PRICE);
        nft.mint();
        vm.stopPrank();

        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.totalMinted(), 1);
        assertEq(treasury.totalDeposited(), MINT_PRICE);
    }

    function test_Mint_RevertWhenPaused() public {
        vm.prank(owner);
        nft.pause();

        vm.startPrank(user1);
        usdc.approve(address(nft), MINT_PRICE);
        vm.expectRevert(ContraNFT.IsPaused.selector);
        nft.mint();
        vm.stopPrank();
    }

    function test_Mint_RevertWhenSoldOut() public {
        // Mint all supply
        for (uint256 i = 0; i < MAX_SUPPLY; i++) {
            vm.startPrank(user1);
            usdc.approve(address(nft), MINT_PRICE);
            nft.mint();
            vm.stopPrank();
        }

        vm.startPrank(user2);
        usdc.approve(address(nft), MINT_PRICE);
        vm.expectRevert(ContraNFT.SoldOut.selector);
        nft.mint();
        vm.stopPrank();
    }

    function test_Mint_RevertWhenPriceZero() public {
        vm.prank(owner);
        nft.setMintPrice(0);

        vm.startPrank(user1);
        usdc.approve(address(nft), 0);
        vm.expectRevert(ContraNFT.PriceNotSet.selector);
        nft.mint();
        vm.stopPrank();
    }

    // ───── Pause Tests ─────

    function test_Pause_OnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.pause();
    }

    function test_Unpause() public {
        vm.prank(owner);
        nft.pause();
        assertTrue(nft.paused());

        vm.prank(owner);
        nft.unpause();
        assertFalse(nft.paused());
    }

    // ───── Max Supply Tests ─────

    function test_SetMaxSupply() public {
        vm.prank(owner);
        nft.setMaxSupply(200);
        assertEq(nft.maxSupply(), 200);
    }

    function test_SetMaxSupply_BelowTotalMinted() public {
        // Mint one
        vm.startPrank(user1);
        usdc.approve(address(nft), MINT_PRICE);
        nft.mint();
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(ContraNFT.BelowTotalMinted.selector, 0, 1)
        );
        nft.setMaxSupply(0);
    }

    function test_SetMaxSupply_BlockedWhenPaused() public {
        vm.prank(owner);
        nft.pause();

        vm.prank(owner);
        vm.expectRevert(ContraNFT.IsPaused.selector);
        nft.setMaxSupply(200);
    }

    // ───── 2-Step Treasury Tests ─────

    function test_Treasury_NominateAndAccept() public {
        address newTreasury = makeAddr("newTreasury");

        vm.prank(owner);
        nft.nominateTreasury(newTreasury);
        assertEq(nft.pendingTreasury(), newTreasury);

        vm.prank(newTreasury);
        nft.acceptTreasury();
        assertEq(nft.treasury(), newTreasury);
    }

    function test_Treasury_AcceptRevertsIfNotPending() public {
        address attacker = makeAddr("attacker");

        vm.prank(owner);
        nft.nominateTreasury(makeAddr("treasuryV2"));

        vm.prank(attacker);
        vm.expectRevert(ContraNFT.NotPendingAddress.selector);
        nft.acceptTreasury();
    }

    // ───── 2-Step PaymentToken Tests ─────

    function test_PaymentToken_NominateAndAccept() public {
        address newToken = makeAddr("newToken");

        vm.prank(owner);
        nft.nominatePaymentToken(newToken);
        assertEq(nft.pendingPaymentToken(), newToken);

        vm.prank(newToken);
        nft.acceptPaymentToken();
        assertEq(address(nft.paymentToken()), newToken);
    }

    // ───── SetMintPrice Tests ─────

    function test_SetMintPrice_BlockedWhenPaused() public {
        vm.prank(owner);
        nft.pause();

        vm.prank(owner);
        vm.expectRevert(ContraNFT.IsPaused.selector);
        nft.setMintPrice(5000 * 1e6);
    }

    // ───── URI Tests ─────

    function test_SetBaseURI() public {
        vm.prank(owner);
        nft.setBaseURI("https://contra.ai/api/nft/");

        // Mint to get tokenURI working
        vm.startPrank(user1);
        usdc.approve(address(nft), MINT_PRICE);
        nft.mint();
        vm.stopPrank();

        string memory uri = nft.tokenURI(1);
        assertTrue(bytes(uri).length > 0);
    }
}
