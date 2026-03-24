import numpy as np
import matplotlib.pyplot as plt
import matplotlib.cm as cm

# --- Configuration & Constants ---
A = 0.5
B = 4
EPS = 0.5  # Tolerance: the algorithm stops when (b - a) <= EPS

def f(x):
    """The objective function we want to minimize."""
    return (x - 2) ** 2 + np.sqrt(x)

def golden_section_search(a, b, eps):
    """
    Implements the Golden Section Search method and tracks 
    the interval reduction history for visualization.
    """
    # Golden ratio constants
    phi = (1 + np.sqrt(5)) / 2
    resphi = 2 - phi  
    
    # 1. Create a history list to store 'a' and 'b' values at each step
    history = [(a, b)] 
    
    # Step 0: Initial internal points
    x1 = a + resphi * (b - a)
    x2 = b - resphi * (b - a)
    f1, f2 = f(x1), f(x2)
    
    # --- TABLE HEADER ---
    print(f"{'k':<3} | {'a':<8} | {'b':<8} | {'x1':<8} | {'x2':<8} | {'f(x1)':<9} | {'f(x2)':<9}")
    print("-" * 70)
    
    iterations = 0
    # Print Step 0
    print(f"{iterations:<3} | {a:<8.4f} | {b:<8.4f} | {x1:<8.4f} | {x2:<8.4f} | {f1:<9.6f} | {f2:<9.6f}")
    
    while (b - a) > eps:
        iterations += 1
        if f1 < f2:
            # The minimum is to the left; discard the right section
            b = x2
            x2 = x1
            f2 = f1
            x1 = a + resphi * (b - a)
            f1 = f(x1)
        else:
            # The minimum is to the right; discard the left section
            a = x1
            x1 = x2
            f1 = f2
            x2 = b - resphi * (b - a)
            f2 = f(x2)
            
        # 2. After each step, append the new [a, b] interval to the history
        history.append((a, b)) 
        
        # Print current iteration values
        print(f"{iterations:<3} | {a:<8.4f} | {b:<8.4f} | {x1:<8.4f} | {x2:<8.4f} | {f1:<9.6f} | {f2:<9.6f}")
            
    # Estimate the final minimum as the midpoint of the final interval
    x_star = (a + b) / 2
    return x_star, f(x_star), history, iterations

# --- Execution ---
x_opt, f_opt, history, steps = golden_section_search(A, B, EPS)

# Extract the final 'a' and 'b' values from the last item in the history
final_a, final_b = history[-1]

# --- Output Results ---
print("-" * 70)
print(f"Final Interval: [{final_a:.4f}, {final_b:.4f}]")
print(f"Minimum found at x ≈ {x_opt:.4f}")
print(f"Function value at this point f(x) ≈ {f_opt:.4f}") 
print(f"Found after {steps} iterations")

# --- Visualization ---
x_plot = np.linspace(A, B, 400)
y_plot = f(x_plot)

# Increase figure size slightly to accommodate the horizontal lines below the graph
plt.figure(figsize=(10, 8)) 
plt.plot(x_plot, y_plot, label="Target Function $f(x)$", color='blue', linewidth=2)

# 3. Create a color palette matching the length of our history
colors = cm.plasma(np.linspace(0, 1, len(history)))
y_min_graph = min(y_plot)

for i, (a_k, b_k) in enumerate(history):
    # Visual Effect 1: Shade the background with slight transparency for each step
    plt.axvspan(a_k, b_k, color=colors[i], alpha=0.1, zorder=0)
    
    # Visual Effect 2: Draw horizontal lines (|---|) below the graph to show the narrowing interval
    y_pos = y_min_graph - 0.5 - (i * 0.25) 
    plt.plot([a_k, b_k], [y_pos, y_pos], marker='|', color=colors[i], 
             linewidth=3, markersize=10, label=f"Iteration {i}")

# Mark the specific minimum point found by the algorithm
plt.scatter(x_opt, f_opt, color='red', s=100, zorder=5, label=f"Min at x ≈ {x_opt:.3f}")

plt.title("Golden Section Search: Iterative Interval Reduction")
plt.xlabel("x")
plt.ylabel("f(x)")

# Place the legend in a convenient location outside the main plotting area
plt.legend(loc='upper right', fontsize=9, bbox_to_anchor=(1.25, 1))
plt.grid(True, linestyle='--', alpha=0.6)

plt.tight_layout()
plt.show()