# Golden Section Search Method

This directory contains an optimized Python implementation of the **Golden Section Search** algorithm. It is a highly efficient, derivative-free numerical method used for finding the global extremum (minimum or maximum) of a strictly unimodal function within a specified bound.

## 1. Theoretical Background
Unlike simple grid search methods, the Golden Section Search dynamically narrows down the "interval of uncertainty" where the minimum must reside. 

It does this by strategically placing two internal points, $x_1$ and $x_2$, inside the current interval $[a, b]$. The distances of these points from the boundaries are determined by the **Golden Ratio** ($\phi = \frac{1 + \sqrt{5}}{2} \approx 1.61803$). 



**The Core Advantage (Efficiency):** Because of the mathematical symmetry of the golden ratio, when the interval is reduced for the next iteration, one of the previously evaluated internal points automatically becomes a new internal point for the new interval. This means the algorithm only needs to evaluate the objective function **once** per iteration (after the initial setup), effectively halving the computational cost compared to the Dichotomy method.

## 2. Mathematical Formulation
To maintain consistency across our numerical experiments, we are minimizing the following objective function:
$$f(x) = (x - 2)^2 + \sqrt{x}$$

* **Initial Search Interval:** $[a, b] = [0.5, 4]$
* **Stopping Criterion (Tolerance):** $\epsilon = 0.5$. The iterations terminate when the length of the interval strictly satisfies $|b - a| \le \epsilon$.
* **Internal Points Calculation:**
  Using the golden ratio conjugate ($2 - \phi \approx 0.3819$), the internal points are formulated as:
  $$x_1 = a + 0.3819 \cdot (b - a)$$
  $$x_2 = b - 0.3819 \cdot (b - a)$$
  *(Alternatively represented as $x_1 = a + b - x_2$)*

## 3. Code Structure & Optimizations
The Python script is written with performance and clarity in mind:
* **Optimized `while` Loop:** The algorithm avoids redundant function calls. It actively reassigns $f(x_1)$ to $f(x_2)$ (or vice versa) based on which boundary is shifted, calculating only one new $f(x)$ per loop.
* **Exact Convergence:** The `while (b - a) > eps:` condition guarantees that the algorithm mathematically proves the interval is smaller than the required tolerance before stopping.
* **Visualization Output:** Using `matplotlib`, the continuous target function is plotted. A colored shaded region (`plt.axvspan`) highlights the exact final interval of uncertainty, clearly demonstrating the algorithm's precision.

## 4. How to Run
Ensure you have the required Python libraries installed:
```bash
pip install numpy matplotlib