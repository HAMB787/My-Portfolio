import numpy as np
import matplotlib.pyplot as plt
from scipy.optimize import minimize_scalar

# --- Configuration & Constants ---
A = 0.5  # Start of interval
B = 4    # End of interval
N = 7    # Number of intervals (divisions)
EPS = 0.5 # Error tolerance (epsilon)

# --- Objective Function ---
def f(x):
    """The function we want to minimize."""
    return (x - 2) ** 2 + np.sqrt(x)

# --- Numerical Method: Exhaustive Search ---
def exhaustive_search(a, b, n):
    """
    Implements the Exhaustive Search (Brute Force) method 
    by dividing the interval [a, b] into 'n' equal parts.
    """
    h = (b - a) / n  # Step size
    
    x_values = []
    f_values = []

    # Calculate function values at each grid point
    for k in range(n + 1):
        xk = a + k * h
        x_values.append(xk)
        f_values.append(f(xk))

    # Identify the index of the minimum value
    min_index = np.argmin(f_values)
    
    return n, h, x_values, f_values, x_values[min_index], f_values[min_index]

# --- Execution ---
n, h, xs, ys, x_min_num, f_min_num = exhaustive_search(A, B, N)

# --- Analytical / Precise Solution (Comparison) ---
# Using a bounded scalar minimizer to represent the "Analytical" ground truth
res = minimize_scalar(f, bounds=(A, B), method='bounded')
x_exact = res.x
f_exact = res.fun

# --- Output Results ---
print(f"--- Exhaustive Search (n={n}) ---")
print(f"Step size (h): {h:.4f}")
print(f"Numerical Min: x = {x_min_num:.4f}, f(x) = {f_min_num:.4f}")

print(f"\n--- Precise Solution (Ground Truth) ---")
print(f"Exact Min: x = {x_exact:.4f}, f(x) = {f_exact:.4f}")

print(f"\n--- Accuracy Metrics ---")
print(f"Absolute Error in f(x): {abs(f_min_num - f_exact):.6f}")

# --- Visualization ---
x_plot = np.linspace(A, B, 400)
plt.figure(figsize=(10, 6))

# Plot the continuous function
plt.plot(x_plot, f(x_plot), label="Target Function $f(x)$", color='blue', alpha=0.6)

# Plot the sampling points
plt.scatter(xs, ys, color="red", s=30, label="Sampled Points (Numerical)")

# Highlight the Numerical Minimum found
plt.scatter(x_min_num, f_min_num, color="green", s=100, marker='X', zorder=5, 
            label=f"Numerical Min (x={x_min_num:.2f})")

# Highlight the Exact Minimum
plt.axvline(x_exact, color='black', linestyle='--', alpha=0.5, label="Exact Min Position")

plt.title("Exhaustive Search vs Exact Minimum")
plt.xlabel("x")
plt.ylabel("f(x)")
plt.legend()
plt.grid(True, linestyle='--', alpha=0.7)
plt.show()