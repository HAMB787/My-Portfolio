# Problem 30 — The Canyon Route

## Problem statement

A transport company is choosing **when to book** a canyon route.

- Every **round** (period) the company receives **one booking quote** \(W_t\).
- The planner may **stop** at any time by **accepting** the current quote; the process then ends and the payoff is that quote.
- If the planner **rejects** the current quote, they **continue** to the next period and see a new draw.
- The **horizon is 7 periods**: there are up to **7** opportunities to observe a quote and decide.
- Each period, \(W_t\) is drawn **independently** from the same distribution:

  \[
  \mathbb{P}(W = 20) = 0.18,\quad
  \mathbb{P}(W = 35) = 0.42,\quad
  \mathbb{P}(W = 45) = 0.40.
  \]

- **If you accept** the current offer, the problem **ends immediately** and you earn that offer.
- **If you reject** it, you move to the next period (unless you are already at the end).
- **If you reject the final offer** (in period 7), you receive **0** — there is no eighth draw.

This is a classic **finite-horizon optimal stopping** problem: at each time step you compare the value of **stopping now** versus the value of **waiting** for the expected optimal continuation value.

---

## What we solve

We compute the **value function** \(V_t(w)\): the **maximum expected payoff** from period \(t\) onward, **given** that the quote observed **in period \(t\)** is \(w\).

From that, you can read off the **optimal decision** in each period for each possible \(w\):

- **Accept (stop)** if the immediate payoff \(w\) is at least as good as waiting.
- **Reject (continue)** if the expected continuation value is higher.

The implementation in `dynamic_optimization.py` walks through **backward induction** step by step and prints tables so you can see how \(V_t\) is built from \(V_{t+1}\).

---

## How it works (Bellman equation)

Let \(T = 7\) be the last period index used in the code (the “terminal” stage when rejecting yields no future quote).

### Terminal period (\(t = T\))

When the current quote is \(w\), you either accept and get \(w\), or reject and get **0**. Hence

\[
V_T(w) = \max\{ w,\, 0 \} = w
\quad\text{for } w \in \{20,\,35,\,45\}.
\]

### Earlier periods (\(t = 1,\ldots,T-1\))

If you **accept**, you earn \(w\) and stop. If you **reject**, you advance to \(t+1\) and the **next** quote \(W_{t+1}\) is random, but your future payoff from that point on is optimally described by \(V_{t+1}(W_{t+1})\). Therefore

\[
V_t(w) = \max\left\{\, w,\; \mathbb{E}\bigl[V_{t+1}(W)\bigr] \,\right\},
\]

where the expectation uses the fixed probabilities \(\mathbb{P}(W = 20),\mathbb{P}(W = 35),\mathbb{P}(W = 45)\) above.

Because the draws are **IID**, \(\mathbb{E}[V_{t+1}(W)]\) is the **same number** for every \(w\) at time \(t\): it does **not** depend on the current \(w\), only on the distribution of the **next** offer. The code expands that expectation explicitly as a weighted sum over the three support points.

---

## Algorithm: backward induction

1. **Initialize** \(V_T(w) = w\) for each possible \(w\).
2. For \(t = T-1, T-2, \ldots, 1\):
   - Compute the **continuation value** \(c_t = \mathbb{E}[V_{t+1}(W)]\).
   - Set \(V_t(w) = \max\{ w,\, c_t \}\) for each \(w\).

After step 2 finishes at \(t = 1\), you have the full value function and can state the **policy**: for each \(t\) and \(w\), accept iff \(w \ge c_t\) (with tie-breaking either way when \(w = c_t\); in code, `max` picks the larger or either if equal).

---

## Code reference

- **`dynamic_optimization.py`** — function `calculate_dp_detailed(W, phi, T)` runs this recursion for your support `W`, probabilities `phi`, and horizon `T`.
- The `__main__` block is set up for **Problem 30**:  
  `W_values = [20, 35, 45]`, `phi_probabilities = [0.18, 0.42, 0.4]`, `total_time_steps = 7`.

Run from this folder (or with the full path to `dynamic_optimization.py`):

```bash
python dynamic_optimization.py
```

---

## Summary

| Item | Meaning |
|------|--------|
| **Decision** | Accept current quote vs reject and wait |
| **Randomness** | IID offers \(W \in \{20,35,45\}\) with fixed probabilities |
| **Horizon** | 7 periods; reject in the last period \(\Rightarrow\) payoff 0 |
| **Method** | Finite-horizon DP / optimal stopping via backward induction |
| **Output** | \(V_t(w)\) and step-by-step expectation and \(\max\) updates |

This matches the **secretary / house-selling / canyon booking** style of model: you balance a **known current payoff** against the **option value** of seeing one more draw.
