# StreamPay

**Real-time payment streaming protocol on Monad.**

Money doesn't move in a single lump — it **flows second by second**. An employer
locks a budget once; the recipient's balance accrues automatically as time passes,
and they can withdraw whenever they want. When the budget runs out, the stream
stops on its own. No intermediary, no bank, no keeper bot — all logic lives on-chain.

<p>
  <img alt="Solidity" src="https://img.shields.io/badge/Solidity-0.8.20-363636?logo=solidity">
  <img alt="Foundry" src="https://img.shields.io/badge/Built%20with-Foundry-orange">
  <img alt="Next.js" src="https://img.shields.io/badge/Next.js-16-black?logo=nextdotjs">
  <img alt="Monad" src="https://img.shields.io/badge/Monad-Testnet%2010143-7c3aed">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-green">
</p>

> **Deployed (Monad Testnet · 10143):** `0x151b311C24AEC109C2cA652C3327E7e58551De6f`

## Table of Contents

- [Features](#features)
- [How It Works](#how-it-works)
- [Use Cases](#use-cases)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
- [Documentation](#documentation)
- [Roadmap](#roadmap)
- [License](#license)

---

## Features

- **Create a stream** — The employer calls `createStream`, sets the recipient and a per-minute rate, and locks an initial budget (`msg.value`).
- **Continuous accrual** — With no transactions required, `elapsed × rate` worth of earnings accrue for the recipient. Accrual can never exceed the locked budget.
- **Claim anytime** — The recipient calls `claim` to pull the accrued amount into their wallet.
- **Automatic liquidation** — When the budget hits zero, the stream deactivates itself. No keeper/bot needed.
- **Rate adjustment** — `adjustRate` changes the speed; the amount accrued at the *old* rate is frozen into `pendingClaim` **before** the change, so earnings are never lost.
- **Safe pause** — `pauseStream` reserves the recipient's earnings up to that moment and refunds the remaining budget to the employer.
- **Emergency withdraw** — If the employer adds no funds for `EMERGENCY_DELAY` (24h), the recipient can rescue the remaining balance via `emergencyWithdraw`.
- **Future claim sale** — A recipient lists the claim rights for a future time window with `listFutureClaim`; a buyer purchases it at a discount via `buyFutureClaim`. During that window, `claim` rights transfer to the buyer (instant liquidity).
- **Security** — Re-entrancy guard + Checks-Effects-Interactions pattern; payouts follow a pull-payment model.

## How It Works

1. **Employer** opens a stream and locks a budget.
2. As time advances, the recipient's entitlement grows automatically.
3. **Recipient** claims the accrued amount whenever they like.
4. If the budget empties, the stream stops by itself.

The rate is per-minute, but accrual is proportional **per second**:

```
accrued = (block.timestamp − lastClaimTimestamp) × ratePerMinute / 60
capped at employerBalance
```

## Use Cases

- **Freelance / remote work** — payment flows as the work progresses, reducing trust issues.
- **Salaries** — employees withdraw earnings without waiting for month-end.
- **Subscriptions & rentals** — automatic, pay-as-you-go payments.
- **Vesting / allocations** — time-distributed token grants for teams and investors.

---

## Architecture

A monorepo: an on-chain contract (Foundry) plus a client (Next.js).

```
.
├── src/StreamPay.sol        # Core contract
├── test/StreamPay.t.sol     # Foundry tests
├── script/
│   ├── Deploy.s.sol         # Deploy + writes deployments.json
│   └── Demo.s.sol           # End-to-end scenario simulation
├── foundry.toml             # Monad testnet RPC/chain config
├── deployments.json         # Deployed address
├── REQUIREMENTS.md          # Requirements analysis
├── SWOT.md                  # SWOT analysis
├── RAMS.md                  # Reliability/Availability/Maintainability/Safety
└── streampay-app/           # Next.js frontend
    └── src/
        ├── app/             # /, /recipient, /employer, /about
        ├── components/      # NavBar, Footer, ConnectButton, NetworkBanner
        └── lib/             # wagmi config, contract (ABI+address), formatters
```

### Contract layer (`src/StreamPay.sol`)

State:

- `Stream` — `employer, recipient, ratePerMinute, lastClaimTimestamp, employerBalance, lastTopUpTimestamp, active`
- `ClaimRightSale` — `streamId, startTime, endTime, originalRecipient, buyer, active`
- Mappings: `streams`, `claimSales`, `pendingClaim` (reserved earnings), `salePrice` (listing price)

Core functions:

| Function | Caller | Purpose |
|---|---|---|
| `createStream` | Employer | Opens a stream, locks the budget |
| `claimableAmount` (view) | Anyone | Computes the currently accrued amount |
| `claim` | Recipient / buyer in sale window | Pays out the accrued amount |
| `adjustRate` | Employer | Changes the rate (accrual frozen first) |
| `pauseStream` | Employer | Stops the stream; reserves earnings, refunds the rest |
| `emergencyWithdraw` | Recipient | Rescues remaining funds from an abandoned stream |
| `withdrawPending` | Recipient | Withdraws reserved (`pendingClaim`) earnings |
| `listFutureClaim` / `buyFutureClaim` | Recipient / buyer | Sale of future claim rights |

### Client layer (`streampay-app/`)

- **Next.js (App Router) + TypeScript**, **wagmi + viem** for chain interaction, **TanStack Query** for data, **Tailwind CSS** for styling.
- Pages: `/` (landing), `/recipient` (recipient panel — live claim counter), `/employer` (employer panel — create/manage streams), `/about` (detailed explainer).
- The app is self-contained: the ABI and deployed address are embedded in `src/lib/contract.ts`, so it can be deployed independently without the Foundry build output.

## Tech Stack

| Layer | Tools |
|---|---|
| Smart contract | Solidity ^0.8.20, Foundry (forge / cast) |
| Network | Monad Testnet (chain id 10143) |
| Frontend | Next.js 16, React 19, TypeScript |
| Web3 | wagmi, viem, TanStack Query |
| Styling | Tailwind CSS v4 |

---

## Getting Started

Requirements: [Foundry](https://book.getfoundry.sh/) and Node.js 18+.

```bash
# Contract
forge install
forge build
forge test            # run tests

# Frontend
cd streampay-app
npm install
npm run dev           # http://localhost:3000
```

Deploy (create `.env` from `.env.example` first):

```bash
forge script script/Deploy.s.sol \
  --rpc-url $MONAD_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

---

## Documentation

Beyond this README, the repository includes a full analysis set:

- **[REQUIREMENTS.md](REQUIREMENTS.md)** — functional & non-functional requirements, actors, user stories, use-case scenarios, and acceptance criteria.
- **[SWOT.md](SWOT.md)** — strengths, weaknesses, opportunities, threats, and strategic takeaways.
- **[RAMS.md](RAMS.md)** — reliability, availability, maintainability, and safety/security (with hazard analysis).

---

## Roadmap

The long-term goal is to turn payment streams into a base layer that financial
products can be built on top of:

- **DeFi collateral** — lock an active stream (predictable future cash flow) as collateral to borrow.
- **Stream transfer** — permanent transfer of an entire stream to another address; receivables tradable on a secondary market.
- **Credit & factoring** — stream-based collateralized lending pools built on the future-claim-sale mechanism.
- **ERC-20 & multi-asset** — token-based streams beyond native MON; payroll, subscription, and vesting scenarios.

---

## License

MIT

Built by [@ex_machinam](https://x.com/ex_machinam)
