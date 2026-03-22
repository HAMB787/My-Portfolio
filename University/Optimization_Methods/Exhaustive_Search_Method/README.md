# Exhaustive Search Method (Brute-Force Optimization)

This directory contains a Python implementation of the **Exhaustive Search Method** for 1D unconstrained optimization. This project is part of my Optimization Methods coursework and serves as a foundational baseline for numerical analysis.

## 1. Theoretical Background
The Exhaustive Search method (often referred to as Grid Search or Brute-Force) is one of the simplest numerical algorithms used to find the global minimum (or maximum) of a function within a bounded interval. 

It operates by dividing the given search space $[a, b]$ into $n$ equal segments. The algorithm evaluates the objective function at each grid point and selects the point that yields the smallest function value.

[Image of Exhaustive Search Method numerical grid optimization]

**Advantages:**
* Guarantees finding the global extremum if the grid is sufficiently dense (avoids getting trapped in local minima).
* Extremely simple to implement and does not require calculating derivatives (derivative-free optimization).

**Disadvantages:**
* Computationally expensive for highly complex functions or multi-dimensional problems.
* The accuracy is strictly limited by the chosen step size $h$.

## 2. Mathematical Formulation
For this specific implementation, we are minimizing the following non-linear objective function:
$$f(x) = (x - 2)^2 + \sqrt{x}$$

* **Search Interval:** $[a, b] = [0.5, 4]$
* **Number of Partitions:** $n = 7$
* **Step Size:** Calculated using the formula:
  $$h = \frac{b - a}{n} = \frac{4 - 0.5}{7} = 0.5$$

The algorithm evaluates the function at points $x_k = a + k \cdot h$ for $k = 0, 1, \dots, n$.

## 3. Code Structure and Implementation
The Python script is structured to be highly readable and modular:
1. **Configuration:** Defines global constants ($A$, $B$, $N$).
2. **Objective Function:** The mathematical function $f(x)$ defined in Python.
3. **Core Algorithm (`exhaustive_search`):** Iterates through the generated points, stores the evaluations, and returns the numerical minimum.
4. **Analytical Validation:** Uses `scipy.optimize.minimize_scalar` to compute the exact minimum. This is crucial for calculating the **Absolute Error** of our numerical method and proving its validity.
5. **Visualization:** Utilizes `matplotlib` to plot the continuous function, mark all sampled points, and highlight both the numerical and exact minima for visual comparison.

## 4. How to Run
Ensure you have the required libraries installed:
```bash
pip install numpy scipy matplotlib