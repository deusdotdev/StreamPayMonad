# RAMS Analysis — StreamPay

RAMS = **Reliability, Availability, Maintainability, Safety**.

This document adapts the classic RAMS engineering framework to the StreamPay
real-time payment streaming protocol (Solidity contract on Monad + Next.js
client). For a smart-contract system, **Safety** is extended to include
**Security**, since fund loss is the dominant hazard.

---

## 1. Reliability

*The ability of the system to perform its required functions correctly and consistently over time.*

### Mechanisms

- **Deterministic accounting** — Accrual is a pure function of state: `(now − lastClaimTimestamp) × ratePerMinute / 60`, capped at `employerBalance`. Same inputs always produce the same output.
- **No fund creation/loss invariant** — Payouts can never exceed the locked budget; rate changes/pauses move earnings into `pendingClaim` rather than discarding them.
- **Checks-Effects-Interactions** — State is updated before external calls, preventing inconsistent state on failed transfers.
- **Automated tests** — Foundry tests cover lifecycle, accrual over time, balance capping, auto-liquidation, rate adjustment, pause, emergency withdraw, and claim-sale flows.

### Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Rounding errors in accrual | Integer math with budget cap; small dust rounds down, never over-pays. |
| Timestamp drift | Tolerable for minute-scale rates; documented assumption. |
| Logic regressions | `forge test` gate; CI formatting/test checks. |

### Metrics / Targets

- Test pass rate: **100%** of defined scenarios.
- Invariant: `sum(payouts) ≤ initial deposit` for every stream — **always true**.

---

## 2. Availability

*The proportion of time the system is operational and accessible to users.*

### Contract layer

- Runs on the **Monad** network; availability inherits from chain liveness (no central server to fail).
- **No keeper dependency** — accrual and auto-liquidation need no off-chain process; the protocol cannot stall due to a down bot.
- Funds remain withdrawable as long as the chain produces blocks.

### Client layer

- Stateless static Next.js app; can be served from any CDN/edge (e.g., Vercel) and is horizontally scalable.
- Read paths use public RPC; UI degrades gracefully if RPC is slow (live counter is client-estimated).

### Risks & Mitigations

| Risk | Mitigation |
|---|---|
| RPC endpoint outage | Allow configurable/fallback RPC URLs. |
| Frontend host downtime | Static export deployable to multiple hosts. |
| Chain congestion | Monad's high throughput minimizes this; claims are retryable. |

### Metrics / Targets

- Contract availability ≈ **chain uptime** (no added single point of failure).
- Frontend target: **≥ 99.9%** via edge hosting.

---

## 3. Maintainability

*The ease with which the system can be understood, modified, tested, and operated.*

### Strengths

- **Single, well-commented contract** (`src/StreamPay.sol`) with NatSpec and rationale comments.
- **Monorepo separation** — contract, scripts, tests, and frontend are cleanly partitioned.
- **Self-contained frontend** — embedded ABI + address (`src/lib/contract.ts`) decouple the client from the build pipeline.
- **Reproducible tooling** — Foundry (`forge build/test/fmt`) and standard npm scripts.
- **Documentation set** — `README.md`, `REQUIREMENTS.md`, `SWOT.md`, this `RAMS.md`.

### Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Hardcoded address drifts after redeploy | Document update step; consider generating from `deployments.json`. |
| Non-upgradeable contract | Intentional for trust; new versions ship as new deployments + frontend pointer. |
| Frontend/ABI mismatch | Regenerate `streampay-abi.json` from the Foundry artifact on contract change. |

### Metrics / Targets

- Lint/format: **clean** (`forge fmt --check`, ESLint).
- Build: **green** (`forge build`, `npm run build`).

---

## 4. Safety & Security

*Freedom from unacceptable risk of harm — here, primarily the loss or lockup of user funds.*

### Hazard analysis

| Hazard | Severity | Cause | Control |
|---|---|---|---|
| Re-entrancy drains funds | Critical | External call before state update | `nonReentrant` guard + CEI ordering |
| Over-payment beyond budget | Critical | Faulty accrual | `min(accrued, employerBalance)` cap |
| Earnings lost on rate change | High | Wrong update order | Freeze accrual into `pendingClaim` **before** rate write |
| Unauthorized claim | High | Missing access control | `_currentClaimer` + `NOT_RECIPIENT`/`NOT_BUYER` checks |
| Employer abandons funds | Medium | Inactive employer | `emergencyWithdraw` after `EMERGENCY_DELAY` (24h) |
| Failed transfer leaves bad state | Medium | Recipient contract reverts | Effects before interactions; `require(ok)` reverts atomically |
| Wrong price / double sale | Medium | Sale race | `WRONG_PRICE`, `ALREADY_SOLD`, `SALE_EXPIRED` checks |

### Safety principles applied

- **Fail-safe** — invalid operations `revert` atomically; no partial state changes.
- **Least privilege** — employer-only and recipient-only functions are access-controlled.
- **Pull over push** — reserved earnings are withdrawn by the recipient (`withdrawPending`), avoiding forced-send failures.
- **Transparency** — all critical actions emit events for off-chain monitoring/auditing.

### Residual risks

- **No third-party audit yet** — recommended before mainnet / high value.
- **Economic risk** of the claim-sale market (buyer availability, pricing) is out of contract scope.
- **Native-asset volatility** affects real-world salary safety (mitigated later by ERC-20/stablecoin support).

---

## 5. Summary

| Attribute | Status | Key driver |
|---|---|---|
| Reliability | Strong | Deterministic math, budget-cap invariant, test coverage |
| Availability | Strong | On-chain, keeper-free; static, edge-deployable client |
| Maintainability | Good | Documented monorepo, self-contained client, standard tooling |
| Safety & Security | Good (pre-audit) | Re-entrancy guard, CEI, access control, fail-safe reverts |

**Top recommendation:** obtain a formal security audit and add ERC-20/stablecoin
support before any production / mainnet deployment carrying real value.
