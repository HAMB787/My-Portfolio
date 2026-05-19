# Optimization Methods

University coursework: numerical and stochastic **optimization** and related models, implemented in Python. Each topic lives in its own folder with a script and documentation.

This page summarizes **every problem** solved in the repository. For full derivations and extra detail, follow the links in each section.

---

## Quick reference

| Folder | Problem / topic | Method | Script | Details |
|--------|-----------------|--------|--------|---------|
| [Exhaustive Search Method](Exhaustive%20Search%20Method/) | Minimize \(f(x)\) on \([0.5, 4]\) | Grid / brute force | `exh_srch_method.py` | [README](Exhaustive%20Search%20Method/README.md) |
| [Golden Section Search](Golden%20Section%20Search/) | Same \(f(x)\), unimodal 1D | Golden ratio interval reduction | `gld_sct_srch.py` | [README](Golden%20Section%20Search/README.md) |
| [Interval Halving Method](Interval%20Halving%20Method/) | Same \(f(x)\), unimodal 1D | Dichotomy / interval halving | `int_halving_meth.py` | [README](Interval%20Halving%20Method/README.md) |
| [Steepest Descent Method](Steepest%20Descent%20Method/) | Minimize 3D quadratic | Gradient descent + exact line search | `steepest_descent.py` | [README](Steepest%20Descent%20Method/README.md) |
| [Dynamic Optimization](Dynamic%20Optimization/) | **Problem 30 — Canyon Route** | Finite-horizon DP / optimal stopping | `dynamic_optimization.py` | [Problem 30](Dynamic%20Optimization/Problem-30-Canyon-Route.md) |
| [Markov Chains](Markov%20Chains/) | **Problem 30 — Warehouse Stock Refill** | Simulation + stationary \(\pi\) | `markov_chains.py` | [README](Markov%20Chains/README.md) |

---

## 1. Exhaustive Search Method

**Issue:** Find the minimum of a **one-dimensional** nonlinear function on a fixed interval by evaluating it on a **uniform grid** (derivative-free baseline).

**Objective function (shared with other 1D labs):**

\[
f(x) = (x - 2)^2 + \sqrt{x}
\]

**Parameters:**

| Parameter | Value |
|-----------|-------|
| Search interval \([a, b]\) | \([0.5,\, 4]\) |
| Number of partitions \(n\) | \(7\) |
| Step size \(h = (b-a)/n\) | \(0.5\) |

**What we solve:** Evaluate \(f\) at \(x_k = a + k h\) for \(k = 0,\ldots,n\), pick the grid point with smallest \(f\). Compare with the exact minimum from `scipy.optimize.minimize_scalar` (absolute error) and plot grid points vs the true minimum.

**How it works:** Brute-force search — simple but accuracy depends on \(h\); guarantees finding the best point **on the grid** (global on the grid if the grid is fine enough).

**Run:** `python exh_srch_method.py` — requires `numpy`, `scipy`, `matplotlib`.

---

## 2. Golden Section Search

**Issue:** Minimize the **same** \(f(x) = (x-2)^2 + \sqrt{x}\) on \([0.5, 4]\) for a **unimodal** function using an efficient interval-reduction method (fewer evaluations than exhaustive search).

**Parameters:**

| Parameter | Value |
|-----------|-------|
| Interval \([a, b]\) | \([0.5,\, 4]\) |
| Tolerance \(\varepsilon\) | \(0.5\) (stop when \(b - a \le \varepsilon\)) |
| Internal points | Golden-ratio placement (\(\approx 0.3819\) of interval length) |

**What we solve:** Repeatedly shrink the interval of uncertainty; only **one** new function evaluation per iteration after the first step (symmetry of the golden ratio). Plot the function and highlight the final uncertainty interval.

**How it works:** Compare \(f(x_1)\) and \(f(x_2)\) inside \([a,b]\); discard the half that cannot contain the minimum. Converges faster per evaluation than grid search for smooth unimodal \(f\).

