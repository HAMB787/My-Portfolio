# Interval Halving (Dichotomy) Method

This directory contains a Python implementation of the **Interval Halving Method** (also known as the Dichotomy Method). It is a robust, derivative-free numerical optimization algorithm used to find the minimum of a unimodal function over a bounded interval.

## 1. Theoretical Background
The Interval Halving Method is a region-elimination technique. Unlike the Golden Section Search which uses the golden ratio to place internal points, the Dichotomy method places two test points symmetrically around the exact midpoint of the current interval. 

These two points are separated by a very small, user-defined distance called $\delta$ (delta). By comparing the function values at these two closely packed points, the algorithm can confidently determine which half of the interval does *not* contain the minimum, effectively cutting the search space almost in half at every iteration.



**Advantages:**
* Provides a very predictable and rapid reduction of the search space (nearly 50% per iteration).
* Simple mathematical formulation and easy to conceptualize.

**Disadvantages:**
* Requires two new function evaluations per iteration, making it slightly more computationally expensive per step compared to the Golden Section Search (which requires only one).
* The choice of $\delta$ must be carefully balanced: too large, and it reduces the efficiency of the halving; too small, and it can cause floating-point precision issues.

## 2. Mathematical Formulation
We are minimizing the same target function to allow for direct comparison between methods:
$$f(x) = (x - 2)^2 + \sqrt{x}$$

* **Initial Search Interval:** $[a, b] = [0.5, 4]$
* **Stopping Criterion (Tolerance):** $\epsilon = 0.5$. The algorithm stops when the interval length $|b - a| \le \epsilon$.
* **Separation Parameter:** $\delta = 0.125$. Note that $\delta$ must strictly satisfy the condition $0 < \delta < 2\epsilon$.
* **Internal Points Calculation:**
  In each iteration, the two test points $x_1$ and $x_2$ are calculated as:
  $$x_1 = \frac{a + b - \delta}{2}$$
  $$x_2 = \frac{a + b + \delta}{2}$$

## 3. Code Structure & Implementation
The Python script is designed for clarity, logging, and visual feedback:
* **Dynamic Convergence:** The search operates within a `while (b - a) > eps:` loop, adhering strictly to the theoretical stopping condition.
* **Tabular Logging:** The script uses formatted strings (`f-strings`) to print a clean, structured table in the terminal. It logs the current iteration $k$, the bounds $a$ and $b$, the interval length, and the function value at the midpoint $f(x_m)$ step-by-step.
* **Advanced Visualization:** Utilizing `matplotlib`, the continuous function is plotted. The final "interval of uncertainty" is highlighted using `plt.axvspan` (a green shaded region), demonstrating exactly where the algorithm bounded the minimum before stopping. The final minimum point is marked with a distinct star symbol.

## 4. How to Run
Ensure you have the required libraries installed:
```bash
pip install numpy matplotlib