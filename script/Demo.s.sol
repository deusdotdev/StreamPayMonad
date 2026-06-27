// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {StreamPay} from "../src/StreamPay.sol";

/// @notice StreamPay'in tüm akışını (stream aç, claim, adjustRate, gelecek
///         talep satışı, pauseStream) tek bir lokal senaryoda adım adım
///         gösteren demo. Cheatcode kullandığı için --broadcast'siz çalışır:
///         forge script script/Demo.s.sol:DemoScript -vvv
contract DemoScript is Script {
    // Kontrat dakika bazlı: ratePerMinute. "1 MON/saniye" -> 60 MON/dakika.
    uint256 internal constant RATE_1_PER_SEC = 60 ether; // 1 MON/sn
    uint256 internal constant RATE_2_PER_SEC = 120 ether; // 2 MON/sn

    StreamPay internal streamPay;

    address internal employer;
    address internal recipient1; // freelancer
    address internal buyer; // likidite sağlayıcı

    function run() external {
        streamPay = new StreamPay();

        _step1_setupWallets();
        uint256 streamId = _step2_createStream();
        _step3_firstClaim(streamId);
        _step4_adjustRate(streamId);
        _step5_claimAtNewRate(streamId);
        uint256 saleId = _step6_listFutureClaim(streamId);
        _step7_buyFutureClaim(saleId);
        _step8_buyerClaimsInWindow(streamId);
        _step9_recipientClaimsAfterWindow(streamId);
        _step10_pauseStream(streamId);
    }

    // ---------------------------------------------------------------------

    function _step1_setupWallets() internal {
        console2.log("=== ADIM 1: Test cuzdanlari olusturuluyor ===");
        employer = vm.addr(1);
        recipient1 = vm.addr(2);
        buyer = vm.addr(3);

        // Aktorleri fonla.
        vm.deal(employer, 1000 ether);
        vm.deal(recipient1, 0);
        vm.deal(buyer, 1000 ether);

        console2.log("employer       :", employer);
        console2.log("recipient1     :", recipient1);
        console2.log("buyer          :", buyer);
        _logBalances();
    }

    function _step2_createStream() internal returns (uint256 streamId) {
        console2.log("");
        console2.log("=== ADIM 2: employer -> recipient1 stream aciyor (1 MON/sn) ===");
        uint256 deposit = 200 ether;

        vm.prank(employer);
        streamId = streamPay.createStream{value: deposit}(recipient1, RATE_1_PER_SEC);

        console2.log("streamId           :", streamId);
        console2.log("yatirilan (MON)    :", deposit / 1e18);
        console2.log("oran (MON/dakika)  :", RATE_1_PER_SEC / 1e18);
        console2.log("baslangic zamani   :", block.timestamp);
        _logBalances();
    }

    function _step3_firstClaim(uint256 streamId) internal {
        console2.log("");
        console2.log("=== ADIM 3: 10 saniye ilerle, recipient1 claim eder ===");
        vm.warp(block.timestamp + 10);
        console2.log("yeni zaman         :", block.timestamp);

        uint256 claimable = streamPay.claimableAmount(streamId);
        console2.log("talep edilebilir(MON):", claimable / 1e18);

        uint256 before = recipient1.balance;
        vm.prank(recipient1);
        streamPay.claim(streamId);
        console2.log("recipient1 aldi(MON):", (recipient1.balance - before) / 1e18);
        _logBalances();
    }

    function _step4_adjustRate(uint256 streamId) internal {
        console2.log("");
        console2.log("=== ADIM 4: employer hizi 2 MON/sn'ye cikariyor (adjustRate) ===");
        vm.prank(employer);
        streamPay.adjustRate(streamId, RATE_2_PER_SEC);

        (,, uint256 rate,,,,) = streamPay.streams(streamId);
        console2.log("yeni oran(MON/dakika):", rate / 1e18);
    }

    function _step5_claimAtNewRate(uint256 streamId) internal {
        console2.log("");
        console2.log("=== ADIM 5: 5 saniye daha ilerle, recipient1 yeni hizla claim eder ===");
        vm.warp(block.timestamp + 5);
        console2.log("yeni zaman         :", block.timestamp);

        uint256 claimable = streamPay.claimableAmount(streamId);
        console2.log("talep edilebilir(MON):", claimable / 1e18, "(5sn x 2 MON/sn = 10)");

        uint256 before = recipient1.balance;
        vm.prank(recipient1);
        streamPay.claim(streamId);
        console2.log("recipient1 aldi(MON):", (recipient1.balance - before) / 1e18);
        _logBalances();
    }

    function _step6_listFutureClaim(uint256 streamId) internal returns (uint256 saleId) {
        console2.log("");
        console2.log("=== ADIM 6: recipient1 gelecek 20 sn'lik kazancini %5 indirimle satar ===");
        uint256 duration = 20; // saniye
        // 20 sn x 2 MON/sn = 40 MON; %5 indirim -> 38 MON.
        uint256 fullValue = (duration * RATE_2_PER_SEC) / 60;
        uint256 price = (fullValue * 95) / 100;

        console2.log("pencere suresi(sn) :", duration);
        console2.log("tam deger(MON)     :", fullValue / 1e18);
        console2.log("indirimli fiyat(MON):", price / 1e18);

        vm.prank(recipient1);
        saleId = streamPay.listFutureClaim(streamId, duration, price);

        (, uint256 start, uint256 end,,,) = streamPay.claimSales(saleId);
        console2.log("saleId             :", saleId);
        console2.log("pencere baslangic  :", start);
        console2.log("pencere bitis      :", end);
    }

    function _step7_buyFutureClaim(uint256 saleId) internal {
        console2.log("");
        console2.log("=== ADIM 7: buyer satisi aliyor, odeme aninda recipient1'e gidiyor ===");
        uint256 price = streamPay.salePrice(saleId);

        uint256 recipientBefore = recipient1.balance;
        vm.prank(buyer);
        streamPay.buyFutureClaim{value: price}(saleId);

        console2.log("buyer odedi(MON)        :", price / 1e18);
        console2.log("recipient1 kazanci(MON) :", (recipient1.balance - recipientBefore) / 1e18);
        _logBalances();
    }

    function _step8_buyerClaimsInWindow(uint256 streamId) internal {
        console2.log("");
        console2.log("=== ADIM 8: Pencere icinde buyer claim eder, recipient1 EDEMEZ ===");
        vm.warp(block.timestamp + 10); // pencere [start, start+20] icinde
        console2.log("yeni zaman         :", block.timestamp);

        // recipient1 bu dilimde claim edemez.
        vm.prank(recipient1);
        try streamPay.claim(streamId) {
            console2.log("BEKLENMEDIK: recipient1 claim edebildi!");
        } catch Error(string memory reason) {
            console2.log("recipient1 claim REDDEDILDI:", reason);
        }

        // buyer claim edebilir.
        uint256 before = buyer.balance;
        vm.prank(buyer);
        streamPay.claim(streamId);
        console2.log("buyer claim etti(MON):", (buyer.balance - before) / 1e18);
        _logBalances();
    }

    function _step9_recipientClaimsAfterWindow(uint256 streamId) internal {
        console2.log("");
        console2.log("=== ADIM 9: Pencere bitti, claim hakki recipient1'e geri dondu ===");
        vm.warp(block.timestamp + 15); // pencerenin disina cik
        console2.log("yeni zaman         :", block.timestamp);

        // buyer artik claim edemez.
        vm.prank(buyer);
        try streamPay.claim(streamId) {
            console2.log("BEKLENMEDIK: buyer hala claim edebildi!");
        } catch Error(string memory reason) {
            console2.log("buyer claim REDDEDILDI:", reason);
        }

        uint256 before = recipient1.balance;
        vm.prank(recipient1);
        streamPay.claim(streamId);
        console2.log("recipient1 claim etti(MON):", (recipient1.balance - before) / 1e18);
        _logBalances();
    }

    function _step10_pauseStream(uint256 streamId) internal {
        console2.log("");
        console2.log("=== ADIM 10: 5 sn daha sonra employer pauseStream cagiriyor ===");
        vm.warp(block.timestamp + 5); // pause oncesi biraz daha hak edis biriksin
        console2.log("yeni zaman         :", block.timestamp);

        uint256 employerBefore = employer.balance;
        (,,,, uint256 balanceBefore,,) = streamPay.streams(streamId);
        console2.log("durdurmadan once kontrat bakiyesi(MON):", balanceBefore / 1e18);

        vm.prank(employer);
        streamPay.pauseStream(streamId);

        // recipient1'in son hak edisi pendingClaim'e rezerve edildi.
        uint256 pending = streamPay.pendingClaim(streamId);
        console2.log("recipient1 son hak edis(rezerve, MON):", pending / 1e18);
        console2.log("employer'a iade(MON):", (employer.balance - employerBefore) / 1e18);

        // recipient1 rezerve tutari ceker.
        uint256 before = recipient1.balance;
        vm.prank(recipient1);
        streamPay.withdrawPending(streamId);
        console2.log("recipient1 rezervi cekti(MON):", (recipient1.balance - before) / 1e18);

        (,,,, uint256 balanceAfter,, bool active) = streamPay.streams(streamId);
        console2.log("son kontrat bakiyesi(MON):", balanceAfter / 1e18);
        console2.log("stream aktif mi:", active);
        _logBalances();
    }

    // ---------------------------------------------------------------------

    function _logBalances() internal view {
        console2.log("--- bakiyeler (MON) ---");
        console2.log("  employer  :", employer.balance / 1e18);
        console2.log("  recipient1:", recipient1.balance / 1e18);
        console2.log("  buyer     :", buyer.balance / 1e18);
        console2.log("  kontrat   :", address(streamPay).balance / 1e18);
    }
}
