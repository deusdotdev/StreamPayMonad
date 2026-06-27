// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title StreamPay - Dakika bazlı maaş/ödeme akışı (payment streaming)
/// @notice İşveren bir miktar MON kilitler, alıcı zaman ilerledikçe
///         birikmiş tutarı talep edebilir. Bakiye bittiğinde akış otomatik
///         olarak durur; dışarıdan bir likidasyon botuna ihtiyaç yoktur.
contract StreamPay {
    // Akış oranının zaman birimi: 1 dakika = 60 saniye.
    uint256 public constant SECONDS_PER_MINUTE = 60;

    // emergencyWithdraw için bekleme süresi: işveren bu süredir bakiye
    // eklemediyse (akışı terk ettiyse) alıcı kalan fonu kurtarabilir.
    uint256 public constant EMERGENCY_DELAY = 24 hours;

    struct Stream {
        address employer; // akışı oluşturan ve fonu sağlayan
        address recipient; // ödemeyi alacak adres
        uint256 ratePerMinute; // dakika başına akan tutar (wei)
        uint256 lastClaimTimestamp; // son talep/oluşturma anı
        uint256 employerBalance; // kontratta kilitli kalan bakiye
        uint256 lastTopUpTimestamp; // işverenin son fon ekleme anı
        bool active; // akış hala aktif mi
    }

    // Alıcının (recipient) bir akıştaki gelecekteki talep hakkını, belirli bir
    // zaman aralığı için iskontolu olarak bir alıcıya (buyer) satması.
    struct ClaimRightSale {
        uint256 streamId; // hangi akışa ait
        uint256 startTime; // hak devrinin başladığı an
        uint256 endTime; // hak devrinin bittiği an
        address originalRecipient; // ilanı açan asıl alacaklı
        address buyer; // hakkı satın alan (0 ise henüz satılmadı)
        bool active; // satış tamamlandı/aktif mi
    }

    mapping(uint256 => Stream) public streams;
    uint256 public nextStreamId;

    mapping(uint256 => ClaimRightSale) public claimSales;
    uint256 public nextSaleId;

    // Akış durdurulduğunda/oran değiştiğinde alıcının hak edip henüz almadığı,
    // employerBalance'tan ayrılarak rezerve edilen tutar (pull-payment).
    mapping(uint256 => uint256) public pendingClaim;

    // ClaimRightSale struct'ı (kullanıcı tarafından sabitlenmiş) fiyat alanı
    // içermediğinden, ilan fiyatını ayrı bir mapping'de tutuyoruz.
    mapping(uint256 => uint256) public salePrice;

    // Bir akış için geçerli satış kimliği (saleId + 1; 0 = satış yok).
    // claim sırasında o anki yetkili talep edeni belirlemek için kullanılır.
    mapping(uint256 => uint256) private _saleOfStreamPlusOne;

    // Basit re-entrancy guard. 1 = giriş yok, 2 = içerideyiz.
    uint256 private _locked = 1;

    event StreamCreated(
        uint256 indexed streamId,
        address indexed employer,
        address indexed recipient,
        uint256 ratePerMinute,
        uint256 deposit
    );
    event Claimed(uint256 indexed streamId, address indexed recipient, uint256 amount);
    event StreamPaused(uint256 indexed streamId);
    event RateAdjusted(uint256 indexed streamId, uint256 oldRatePerMinute, uint256 newRatePerMinute);
    event EmergencyWithdrawn(uint256 indexed streamId, address indexed recipient, uint256 amount);
    event FutureClaimListed(
        uint256 indexed saleId,
        uint256 indexed streamId,
        address indexed recipient,
        uint256 startTime,
        uint256 endTime,
        uint256 price
    );
    event FutureClaimSold(uint256 indexed saleId, uint256 indexed streamId, address indexed buyer, uint256 price);

    /// @dev Fonksiyon yeniden girilemez (re-entrancy koruması).
    modifier nonReentrant() {
        require(_locked == 1, "REENTRANCY");
        _locked = 2;
        _;
        _locked = 1;
    }

    /// @notice Yeni bir ödeme akışı oluşturur ve gönderilen MON'u kilitler.
    /// @param recipient Ödemeyi alacak adres.
    /// @param ratePerMinute Dakika başına akan tutar (wei).
    /// @return streamId Oluşturulan akışın kimliği.
    function createStream(address recipient, uint256 ratePerMinute) external payable returns (uint256 streamId) {
        require(recipient != address(0), "ZERO_RECIPIENT");
        require(ratePerMinute > 0, "ZERO_RATE");
        require(msg.value > 0, "ZERO_DEPOSIT");

        // Yeni id'yi al ve sayacı artır.
        streamId = nextStreamId;
        nextStreamId++;

        // Gönderilen MON (msg.value) işverenin bakiyesi olarak kaydedilir.
        // Sayaç şu andan (block.timestamp) itibaren işlemeye başlar.
        streams[streamId] = Stream({
            employer: msg.sender,
            recipient: recipient,
            ratePerMinute: ratePerMinute,
            lastClaimTimestamp: block.timestamp,
            employerBalance: msg.value,
            lastTopUpTimestamp: block.timestamp,
            active: true
        });

        emit StreamCreated(streamId, msg.sender, recipient, ratePerMinute, msg.value);
    }

    /// @notice Şu an talep edilebilir (birikmiş) tutarı hesaplar.
    /// @dev Geçen süre * oran; ancak kilitli bakiyeyi (employerBalance) aşamaz.
    ///      Oran dakika bazlı olduğu için geçen saniye 60'a bölünür. Birikim
    ///      saniye bazında orantılı (sürekli) ilerler; tam dakika beklemeye
    ///      gerek yoktur.
    function claimableAmount(uint256 streamId) public view returns (uint256) {
        Stream storage s = streams[streamId];

        // Aktif değilse veya bakiye yoksa talep edilebilir tutar 0'dır.
        if (!s.active || s.employerBalance == 0) {
            return 0;
        }

        // Son talepten bu yana geçen süre kadar tutar birikir.
        // accrued = geçen_saniye * (dakikalik_oran / 60)
        uint256 elapsed = block.timestamp - s.lastClaimTimestamp;
        uint256 accrued = (elapsed * s.ratePerMinute) / SECONDS_PER_MINUTE;

        // Bakiyeyi aşamaz: min(accrued, employerBalance).
        if (accrued > s.employerBalance) {
            return s.employerBalance;
        }
        return accrued;
    }

    /// @notice Birikmiş tutarı o anki yetkili talep edene öder.
    /// @dev Normalde alıcı (recipient) çağırır. Ancak şu anki zaman aktif bir
    ///      ClaimRightSale'in [startTime, endTime] aralığındaysa, o dilim için
    ///      yetkili talep eden satın alan (buyer) olur ve ödeme buyer'a gider.
    ///      Checks-Effects-Interactions deseni uygulanır.
    function claim(uint256 streamId) external nonReentrant {
        Stream storage s = streams[streamId];

        // --- Checks ---
        require(s.active, "NOT_ACTIVE");

        // O an hak sahibi kim? (satış penceresindeyse buyer, değilse recipient)
        address payee = _currentClaimer(streamId);
        if (msg.sender != payee) {
            // Hata mesajı, beklenen yetkiliye göre değişir.
            revert(payee == s.recipient ? "NOT_RECIPIENT" : "NOT_BUYER");
        }

        uint256 amount = claimableAmount(streamId);
        require(amount > 0, "NOTHING_TO_CLAIM");

        // --- Effects (transferden ÖNCE state güncellenir) ---
        s.employerBalance -= amount;
        s.lastClaimTimestamp = block.timestamp;

        // Bakiye sıfıra düştüyse akışı otomatik olarak durdur (likidasyon).
        if (s.employerBalance == 0) {
            s.active = false;
            emit StreamPaused(streamId);
        }

        emit Claimed(streamId, payee, amount);

        // --- Interactions (her şeyin sonunda dış çağrı) ---
        (bool ok,) = payable(payee).call{value: amount}("");
        require(ok, "TRANSFER_FAILED");
    }

    /// @dev Verilen akış için şu an talep hakkına sahip adresi döner.
    ///      Aktif bir satış penceresi içindeysek buyer, aksi halde recipient.
    function _currentClaimer(uint256 streamId) internal view returns (address) {
        uint256 plusOne = _saleOfStreamPlusOne[streamId];
        if (plusOne != 0) {
            ClaimRightSale storage sale = claimSales[plusOne - 1];
            if (sale.active && block.timestamp >= sale.startTime && block.timestamp <= sale.endTime) {
                return sale.buyer;
            }
        }
        return streams[streamId].recipient;
    }

    /// @notice Akışı durdurur; hak edilen tutarı alıcıya rezerve eder, kalanı
    ///         işverene iade eder. Sadece işveren çağırabilir.
    /// @dev Çalışan kaybetmez: durdurma anına kadar biriken tutar pendingClaim
    ///      olarak ayrılır (alıcı withdrawPending ile çeker). CEI uygulanır.
    function pauseStream(uint256 streamId) external nonReentrant {
        Stream storage s = streams[streamId];

        // --- Checks ---
        require(s.active, "NOT_ACTIVE");
        require(msg.sender == s.employer, "NOT_EMPLOYER");

        // --- Effects ---
        // Önce biriken hak edişi alıcı için rezerve et (employerBalance'tan ayrılır).
        _settleAccrued(streamId);

        // Geriye kalan tüm bakiye işverene iade edilecek.
        uint256 refund = s.employerBalance;
        s.employerBalance = 0;
        s.active = false;

        emit StreamPaused(streamId);

        // --- Interactions ---
        if (refund > 0) {
            (bool ok,) = payable(s.employer).call{value: refund}("");
            require(ok, "REFUND_FAILED");
        }
    }

    /// @notice Akışın dakikalık oranını değiştirir. Sadece işveren, aktif akış.
    /// @dev Sıralama kritik: ÖNCE eski oranla biriken tutar dondurulur
    ///      (pendingClaim'e taşınır, lastClaimTimestamp güncellenir), SONRA
    ///      yeni oran yazılır. Böylece değişimden önceki hak ediş kaybolmaz.
    function adjustRate(uint256 streamId, uint256 newRatePerMinute) external {
        Stream storage s = streams[streamId];

        require(s.active, "NOT_ACTIVE");
        require(msg.sender == s.employer, "NOT_EMPLOYER");
        require(newRatePerMinute > 0, "ZERO_RATE");

        // 1) Önce eski oranla biriken miktarı dondur/koru.
        _settleAccrued(streamId);

        // 2) Sonra yeni oranı uygula.
        uint256 oldRate = s.ratePerMinute;
        s.ratePerMinute = newRatePerMinute;

        emit RateAdjusted(streamId, oldRate, newRatePerMinute);
    }

    /// @notice İşveren akışı terk ettiyse (EMERGENCY_DELAY süresince fon
    ///         eklemediyse) alıcının kalan bakiyenin tamamını kurtarmasını sağlar.
    /// @dev Sadece alıcı çağırabilir.
    function emergencyWithdraw(uint256 streamId) external nonReentrant {
        Stream storage s = streams[streamId];

        // --- Checks ---
        require(s.active, "NOT_ACTIVE");
        require(msg.sender == s.recipient, "NOT_RECIPIENT");
        require(block.timestamp >= s.lastTopUpTimestamp + EMERGENCY_DELAY, "NOT_STALE");

        uint256 amount = s.employerBalance;
        require(amount > 0, "NOTHING_TO_WITHDRAW");

        // --- Effects ---
        s.employerBalance = 0;
        s.active = false;

        emit EmergencyWithdrawn(streamId, s.recipient, amount);

        // --- Interactions ---
        (bool ok,) = payable(s.recipient).call{value: amount}("");
        require(ok, "TRANSFER_FAILED");
    }

    /// @notice Rezerve edilmiş (pendingClaim) tutarı alıcıya öder.
    /// @dev Akış pasif olsa bile çalışır; pauseStream/adjustRate ile ayrılan
    ///      hak edişin çekilmesini sağlar.
    function withdrawPending(uint256 streamId) external nonReentrant {
        Stream storage s = streams[streamId];
        require(msg.sender == s.recipient, "NOT_RECIPIENT");

        uint256 amount = pendingClaim[streamId];
        require(amount > 0, "NOTHING_TO_CLAIM");

        // --- Effects ---
        pendingClaim[streamId] = 0;
        emit Claimed(streamId, s.recipient, amount);

        // --- Interactions ---
        (bool ok,) = payable(s.recipient).call{value: amount}("");
        require(ok, "TRANSFER_FAILED");
    }

    /// @dev O ana kadar biriken hak edişi employerBalance'tan düşüp
    ///      pendingClaim'e taşır ve sayacı (lastClaimTimestamp) sıfırlar.
    ///      Böylece oran değişimi/durdurma anındaki birikim korunur.
    function _settleAccrued(uint256 streamId) private {
        Stream storage s = streams[streamId];
        uint256 accrued = claimableAmount(streamId);
        if (accrued > 0) {
            s.employerBalance -= accrued;
            pendingClaim[streamId] += accrued;
        }
        s.lastClaimTimestamp = block.timestamp;
    }

    /// @notice Alıcı, [şimdi, şimdi + durationSeconds] aralığındaki talep hakkını
    ///         iskontolu bir fiyatla satışa çıkarır. Sadece akışın recipient'ı.
    /// @return saleId Oluşturulan satış ilanının kimliği.
    function listFutureClaim(uint256 streamId, uint256 durationSeconds, uint256 price)
        external
        returns (uint256 saleId)
    {
        Stream storage s = streams[streamId];
        require(msg.sender == s.recipient, "NOT_RECIPIENT");
        require(s.active, "NOT_ACTIVE");
        require(durationSeconds > 0, "ZERO_DURATION");
        require(price > 0, "ZERO_PRICE");

        saleId = nextSaleId;
        nextSaleId++;

        // Satış penceresi ilan anından itibaren başlar; buyer henüz boş (0).
        claimSales[saleId] = ClaimRightSale({
            streamId: streamId,
            startTime: block.timestamp,
            endTime: block.timestamp + durationSeconds,
            originalRecipient: msg.sender,
            buyer: address(0),
            active: false
        });
        salePrice[saleId] = price;

        emit FutureClaimListed(saleId, streamId, msg.sender, block.timestamp, block.timestamp + durationSeconds, price);
    }

    /// @notice İlanı satın alır: ilan fiyatını öder (asıl alacaklıya gider) ve
    ///         satış penceresi boyunca talep hakkını üstlenir. Herkes çağırabilir.
    function buyFutureClaim(uint256 saleId) external payable nonReentrant {
        ClaimRightSale storage sale = claimSales[saleId];

        // --- Checks ---
        require(sale.originalRecipient != address(0), "NO_SALE");
        require(!sale.active, "ALREADY_SOLD");
        require(block.timestamp < sale.endTime, "SALE_EXPIRED");
        require(msg.value == salePrice[saleId], "WRONG_PRICE");

        // --- Effects ---
        sale.buyer = msg.sender;
        sale.active = true;
        _saleOfStreamPlusOne[sale.streamId] = saleId + 1;

        emit FutureClaimSold(saleId, sale.streamId, msg.sender, msg.value);

        // --- Interactions (anlık ödeme asıl alacaklıya gider) ---
        (bool ok,) = payable(sale.originalRecipient).call{value: msg.value}("");
        require(ok, "PAYMENT_FAILED");
    }
}
