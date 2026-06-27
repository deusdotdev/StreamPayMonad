# Requirements Analysis — StreamPay

This document captures the functional and non-functional requirements, actors,
user stories, scenarios, and acceptance criteria for the StreamPay payment
streaming protocol.

---

## 1. Overview

StreamPay is a smart-contract protocol that enables **continuous, real-time
payments** on the Monad blockchain. Instead of a single lump-sum transfer, value
streams from a payer to a payee proportionally over time. A web client lets users
create, monitor, and manage these streams.

### 1.1 Goals

- Allow payers to commit a budget and stream it to a payee at a defined rate.
- Allow payees to withdraw accrued value at any time, trustlessly.
- Require no external keeper/bot for normal operation.
- Protect both parties from loss when rates change or streams stop.
- Provide instant liquidity by allowing payees to sell future claim rights.

### 1.2 Definitions

| Term | Meaning |
|---|---|
| Stream | A continuous payment from an employer to a recipient. |
| Employer | The party that funds and controls a stream. |
| Recipient | The party that earns and claims from a stream. |
| Accrued amount | Earned-but-unclaimed value at a point in time. |
| `pendingClaim` | Reserved earnings set aside on pause/rate change. |
| Claim right sale | Selling the right to claim a future window to a buyer. |

---

## 2. Actors / Roles

- **Employer** — creates streams, funds them, adjusts the rate, pauses streams.
- **Recipient** — monitors accrual, claims, sells future claim rights, performs emergency withdraw.
- **Buyer** — purchases a recipient's future claim right and claims during that window.
- **Anyone (read-only)** — can query stream state and claimable amounts.

---

## 3. Functional Requirements

Each requirement maps to on-chain behavior in `src/StreamPay.sol`.

### 3.1 Stream lifecycle

- **FR-1** The system SHALL let an employer create a stream specifying a recipient and a per-minute rate, locking `msg.value` as the budget. *(createStream)*
- **FR-2** The system SHALL reject stream creation with a zero recipient, zero rate, or zero deposit.
- **FR-3** The system SHALL accrue earnings continuously as `elapsed × ratePerMinute / 60`, capped at the remaining budget. *(claimableAmount)*
- **FR-4** The system SHALL let the recipient claim the accrued amount, transferring it and resetting the accrual clock. *(claim)*
- **FR-5** The system SHALL automatically deactivate a stream when its budget reaches zero.

### 3.2 Stream management

- **FR-6** The system SHALL let only the employer adjust the rate of an active stream. *(adjustRate)*
- **FR-7** On a rate change, the system SHALL freeze earnings accrued at the old rate into `pendingClaim` **before** applying the new rate, so no earnings are lost.
- **FR-8** The system SHALL let only the employer pause a stream, reserving the recipient's accrued earnings and refunding the remaining budget to the employer. *(pauseStream)*
- **FR-9** The system SHALL let the recipient withdraw reserved earnings even after the stream is inactive. *(withdrawPending)*
- **FR-10** The system SHALL let the recipient perform an emergency withdrawal of the full remaining budget only if the employer has not topped up for at least `EMERGENCY_DELAY` (24h). *(emergencyWithdraw)*

### 3.3 Future claim sale

- **FR-11** The system SHALL let the recipient list a future claim window `[now, now + duration]` at a fixed price. *(listFutureClaim)*
- **FR-12** The system SHALL let any buyer purchase a valid, unsold, unexpired listing by paying exactly the listed price, which is forwarded to the original recipient. *(buyFutureClaim)*
- **FR-13** During an active sale window, the system SHALL route claim rights to the buyer instead of the recipient; outside the window, rights revert to the recipient.

### 3.4 Frontend

