# Insurance - Decentralized Protection Platform

## Overview

The **Insurance** contract provides a decentralized insurance system where users can buy policies, file claims, and manage risk pools on-chain. It ensures transparency, fairness, and automated claim resolution.

---

## Features

* **Risk Pools**: Create and manage pools with coverage types, premium rates, and total funds.
* **Policies**: Buy, renew, and cancel insurance policies with defined coverage and duration.
* **Premiums**: Calculate and track premium payments.
* **Claims**: File, approve, or reject claims in a decentralized manner.
* **Pool Management**: Track funds, claims paid, and active policies.

---

## Data Structures

* **policies**: Stores details of each insurance policy.

  * holder, coverage-type, coverage-amount, premium-paid, start-block, end-block, is-active

* **claims**: Tracks claims filed against policies.

  * policy-id, claimant, amount, description, status, filed-at, resolved-at

* **risk-pools**: Contains details of each coverage pool.

  * total-funds, active-policies, claims-paid, premium-rate

* **premium-history**: Logs premium payments per policy.

  * amount, payment-block

---

## Key Functions

### Read-Only

* `get-policy(policy-id)` – Retrieve a policy’s details
* `get-claim(claim-id)` – Retrieve claim details
* `get-risk-pool(pool-type)` – Retrieve pool details
* `policy-active(policy-id)` – Check if a policy is active
* `calculate-premium(coverage-amount, coverage-type)` – Calculate premium for coverage
* `get-policy-count()` – Total policies issued

### Public

* `create-risk-pool(pool-type, initial-funds, premium-rate)` – Create a new risk pool (admin only)
* `buy-policy(coverage-type, coverage-amount, duration)` – Buy a new policy
* `file-claim(policy-id, claim-amount, description)` – File a claim under a policy
* `approve-claim(claim-id)` – Approve and pay out a claim (admin only)
* `reject-claim(claim-id)` – Reject a claim (admin only)
* `renew-policy(policy-id, additional-duration)` – Extend a policy duration with additional premium
* `cancel-policy(policy-id)` – Cancel an active policy

---

## Error Codes

* `ERR_UNAUTHORIZED (401)` – Unauthorized action
* `ERR_NOT_FOUND (404)` – Policy or pool not found
* `ERR_POLICY_EXPIRED (403)` – Policy is inactive or expired
* `ERR_INVALID_AMOUNT (400)` – Invalid amount specified
* `ERR_CLAIM_EXISTS (405)` – Claim already processed
* `ERR_INSUFFICIENT_POOL (402)` – Insufficient pool funds
