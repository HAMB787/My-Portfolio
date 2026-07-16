import numpy as np
import matplotlib.pyplot as plt
from scipy.optimize import minimize_scalar

# --- Configuration & Constants ---
A = 0.5  # Start of interval
B = 4    # End of interval
N = 7    # Number of intervals (divisions)

# --- Objective Function ---
def f(x):
    """The function we want to minimize."""
    return (x - 2) ** 2 + np.sqrt(x)

# --- Numerical Method: Exhaustive Search ---
def exhaustive_search(a, b, n):
    """
    Implements the Exhaustive Search method.
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
    
    return x_values, f_values, min_index

# --- Execution ---
xs, ys, min_index = exhaustive_search(A, B, N)
x_min_num = xs[min_index]
f_min_num = ys[min_index]

# --- Analytical / Precise Solution (Comparison) ---
res = minimize_scalar(f, bounds=(A, B), method='bounded')
x_exact = res.x
f_exact = res.fun

# --- Output Results (Formatted like the reference image) ---
print(f"{'i':<3} | {'x_i':<8} | {'f(x_i)':<10}")
print("-" * 35)

for i in range(len(xs)):
    marker = "<-- Min" if i == min_index else ""
    print(f"{i:<3} | {xs[i]:<8.4f} | {ys[i]:<9.6f} {marker}")

print("-" * 35)
print(f"Calculated X_min = {x_min_num:.4f}, f(X_min) = {f_min_num:.6f}")
print(f"Actual minimum x* = {x_exact:.6f}, f(x*) = {f_exact:.6f}")
print(f"Error |X_min - x*| = {abs(x_min_num - x_exact):.6f}")

# --- Visualization (Styled like the reference image) ---
x_plot = np.linspace(A, B, 400)
plt.figure(figsize=(9, 7))

# Plot the continuous function (Pink line)
plt.plot(x_plot, f(x_plot), color='pink', linewidth=2.5, label="Target Function $f(x)$")

# Plot the evaluated sampling points (Blue dots)
plt.plot(xs, ys, 'o', color='blue', markersize=7, label="Evaluated Points")

# Highlight the Actual Minimum (Red star with black edge)
plt.scatter(x_exact, f_exact, color="red", edgecolors='black', s=250, 
            marker='*', zorder=5, label="Actual Minimum")

# Highlight the Calculated Minimum (Blue star with black edge)
plt.scatter(x_min_num, f_min_num, color="blue", edgecolors='black', s=250, 
            marker='*', zorder=5, label="Calculated Minimum")

# Add straight black lines for X and Y axes for better mathematical representation
plt.axhline(0, color='black', linewidth=1)
plt.axvline(0, color='black', linewidth=1)

# Title and Labels
plt.title("Function Minimum Search via Exhaustive Method")
plt.xlabel("X")
plt.ylabel("f(X)")

# Legend and Grid
plt.legend(loc='upper center', bbox_to_anchor=(0.5, 0.95), shadow=True)
plt.grid(True, linestyle='--', alpha=0.5)

# Show the plot
plt.tight_layout()
plt.show()