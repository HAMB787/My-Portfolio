import numpy as np
import matplotlib.pyplot as plt

# --- Configuration ---
A = 0.5
B = 4
EPS = 0.5  # Tolerance: the algorithm stops when (b - a) <= EPS

def f(x):
    return (x - 2) ** 2 + np.sqrt(x)

def golden_section_search(a, b, eps):
    # Golden ratio constants
    phi = (1 + np.sqrt(5)) / 2
    resphi = 2 - phi  # approx 0.3819
    
    # Step 0: Initial points
    x1 = a + resphi * (b - a)
    x2 = b - resphi * (b - a)
    f1, f2 = f(x1), f(x2)
    
    iterations = 0
    while (b - a) > eps:
        iterations += 1
        if f1 < f2:
            b = x2
            x2 = x1
            f2 = f1
            x1 = a + resphi * (b - a)
            f1 = f(x1)
        else:
            a = x1
            x1 = x2
            f1 = f2
            x2 = b - resphi * (b - a)
            f2 = f(x2)
            
    x_star = (a + b) / 2
    return x_star, f(x_star), a, b, iterations

# Execution
x_opt, f_opt, final_a, final_b, steps = golden_section_search(A, B, EPS)

# --- Updated Print Section ---
print(f"Final Interval: [{final_a:.4f}, {final_b:.4f}]")
print(f"Minimum found at x ≈ {x_opt:.4f}")
print(f"Function value at this point f(x) ≈ {f_opt:.4f}") # Ավելացված տողը
print(f"Found after {steps} iterations")

# --- Visualization ---
x_plot = np.linspace(A, B, 400)
plt.figure(figsize=(10, 6))
plt.plot(x_plot, f(x_plot), label="f(x)", color='blue')

# Highlight the final interval [a, b] where the minimum lies
plt.axvspan(final_a, final_b, color='yellow', alpha=0.3, label=f"Final Interval (size <= {EPS})")

# Mark the specific minimum point
plt.scatter(x_opt, f_opt, color='red', zorder=5, label=f"Min at x={x_opt:.3f}")

plt.title("Golden Section Search: Final Uncertainty Interval")
plt.xlabel("x")
plt.ylabel("f(x)")
plt.legend()
plt.grid(True, linestyle='--', alpha=0.6)
plt.show()