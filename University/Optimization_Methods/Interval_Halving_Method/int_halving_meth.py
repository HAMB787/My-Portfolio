import numpy as np
import matplotlib.pyplot as plt

# --- Configuration ---
A = 0.5
B = 4
EPS = 0.5
DELTA = 0.125  # Should be 0 < DELTA < 2*EPS

def f(x):
    """Objective function to minimize."""
    return (x - 2) ** 2 + np.sqrt(x)

def dichotomy_method(a, b, eps, delta):
    """
    Implements the Interval Halving (Dichotomy) Method.
    """
    iteration = 0
    print(f"{'k':<5} | {'a':<10} | {'b':<10} | {'b-a':<10} | {'f(xm)':<10}")
    print("-" * 55)

    while (b - a) > eps:
        # Calculate mid-point for logging
        xm = (a + b) / 2
        print(f"{iteration:<5} | {a:<10.4f} | {b:<10.4f} | {(b-a):<10.4f} | {f(xm):<10.4f}")

        # Calculate two symmetric points around the center
        x1 = (a + b - delta) / 2
        x2 = (a + b + delta) / 2

        # Decide which part of the interval to keep
        if f(x1) <= f(x2):
            b = x2
        else:
            a = x1
        
        iteration += 1

    x_star = (a + b) / 2
    f_star = f(x_star)
    
    # Final state
    print(f"{iteration:<5} | {a:<10.4f} | {b:<10.4f} | {(b-a):<10.4f} | {f_star:<10.4f}")
    return x_star, f_star, a, b, iteration

# --- Execution ---
x_min, f_min, final_a, final_b, iters = dichotomy_method(A, B, EPS, DELTA)

print(f"\n--- Final Result ---")
print(f"Minimum at x* ≈ {x_min:.4f}")
print(f"Function value f(x*) ≈ {f_min:.4f}")
print(f"Converged in {iters} iterations")

# --- Visualization ---
x_plot = np.linspace(A, B, 400)
plt.figure(figsize=(10, 6))
plt.plot(x_plot, f(x_plot), label="f(x)", color='blue', alpha=0.7)

# Highlight the final uncertainty interval
plt.axvspan(final_a, final_b, color='green', alpha=0.2, label=f"Final Interval (size <= {EPS})")

# Mark the minimum point
plt.scatter(x_min, f_min, color="red", s=100, marker='*', zorder=5, label=f"Min (x={x_min:.3f})")

plt.title("Dichotomy Method: Search Visualization")
plt.xlabel("x")
plt.ylabel("f(x)")
plt.legend()
plt.grid(True, linestyle='--', alpha=0.5)
plt.show()  