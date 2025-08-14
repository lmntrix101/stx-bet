 STX-Bet Smart Contract

A **decentralized prediction market** built on the Stacks blockchain that enables users to create, join, and settle bets using STX. Outcomes are transparently recorded on-chain, and payouts are automatically distributed to winners.

---

 Features
- **Bet Creation** – Any user can start a bet with custom conditions.
- **Bet Participation** – Other users can place STX wagers on outcomes.
- **Outcome Resolution** – Resolved by an authorized admin or oracle.
- **Automatic Payouts** – Proportional STX rewards distributed instantly.
- **On-Chain Transparency** – All bets, participants, and results recorded on-chain.

---

 Project Structure
├── contracts
│ └── stx-bet.clar # Core smart contract logic
├── tests
│ └── stx-bet_test.ts # Contract unit tests
└── Clarinet.toml # Project configuration

---

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Basic knowledge of Clarity smart contracts

### Installation & Testing
```bash
# Clone repository
git clone https://github.com/your-username/stx-bet.git
cd stx-bet

# Install dependencies (if any)
npm install

# Run Clarinet tests
clarinet test
(contract-call? .stx-bet create-bet "MatchID-001" u1000000 u1700000000)
"MatchID-001" → unique bet/event identifier
u1000000 → bet amount in microSTX
u1700000000 → event end timestamp
(contract-call? .stx-bet join-bet "MatchID-001" true)
(contract-call? .stx-bet join-bet "MatchID-001" true)
"MatchID-001" → bet/event ID

true → chosen outcome (true/false for binary bets)
(contract-call? .stx-bet resolve-bet "MatchID-001" true)
"MatchID-001" → bet/event ID

true → winning outcome
