import numpy as np
import matplotlib.pyplot as plt
import matplotlib.cm as cm
from scipy.optimize import minimize_scalar

# --- Configuration & Constants ---
A = 0.5
B = 4
EPS = 0.5      # Tolerance: the algorithm stops when (b - a) <= EPS
DELTA = 0.125  # A small shift parameter; should satisfy 0 < DELTA < 2*EPS

def f(x):
    """The objective function we want to minimize."""
    return (x - 2) ** 2 + np.sqrt(x)

def dichotomy_method(a, b, eps, delta):
    """
    Implements the Interval Halving (Dichotomy) Method and tracks
    the interval reduction history for visualization.
    """
    iteration = 0
    # 1. Create a history list to store initial 'a' and 'b' values
    history = [(a, b)] 
    
    # Print the table header for logging
    print(f"{'k':<5} | {'a':<10} | {'b':<10} | {'b-a':<10} | {'f(xm)':<10}")
    print("-" * 55)

    while (b - a) > eps:
        # Calculate mid-point purely for logging purposes
        xm = (a + b) / 2
        print(f"{iteration:<5} | {a:<10.4f} | {b:<10.4f} | {(b-a):<10.4f} | {f(xm):<10.4f}")

        # Calculate two symmetric points strictly around the center
        x1 = (a + b - delta) / 2
        x2 = (a + b + delta) / 2

        # Decide which part of the interval to keep
        if f(x1) <= f(x2):
            # Minimum is in the left half, discard the right half [x2, b]
            b = x2
        else:
            # Minimum is in the right half, discard the left half [a, x1]
            a = x1
        
        # 2. Append the newly reduced [a, b] interval to the history
        history.append((a, b))
        iteration += 1

    # Estimate the final minimum as the midpoint of the final tiny interval
    x_star = (a + b) / 2
    f_star = f(x_star)
    
    # Print the final state in the log table
    print(f"{iteration:<5} | {a:<10.4f} | {b:<10.4f} | {(b-a):<10.4f} | {f_star:<10.4f}")
    
    return x_star, f_star, history, iteration

# --- Execution ---
x_min, f_min, history, iters = dichotomy_method(A, B, EPS, DELTA)

# Extract the final 'a' and 'b' values from the last item in the history
final_a, final_b = history[-1]

# --- Analytical / Precise Solution (Comparison) ---
res = minimize_scalar(f, bounds=(A, B), method='bounded')
x_exact = res.x
f_exact = res.fun

# --- Output Results ---
print(f"\n--- Final Result ---")
print("-" * 55)
print(f"Final Interval: [{final_a:.4f}, {final_b:.4f}]")
print(f"Calculated Min at x ≈ {x_min:.4f}, f(x) ≈ {f_min:.4f}")
print(f"Actual Minimum x* ≈ {x_exact:.4f}, f(x*) ≈ {f_exact:.4f}")
print(f"Error |x - x*| = {abs(x_min - x_exact):.6f}")
print(f"Converged in {iters} iterations")

# --- Visualization ---
x_plot = np.linspace(A, B, 400)
y_plot = f(x_plot)

# Increase figure size to fit the horizontal interval lines below
plt.figure(figsize=(10, 8))
plt.plot(x_plot, y_plot, label="Target Function $f(x)$", color='blue', linewidth=2)

# 3. Create a 'viridis' color palette based on the number of iterations
colors = cm.viridis(np.linspace(0, 1, len(history)))
y_min_graph = min(y_plot)

for i, (a_k, b_k) in enumerate(history):
    # Visual Effect 1: Shade the background with a different color for each step
    plt.axvspan(a_k, b_k, color=colors[i], alpha=0.1, zorder=0)
    
    # Visual Effect 2: Draw horizontal tracking lines (|---|) below the curve
    y_pos = y_min_graph - 0.5 - (i * 0.25)
    plt.plot([a_k, b_k], [y_pos, y_pos], marker='|', color=colors[i], 
             linewidth=3, markersize=10, label=f"Iteration {i}")

# Mark the Specific Points
plt.scatter(x_exact, f_exact, color='black', marker='x', s=100, zorder=6, label=f"Exact Min")
plt.scatter(x_min, f_min, color="red", s=150, marker='*', edgecolors='black', zorder=5, label=f"Calculated Min at x ≈ {x_min:.3f}")

plt.title("Dichotomy Method: Iterative Interval Reduction")
plt.xlabel("X")
plt.ylabel("f(X)")

# Move legend outside the plot so it doesn't overlap the lines
plt.legend(loc='upper right', fontsize=9, bbox_to_anchor=(1.25, 1))
plt.grid(True, linestyle='--', alpha=0.6)

plt.tight_layout()
plt.show()