- **FR-14** The client SHALL let users connect a wallet and detect/switch to Monad Testnet.
- **FR-15** The recipient panel SHALL display a recipient's active streams and a **live-updating** claimable counter, with a claim action.
- **FR-16** The employer panel SHALL let users create streams (with rate-per-day/second helpers) and manage existing streams (adjust rate, pause with confirmation).
- **FR-17** The client SHALL surface transaction states (pending, confirming, success, rejected).

---

## 4. Non-Functional Requirements

- **NFR-1 Security** — All state-changing fund flows MUST follow Checks-Effects-Interactions and be protected by a re-entrancy guard.
- **NFR-2 Trustlessness** — Normal operation (accrual, claim, auto-liquidation) MUST NOT depend on any off-chain keeper.
- **NFR-3 Correctness** — Earnings MUST NOT be lost on rate changes or pauses; the contract MUST never pay out more than the locked budget.
- **NFR-4 Transparency** — Every significant action MUST emit an event (`StreamCreated`, `Claimed`, `StreamPaused`, `RateAdjusted`, `EmergencyWithdrawn`, `FutureClaimListed`, `FutureClaimSold`).
- **NFR-5 Testability** — Core flows MUST be covered by Foundry tests (`forge test`).
- **NFR-6 Portability** — The frontend MUST build and deploy independently of the contract build output (embedded ABI + address).
- **NFR-7 Usability** — The UI MUST present a live, intuitive sense of "money flowing" and clear, real-time feedback.

---

## 5. User Stories

- As an **employer**, I want to stream a salary so my employee gets paid continuously without manual monthly transfers.
- As a **recipient**, I want to see my earnings grow live and withdraw at any moment.
- As an **employer**, I want to increase or decrease the rate without my employee losing already-earned funds.
- As a **recipient**, I want to recover my funds if the employer disappears.
- As a **recipient**, I want to sell part of my future earnings today to get instant cash.
- As a **buyer**, I want to buy discounted future earnings and claim them when the window arrives.

---

## 6. Use Case Scenarios

### 6.1 Happy path — salary stream

1. Employer creates a stream at 1 MON/min with a 100 MON budget.
2. After 10 minutes, the recipient claims ~10 MON.
3. The employer raises the rate to 2 MON/min; prior accrual is preserved.
4. The recipient keeps claiming until the budget empties and the stream auto-stops.

### 6.2 Rate adjustment safety

1. Recipient has accrued X at the old rate but has not claimed.
2. Employer calls `adjustRate`.
3. X is frozen into `pendingClaim`; new accrual starts at the new rate.
4. Recipient receives X + new accrual (no loss).

### 6.3 Future claim sale

1. Recipient lists a 20-minute future window at a 5% discount.
2. Buyer pays the price (sent to the recipient) and is recorded.
3. Within the window, the buyer can claim; the recipient cannot.
4. After the window, claim rights revert to the recipient.

### 6.4 Pause

1. Employer pauses an active stream.
2. Recipient's earnings up to that moment are reserved.
3. The remaining budget is refunded to the employer; the stream becomes inactive.

---

## 7. Constraints & Assumptions

- Native asset is **MON** on Monad Testnet (chain id 10143).
- Rate is expressed per minute; accrual is computed per second.
- One active claim-right sale is tracked per stream at a time.
- Time relies on `block.timestamp`; minor miner drift is acceptable for this use case.
- Emergency delay is fixed at 24 hours.

---

## 8. Out of Scope (current version)

- ERC-20 / multi-asset streams (native MON only for now).
- Full transfer of an entire stream (only future-window claim sale exists).
- On-chain lending/collateralization (see Roadmap in `README.md`).
- Upgradeability / governance.

---

## 9. Acceptance Criteria

- `forge test` passes for all lifecycle, rate-adjustment, pause, emergency, and claim-sale scenarios.
- A claim never returns more than `employerBalance`.
- After a rate change, `pendingClaim` holds exactly the old-rate accrual.
- During a sale window, only the buyer can claim; outside it, only the recipient.
- The frontend builds (`npm run build`) and deploys without access to the Foundry `out/` directory.
