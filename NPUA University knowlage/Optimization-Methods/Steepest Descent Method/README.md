# Steepest Descent Method

This folder implements the **method of steepest descent** (gradient descent with **exact line search**) for minimizing a multivariate quadratic objective function in \(\mathbb{R}^3\).

## Problem we solve

Find a local (here, global) minimum of

\[
f(x_1, x_2, x_3) = \tfrac{1}{2}\bigl(7x_1^2 + 2x_1 x_2 - 4x_1 x_3 + 8x_2^2 - 2x_2 x_3 + 7x_3^2\bigr) - 5x_1 + 15x_2
\]

starting from \(X^0 = (0,\, 2,\, 1)^\top\), and stop when the largest absolute partial derivative is at most \(\varepsilon = 10^{-3}\).

This is a standard **unconstrained smooth optimization** exercise: at each step we move in the direction of the **negative gradient** and choose the step length \(\alpha\) that minimizes \(f\) along that ray.

## How it works

1. **Gradient** \(\nabla f(X)\) is computed **analytically** (no finite differences).
2. **Stopping rule:** \(\max_i \bigl|\partial f / \partial x_i\bigr| \le \varepsilon\).
3. **Search direction:** \(Y_k = -\nabla f(X_k)\) (steepest descent).
4. **Exact line search:** minimize \(\phi(\alpha) = f(X_k + \alpha Y_k)\) over \(\alpha \ge 0\) using `scipy.optimize.minimize_scalar`.
5. **Update:** \(X_{k+1} = X_k + \alpha^\* Y_k\).

Because \(f\) is a **positive definite quadratic**, the method converges to the unique global minimum for any reasonable starting point.

### Analytical gradient (used in code)

\[
\frac{\partial f}{\partial x_1} = 7x_1 + x_2 - 2x_3 - 5,\quad
\frac{\partial f}{\partial x_2} = x_1 + 8x_2 - x_3 + 15,\quad
\frac{\partial f}{\partial x_3} = -2x_1 - x_2 + 7x_3.
\]

## Code reference

| File | Role |
|------|------|
| `steepest_descent.py` | `f`, `gradient`, `steepest_descent`, and the main run block |

## How to run

```bash
pip install numpy scipy
python steepest_descent.py
```

The script prints an iteration table (`x1`, `x2`, `x3`, `f(X)`, `max|grad|`) and the final optimal point \(X^\*\) with \(f(X^\*)\).

## Relation to other labs

Unlike the **1D** methods in `Golden Section Search`, `Interval Halving Method`, and `Exhaustive Search Method`, steepest descent works in **several variables** and uses **first-order** information (the gradient), not only function values on a grid.