**Run:** `python gld_sct_srch.py` — requires `numpy`, `matplotlib`.

---

## 3. Interval Halving Method (Dichotomy)

**Issue:** Again minimize \(f(x) = (x-2)^2 + \sqrt{x}\) on \([0.5, 4]\) by **halving** the search interval each iteration (alternative 1D method to golden section).

**Parameters:**

| Parameter | Value |
|-----------|-------|
| Interval \([a, b]\) | \([0.5,\, 4]\) |
| Tolerance \(\varepsilon\) | \(0.5\) |
| Separation \(\delta\) | \(0.125\) (must satisfy \(0 < \delta < 2\varepsilon\)) |

**Internal points:**

\[
x_1 = \frac{a + b - \delta}{2}, \qquad x_2 = \frac{a + b + \delta}{2}
\]

**What we solve:** Each iteration uses **two** evaluations near the midpoint to decide which half to keep. Terminal table logs iteration, bounds, interval length, and \(f\) at the midpoint; plot shows the final uncertainty band.

**How it works:** Region elimination — predictable \(\approx 50\%\) interval reduction per step; two function calls per iteration vs one for golden section.

**Run:** `python int_halving_meth.py` — requires `numpy`, `matplotlib`.

---

## 4. Steepest Descent Method

**Issue:** **Unconstrained minimization in \(\mathbb{R}^3\)** — move along the steepest descent direction with **optimal step size** at each step (multivariate optimization, not 1D).

**Objective function:**

\[
f(x_1, x_2, x_3) = \tfrac{1}{2}\bigl(7x_1^2 + 2x_1 x_2 - 4x_1 x_3 + 8x_2^2 - 2x_2 x_3 + 7x_3^2\bigr) - 5x_1 + 15x_2
\]

**Parameters:**

| Parameter | Value |
|-----------|-------|
| Initial point \(X^0\) | \((0,\, 2,\, 1)^\top\) |
| Stopping tolerance \(\varepsilon\) | \(10^{-3}\) on \(\max_i |\partial f / \partial x_i|\) |

**What we solve:** Sequence \(X_k\) with \(Y_k = -\nabla f(X_k)\) and \(X_{k+1} = X_k + \alpha^\* Y_k\), where \(\alpha^\*\) minimizes \(f(X_k + \alpha Y_k)\) (exact line search via SciPy). Print iteration table and final \(X^\*\), \(f(X^\*)\).

**Gradient (analytical):**

\[
\frac{\partial f}{\partial x_1} = 7x_1 + x_2 - 2x_3 - 5,\quad
\frac{\partial f}{\partial x_2} = x_1 + 8x_2 - x_3 + 15,\quad
\frac{\partial f}{\partial x_3} = -2x_1 - x_2 + 7x_3.
\]

**How it works:** First-order method; for this positive definite quadratic, convergence is to the **unique global minimum** (typical result: \(X^\* \approx (1,\,-2,\,0)^\top\), \(f(X^\*) \approx -17.5\)).

**Run:** `python steepest_descent.py` — requires `numpy`, `scipy`.

---

## 5. Dynamic Optimization — Problem 30: The Canyon Route

**Issue:** A transport company chooses **when to book** a canyon route. Each period brings one random **booking quote**; you may **accept** (stop, earn the quote) or **reject** (continue). Rejecting the **last** offer pays **0**.

**Setting:**

| Item | Value |
|------|-------|
| Horizon | \(T = 7\) periods |
| Possible quotes \(W\) | \(20,\, 35,\, 45\) |
| Probabilities | \(0.18,\, 0.42,\, 0.40\) (IID each period) |
| If accept | Earn current \(w\), process ends |
| If reject in period 7 | Payoff \(0\) |

**What we solve:** Value functions \(V_t(w)\) = maximum expected payoff from period \(t\) onward given current quote \(w\), via **backward induction**:

- Terminal: \(V_T(w) = \max\{w, 0\} = w\).
- Earlier: \(V_t(w) = \max\bigl\{ w,\; \mathbb{E}[V_{t+1}(W)] \bigr\}\).

