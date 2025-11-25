# 🏛️ Micro DAO Builder

> 🚀 Launch minimal, purpose-specific DAOs with plug-and-play governance

## 🌟 Overview

Micro DAO Builder enables anyone to create and manage lightweight DAOs perfect for neighborhood funds, school clubs, community projects, or any small-scale collaborative initiatives. Built on Stacks blockchain using Clarity smart contracts.

## ✨ Key Features

- 🎯 **Quick DAO Creation**: Launch a DAO in seconds with custom governance rules
- 👥 **Member Management**: Add/remove members with admin controls
- 🗳️ **Proposal Voting**: Create and vote on proposals with configurable thresholds
- 💰 **Treasury Management**: Secure fund management with member oversight
- ⚙️ **Configurable Governance**: Set voting periods and approval percentages
- 🔄 **Admin Transfer**: Transfer DAO ownership when needed

## 🚀 Quick Start

### Deploy the Contract

```bash
clarinet deploy
```

### Create Your First DAO

```clarity
(contract-call? .micro-dao-buider create-dao 
  "Neighborhood Fund" 
  "Managing our community garden budget" 
  u144  ;; 1 day voting period (blocks)
  u51)  ;; 51% approval threshold
```

### Join a DAO

```clarity
(contract-call? .micro-dao-buider join-dao u1)
```

### Add Funds to Treasury

```clarity
(contract-call? .micro-dao-buider deposit-to-dao u1 u1000000) ;; 1 STX
```

### Create a Proposal

```clarity
(contract-call? .micro-dao-buider create-proposal 
  u1 
  "Buy garden tools" 
  "Purchase shovels and watering cans for the community garden" 
  u500000  ;; 0.5 STX
  'ST1SOME-RECIPIENT-ADDRESS)
```

### Vote on Proposals

```clarity
(contract-call? .micro-dao-buider vote-proposal u1 true) ;; Vote yes
```

### Execute Passed Proposals

```clarity
(contract-call? .micro-dao-buider execute-proposal u1)
```

## 📋 Core Functions

### DAO Management
- `create-dao` - Launch a new DAO with custom settings
- `join-dao` - Join an existing DAO
- `add-member` - Admin function to add members
- `remove-member` - Admin function to remove members
- `update-dao-settings` - Modify governance parameters

### Proposals & Voting
- `create-proposal` - Submit funding proposals
- `create-simple-proposal` - Create non-funding proposals
- `vote-proposal` - Cast votes on active proposals
- `execute-proposal` - Execute passed proposals after voting period

### Treasury Operations
- `deposit-to-dao` - Add funds to DAO treasury
- `withdraw-treasury` - Admin emergency withdrawal

### Read-Only Functions
- `get-dao` - Retrieve DAO information
- `get-proposal` - Get proposal details
- `get-proposal-status` - Check voting status and results
- `is-dao-member` - Verify membership
- `get-active-proposals` - List ongoing votes

## 🎮 Example Use Cases

### 🏠 Neighborhood Association
```clarity
;; Create neighborhood DAO with 3-day voting, 60% approval
(contract-call? .micro-dao-buider create-dao 
  "Maple Street HOA" 
  "Managing shared expenses and community decisions" 
  u432 u60)
```

### 🎓 School Club
```clarity
;; Create club DAO with 1-day voting, simple majority
(contract-call? .micro-dao-buider create-dao 
  "Robotics Club" 
  "Budget decisions for competitions and equipment" 
  u144 u51)
```

### 🌱 Community Project
```clarity
;; Create project DAO with extended voting, high threshold
(contract-call? .micro-dao-buider create-dao 
  "Community Garden" 
  "Funding and maintaining our shared garden space" 
  u1008 u75)
```

## 🔧 Configuration

Each DAO can be customized with:
- **Voting Period**: Duration (in blocks) for proposal voting
- **Approval Threshold**: Minimum percentage needed to pass proposals
- **Member Permissions**: Admin vs regular member roles

## 🛡️ Security Features

- Only DAO members can vote on proposals
- Admins required for member management
- Treasury funds secured by contract logic
- Proposal execution only after voting period ends
- Protection against double voting

## 📊 Testing

```bash
clarinet test
```



---

Built with ❤️ on Stacks blockchain | Perfect for micro-communities and small organizations
