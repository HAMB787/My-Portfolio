# Problem 30 — Warehouse Stock Refill (Markov Chains)

This folder studies a **discrete-time Markov chain** that models daily warehouse stock levels. The script simulates paths, estimates long-run state frequencies, and compares them with the **stationary distribution** computed by two theoretical methods.

## Problem statement

The warehouse can be in one of six states:

| State | Meaning |
|-------|---------|
| Full | Highest stock level |
| High | |
| Medium | |
| Low | |
| Reorder | Trigger level for replenishment |
| Shortage | Lowest / critical level |

Transitions from one day to the next follow a fixed **stochastic matrix** \(P\), where \(P_{ij} = \mathbb{P}(\text{next state } j \mid \text{current state } i)\). All simulations start in **Full** (index 0).

The transition matrix is defined in `markov_chains.py` (rows sum to 1).

## What we solve

Three tasks, matching the coursework:

### Task 1 — Sample paths

- Simulate **5** independent chains, each of length **420** steps.
- Plot each path as a step chart (state vs time).

### Task 2 — Empirical distribution

- Run **1200** simulations × **420** steps.
- Count how often each state appears across **all** steps and all runs.
- Plot the **empirical share** \(\hat{\pi}_j\) for each state \(j\).

This estimates the long-run proportion of time the chain spends in each state when started from Full.

### Task 3 — Stationary distribution \(\pi\)

Compare three estimates of the limiting distribution \(\pi\) (where \(\pi^\top P = \pi^\top\) and \(\sum_j \pi_j = 1\)):

| Method | Idea |
|--------|------|
| **Empirical** | Task 2 frequencies from simulation |
| **Eigenvalue** | Left eigenvector of \(P\) for eigenvalue 1 (via `eig` on \(P^\top\)) |
| **Linear system** | Solve \((P^\top - I)\pi = 0\) with \(\sum_j \pi_j = 1\) (replace one row of the singular system) |

Print a comparison table and a grouped bar chart.

## How it works

**Simulation:** At each step \(t\), if the current state is \(i\), the next state is drawn from row \(P_{i,\cdot}\) using `numpy.random.choice`.

**Stationary \(\pi\):** For an irreducible, aperiodic finite chain, the empirical time spent in each state (over many steps) converges to \(\pi\). The eigen and linear methods give \(\pi\) **without** simulation, assuming the chain is well-behaved (here, a single recurrent class).

## Code reference

| File | Role |
|------|------|
| `markov_chains.py` | Matrix \(P\), `simulate_markov_chain`, Tasks 1–3, plots |

## How to run

```bash
pip install numpy matplotlib
python markov_chains.py
```

Close each plot window to advance to the next figure. The terminal prints the Task 3 comparison table after the simulations finish.

## Parameters (defaults in code)

| Parameter | Value |
|-----------|-------|
| Chain length | 420 |
| Number of simulations (Task 2–3) | 1200 |
| Initial state | Full (0) |
