// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {StreamPay} from "../src/StreamPay.sol";

contract StreamPayTest is Test {
    // expectEmit için kontrattaki event'lerin yerel kopyaları.
    event StreamPaused(uint256 indexed streamId);
    event RateAdjusted(uint256 indexed streamId, uint256 oldRatePerMinute, uint256 newRatePerMinute);
    event EmergencyWithdrawn(uint256 indexed streamId, address indexed recipient, uint256 amount);

    StreamPay internal streamPay;

    address internal employer = makeAddr("employer");
    address internal recipient = makeAddr("recipient");
    address internal stranger = makeAddr("stranger");
    address internal buyer = makeAddr("buyer");

    // 1 ether / dakika -> saniye başına temiz bölünebilir (60'a tam bölünür).
    uint256 internal constant RATE_PER_MINUTE = 1 ether;

    function setUp() public {
        streamPay = new StreamPay();
        // İşvereni ve alıcıyı fonla.
        vm.deal(employer, 100 ether);
        vm.deal(buyer, 100 ether);
    }

    /// Yardımcı: employer adına bir akış oluşturur ve id'yi döner.
    function _createStream(uint256 deposit) internal returns (uint256 id) {
        vm.prank(employer);
        id = streamPay.createStream{value: deposit}(recipient, RATE_PER_MINUTE);
    }

    // 1) createStream akışı doğru alanlarla oluşturmalı.
    function test_CreateStream_StoresCorrectData() public {
        uint256 deposit = 10 ether;
        uint256 id = _createStream(deposit);

        assertEq(id, 0, "ilk stream id 0 olmali");
        assertEq(streamPay.nextStreamId(), 1, "sayac artmali");
        // Kilitli fon kontrata gecmis olmali.
        assertEq(address(streamPay).balance, deposit, "kontrat bakiyesi depozit kadar");

        (
            address sEmployer,
            address sRecipient,
            uint256 sRate,
            uint256 sLastClaim,
            uint256 sBalance,
            uint256 sLastTopUp,
            bool sActive
        ) = streamPay.streams(id);

        assertEq(sEmployer, employer, "employer yanlis");
        assertEq(sRecipient, recipient, "recipient yanlis");
        assertEq(sRate, RATE_PER_MINUTE, "oran yanlis");
        assertEq(sLastClaim, block.timestamp, "lastClaim = block.timestamp olmali");
        assertEq(sBalance, deposit, "employerBalance = msg.value olmali");
        assertEq(sLastTopUp, block.timestamp, "lastTopUp = block.timestamp olmali");
        assertTrue(sActive, "akis aktif olmali");
    }

    // 2) Zaman ilerledikten sonra claim doğru miktarı vermeli.
    function test_Claim_PaysCorrectAmountAfterTime() public {
        uint256 deposit = 10 ether;
        uint256 id = _createStream(deposit);

        // 2 dakika ilerlet -> 2 * RATE_PER_MINUTE birikmeli.
        vm.warp(block.timestamp + 2 minutes);

        uint256 expected = 2 * RATE_PER_MINUTE;
        assertEq(streamPay.claimableAmount(id), expected, "claimable 2 dk * oran olmali");

        uint256 before = recipient.balance;
        vm.prank(recipient);
        streamPay.claim(id);

        assertEq(recipient.balance - before, expected, "recipient dogru tutari almali");

        (, , , uint256 sLastClaim, uint256 sBalance, , bool sActive) = streamPay.streams(id);
        assertEq(sBalance, deposit - expected, "bakiye dusulmis olmali");
        assertEq(sLastClaim, block.timestamp, "lastClaim guncellenmeli");
        assertTrue(sActive, "bakiye var, akis hala aktif");
        // Talepten hemen sonra birikmis tutar 0 olmali.
        assertEq(streamPay.claimableAmount(id), 0, "talepten sonra claimable 0");
    }

    // 3) Bakiye yetersizken claim yalnızca kalanı vermeli, fazlasını değil.
    function test_Claim_CapsAtEmployerBalance() public {
        uint256 deposit = 1 ether; // sadece 1 dakikalik fon
        uint256 id = _createStream(deposit);

        // 10 dakika ilerlet: teorik birikim 10 ether ama bakiye 1 ether.
        vm.warp(block.timestamp + 10 minutes);

        // claimable bakiyeyi asmamali.
        assertEq(streamPay.claimableAmount(id), deposit, "claimable bakiye ile sinirli");

        uint256 before = recipient.balance;
        vm.prank(recipient);
        streamPay.claim(id);

        assertEq(recipient.balance - before, deposit, "sadece kalan bakiye odenmeli");
        assertEq(address(streamPay).balance, 0, "kontratta fon kalmamali");
    }

    // 4) Bakiye sıfırlandığında active otomatik false olmalı (StreamPaused).
    function test_Claim_DeactivatesWhenBalanceDrained() public {
        uint256 deposit = 1 ether;
        uint256 id = _createStream(deposit);

        vm.warp(block.timestamp + 5 minutes);

        // StreamPaused event'i beklenir.
        vm.expectEmit(true, false, false, false, address(streamPay));
        emit StreamPaused(id);

        vm.prank(recipient);
        streamPay.claim(id);

        (, , , , uint256 sBalance, , bool sActive) = streamPay.streams(id);
        assertEq(sBalance, 0, "bakiye 0 olmali");
        assertFalse(sActive, "akis otomatik pasiflesmeli");
        // Pasif akista yeni claim revert etmeli.
        vm.warp(block.timestamp + 1 minutes);
        vm.prank(recipient);
        vm.expectRevert(bytes("NOT_ACTIVE"));
        streamPay.claim(id);
    }

    // 5) recipient olmayan biri claim çağırırsa revert etmeli.
    function test_Claim_RevertsForNonRecipient() public {
        uint256 id = _createStream(10 ether);
        vm.warp(block.timestamp + 1 minutes);

        vm.prank(stranger);
        vm.expectRevert(bytes("NOT_RECIPIENT"));
        streamPay.claim(id);

        // employer da recipient degil -> o da revert etmeli.
        vm.prank(employer);
        vm.expectRevert(bytes("NOT_RECIPIENT"));
        streamPay.claim(id);
    }

    // 6) pauseStream sonrası: hak edis alıcıya rezerve edilmeli, kalan
    //    employer'a iade edilmeli; alıcı pending'i çekince doğru tutarı almalı.
    function test_PauseStream_ReservesAccruedAndRefundsEmployer() public {
        uint256 deposit = 10 ether;
        uint256 id = _createStream(deposit);

        // 3 dakika ilerlet -> 3 ether hak edis.
        vm.warp(block.timestamp + 3 minutes);
        uint256 accrued = 3 * RATE_PER_MINUTE;

        uint256 employerBefore = employer.balance;

        vm.prank(employer);
        streamPay.pauseStream(id);

        // Akis pasif, bakiye 0, hak edis pendingClaim'e rezerve edilmis olmali.
        (, , , , uint256 sBalance, , bool sActive) = streamPay.streams(id);
        assertFalse(sActive, "akis durdurulmus olmali");
        assertEq(sBalance, 0, "employerBalance sifirlanmali");
        assertEq(streamPay.pendingClaim(id), accrued, "hak edis rezerve edilmeli");

        // Kalan (deposit - accrued) employer'a iade edilmis olmali.
        assertEq(employer.balance - employerBefore, deposit - accrued, "kalan employer'a iade");

        // Alıcı rezerve tutari ceker.
        uint256 recipientBefore = recipient.balance;
        vm.prank(recipient);
        streamPay.withdrawPending(id);
        assertEq(recipient.balance - recipientBefore, accrued, "alici hak edisi almali");
        assertEq(streamPay.pendingClaim(id), 0, "pending sifirlanmali");
    }

    // 7) adjustRate: degisimden onceki birikim kaybolmamali; eski + yeni hizla
    //    biriken toplam dogru olmali.
    function test_AdjustRate_PreservesAccruedBeforeChange() public {
        uint256 deposit = 100 ether;
        uint256 id = _createStream(deposit);

        // Faz 1: eski hizla (1 ether/dk) 2 dakika -> 2 ether.
        vm.warp(block.timestamp + 2 minutes);
        uint256 oldAccrued = 2 * RATE_PER_MINUTE;

        uint256 newRate = 3 ether;
        vm.expectEmit(true, false, false, true, address(streamPay));
        emit RateAdjusted(id, RATE_PER_MINUTE, newRate);

        vm.prank(employer);
        streamPay.adjustRate(id, newRate);

        // Eski birikim donduruldu (pendingClaim), oran guncellendi.
        assertEq(streamPay.pendingClaim(id), oldAccrued, "eski birikim korunmali");
        (, , uint256 sRate, , , , ) = streamPay.streams(id);
        assertEq(sRate, newRate, "oran guncellenmis olmali");
        // Degisim aninda yeni birikim henuz 0.
        assertEq(streamPay.claimableAmount(id), 0, "degisimden hemen sonra yeni birikim 0");

        // Faz 2: yeni hizla (3 ether/dk) 4 dakika -> 12 ether.
        vm.warp(block.timestamp + 4 minutes);
        uint256 newAccrued = 4 * newRate;
        assertEq(streamPay.claimableAmount(id), newAccrued, "yeni hizla birikim dogru");

        // Alici hem yeni birikimi (claim) hem eski birikimi (withdrawPending) alir.
        uint256 before = recipient.balance;
        vm.startPrank(recipient);
        streamPay.claim(id);
        streamPay.withdrawPending(id);
        vm.stopPrank();

        // Toplam = eski + yeni, hicbiri kaybolmamis.
        assertEq(recipient.balance - before, oldAccrued + newAccrued, "eski + yeni toplam dogru");
    }

    // 8) emergencyWithdraw 24 saat dolmadan revert etmeli.
    function test_EmergencyWithdraw_RevertsBeforeDelay() public {
        uint256 id = _createStream(10 ether);

        // Sadece 1 saat gecti (EMERGENCY_DELAY = 24 saat).
        vm.warp(block.timestamp + 1 hours);

        vm.prank(recipient);
        vm.expectRevert(bytes("NOT_STALE"));
        streamPay.emergencyWithdraw(id);
    }

    // 9) emergencyWithdraw 24 saat dolduktan sonra kalan bakiyeyi alıcıya vermeli.
    function test_EmergencyWithdraw_WorksAfterDelay() public {
        uint256 deposit = 10 ether;
        uint256 id = _createStream(deposit);

        // 24 saat + 1 saniye ilerlet.
        vm.warp(block.timestamp + 24 hours + 1);

        uint256 before = recipient.balance;

        vm.expectEmit(true, true, false, true, address(streamPay));
        emit EmergencyWithdrawn(id, recipient, deposit);

        vm.prank(recipient);
        streamPay.emergencyWithdraw(id);

        assertEq(recipient.balance - before, deposit, "alici tum bakiyeyi almali");
        assertEq(address(streamPay).balance, 0, "kontratta fon kalmamali");

        (, , , , uint256 sBalance, , bool sActive) = streamPay.streams(id);
        assertEq(sBalance, 0, "bakiye 0 olmali");
        assertFalse(sActive, "akis pasiflesmeli");
    }

    // 10) listFutureClaim + buyFutureClaim akışı doğru çalışmalı.
    function test_ListAndBuyFutureClaim() public {
        uint256 id = _createStream(100 ether);

        uint256 duration = 10 minutes;
        uint256 price = 5 ether;
        uint256 t0 = block.timestamp;

        // recipient ilanı açar.
        vm.prank(recipient);
        uint256 saleId = streamPay.listFutureClaim(id, duration, price);
        assertEq(saleId, 0, "ilk sale id 0");
        assertEq(streamPay.nextSaleId(), 1, "sale sayaci artmali");
        assertEq(streamPay.salePrice(saleId), price, "fiyat kaydedilmeli");

        (
            uint256 sStreamId,
            uint256 sStart,
            uint256 sEnd,
            address sOriginal,
            address sBuyer,
            bool sActive
        ) = streamPay.claimSales(saleId);
        assertEq(sStreamId, id, "streamId");
        assertEq(sStart, t0, "startTime ilan ani");
        assertEq(sEnd, t0 + duration, "endTime = baslangic + sure");
        assertEq(sOriginal, recipient, "originalRecipient recipient olmali");
        assertEq(sBuyer, address(0), "henuz buyer yok");
        assertFalse(sActive, "henuz satilmadi");

        // buyer satin alir; fiyat recipient'a gider.
        uint256 recipientBefore = recipient.balance;
        vm.prank(buyer);
        streamPay.buyFutureClaim{value: price}(saleId);

        assertEq(recipient.balance - recipientBefore, price, "fiyat recipient'a gitmeli");
        (, , , , address sBuyer2, bool sActive2) = streamPay.claimSales(saleId);
        assertEq(sBuyer2, buyer, "buyer kaydedilmeli");
        assertTrue(sActive2, "satis aktif olmali");
    }

    // 11) Satılan zaman diliminde buyer claim edebilmeli, recipient edememeli.
    function test_BuyerClaimsDuringWindow_RecipientCannot() public {
        uint256 id = _createStream(100 ether);
        uint256 price = 5 ether;

        vm.prank(recipient);
        uint256 saleId = streamPay.listFutureClaim(id, 10 minutes, price);

        vm.prank(buyer);
        streamPay.buyFutureClaim{value: price}(saleId);

        // Pencere içine gir (2 dk).
        vm.warp(block.timestamp + 2 minutes);
        uint256 accrued = 2 * RATE_PER_MINUTE;

        // recipient bu dilimde claim edemez -> NOT_BUYER.
        vm.prank(recipient);
        vm.expectRevert(bytes("NOT_BUYER"));
        streamPay.claim(id);

        // buyer claim edebilir ve tutari alir.
        uint256 buyerBefore = buyer.balance;
        vm.prank(buyer);
        streamPay.claim(id);
        assertEq(buyer.balance - buyerBefore, accrued, "buyer dilim tutarini almali");
    }

    // 12) Satış süresi dolduktan sonra claim hakkı recipient'a geri dönmeli.
    function test_ClaimRightRevertsToRecipientAfterWindow() public {
        uint256 id = _createStream(100 ether);
        uint256 price = 5 ether;
        uint256 duration = 10 minutes;

        vm.prank(recipient);
        uint256 saleId = streamPay.listFutureClaim(id, duration, price);

        vm.prank(buyer);
        streamPay.buyFutureClaim{value: price}(saleId);

        // Pencerenin ötesine geç (süre + 1 dk).
        vm.warp(block.timestamp + duration + 1 minutes);

        // buyer artik claim edemez -> hak recipient'a dondu.
        vm.prank(buyer);
        vm.expectRevert(bytes("NOT_RECIPIENT"));
        streamPay.claim(id);

        // recipient claim edebilir.
        uint256 recipientBefore = recipient.balance;
        vm.prank(recipient);
        streamPay.claim(id);
        assertGt(recipient.balance - recipientBefore, 0, "recipient tekrar claim edebilmeli");
    }
}