**Decision rule:** Accept if \(w \ge \mathbb{E}[V_{t+1}(W)]\); otherwise wait.

**Output:** Step-by-step tables (expectation breakdown, Bellman updates, value-function tables per \(t\)).

**How it works:** Finite-horizon **optimal stopping** / dynamic programming — same family as secretary problem or optimal house selling.

**Run:** `python dynamic_optimization.py` — see [Problem-30-Canyon-Route.md](Dynamic%20Optimization/Problem-30-Canyon-Route.md).

---

## 6. Markov Chains — Problem 30: Warehouse Stock Refill

**Issue:** Model **daily warehouse stock** as a discrete-time **Markov chain**. Each day the state changes according to a fixed transition matrix \(P\). Study sample paths and the **long-run distribution** of states.

**States:** Full → High → Medium → Low → Reorder → Shortage (6 states).

**Transition matrix \(P\)** (rows = from, columns = to; each row sums to 1):

| From \ To | Full | High | Medium | Low | Reorder | Shortage |
|-----------|------|------|--------|-----|---------|----------|
| Full | 0.65 | 0.16 | 0.05 | 0.06 | 0.02 | 0.06 |
| High | 0.13 | 0.59 | 0.14 | 0.08 | 0.03 | 0.03 |
| Medium | 0.05 | 0.14 | 0.62 | 0.08 | 0.03 | 0.08 |
| Low | 0.11 | 0.07 | 0.10 | 0.43 | 0.18 | 0.11 |
| Reorder | 0.05 | 0.04 | 0.06 | 0.09 | 0.62 | 0.14 |
| Shortage | 0.02 | 0.04 | 0.03 | 0.06 | 0.27 | 0.58 |

**Initial state:** Full (index 0).

**What we solve:**

| Task | Description | Settings |
|------|-------------|----------|
| **1** | Plot **5** sample paths | Length **420** steps each |
| **2** | **Empirical** state shares | **1200** runs × **420** steps; bar chart of \(\hat{\pi}\) |
| **3** | Compare \(\pi\) three ways | Empirical vs **eigenvector** of \(P^\top\) (eigenvalue 1) vs **linear system** \((P^\top - I)\pi = 0\), \(\sum \pi_j = 1\) |

**How it works:** Monte Carlo time-in-state frequencies approximate \(\pi\); theory gives \(\pi^\top P = \pi^\top\). Close agreement validates both simulation and linear algebra.

**Run:** `python markov_chains.py` — requires `numpy`, `matplotlib` (interactive plots).

---

## Methods at a glance

| Category | Folders | Idea |
|----------|---------|------|
| **1D derivative-free** | Exhaustive, Golden Section, Interval Halving | Minimize \(f(x)\) on \([a,b]\) without gradients |
| **Multivariate first-order** | Steepest Descent | Use \(\nabla f\) + line search |
| **Dynamic programming** | Dynamic Optimization | Backward induction, optimal stopping |
| **Stochastic processes** | Markov Chains | Simulate chains, find stationary \(\pi\) |

The three **1D** labs share the same test function so you can **compare** methods (grid vs golden ratio vs dichotomy) on identical data.

---

## Setup and run

Install dependencies once:

```bash
pip install numpy scipy matplotlib
```

Examples:

```bash
cd "Exhaustive Search Method" && python exh_srch_method.py
cd "Golden Section Search"     && python gld_sct_srch.py
cd "Interval Halving Method"   && python int_halving_meth.py
cd "Steepest Descent Method"   && python steepest_descent.py
cd "Dynamic Optimization"      && python dynamic_optimization.py
cd "Markov Chains"             && python markov_chains.py
```

---

## Naming convention

Scripts use descriptive **snake_case** names (`steepest_descent.py`, `markov_chains.py`, `dynamic_optimization.py`, …) instead of generic `labN.py`, so the filename matches the method or topic.
