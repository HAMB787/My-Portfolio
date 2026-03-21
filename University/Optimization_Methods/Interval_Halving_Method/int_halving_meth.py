# Lab: Interval Halving Method (also known as Dichotomy Method)
import numpy as np
import matplotlib.pyplot as plt

# Define the initial interval [A, B] for the search.
A = 0.5
B = 4
# EPS is the desired precision (epsilon). The algorithm stops when the interval length is less than EPS.
EPS = 0.5
# DELTA is a small number used to separate the two test points (x1 and x2). It must be smaller than EPS.
DELTA = 0.125

# This is the objective function we want to minimize.
def f(x):
    return (x - 2) ** 2 + np.sqrt(x)

# This function implements the Interval Halving Method.
# It finds the minimum of a unimodal function f(x) on a given interval [a, b].
def interval_halving_method(a, b, eps, delta):
    iteration = 0
    print("--- Interval Halving Method Iterations ---")
    print("k\t a\t\t b\t\t b-a")
    print("-" * 40)

    # The loop continues as long as the interval [a, b] is larger than the desired precision 'eps'.
    while (b - a) > eps:
        print(f"{iteration}\t{a:.4f}\t{b:.4f}\t{(b-a):.4f}")
        # Calculate two points, x1 and x2, near the middle of the current interval.
        # These points are separated by 'delta'.
        x1 = (a + b - delta) / 2
        x2 = (a + b + delta) / 2

        # Compare the function values at x1 and x2 to decide which half of the interval to discard.
        if f(x1) <= f(x2):
            # The minimum is in the left part, so we discard the right part [x2, b].
            b = x2
        else:
            # The minimum is in the right part, so we discard the left part [a, x1].
            a = x1

        iteration += 1
    
    print(f"{iteration}\t{a:.4f}\t{b:.4f}\t{(b-a):.4f}")

    # The minimum is estimated as the midpoint of the final, small interval [a, b].
    x_min = (a + b) / 2
    return x_min, f(x_min), iteration


# Set the initial parameters for the search.
a = A
b = B
eps = EPS
delta = DELTA

# Call the interval halving function to find the minimum.
x_min, f_min, iters = interval_halving_method(a, b, eps, delta)

# Print the final results.
print("\n--- Minimum Point Found ---")
print(f"x* = {x_min:.4f}")
print(f"f(x*) = {f_min:.4f}")
print(f"Iterations = {iters}")


# --- Plotting the results ---
# Generate a range of x values for a smooth plot of the function.
x_plot = np.linspace(A, B, 400)
y_plot = f(x_plot)

# Plot the function f(x).
plt.plot(x_plot, y_plot, label="f(x) = (x-2)^2 + sqrt(x)")
# Highlight the minimum point found by the algorithm.
plt.scatter(x_min, f_min, color="red", s=80, zorder=5, label="Minimum Found")

plt.title("Interval Halving Method")
plt.xlabel("x")
plt.ylabel("f(x)")
plt.legend()
plt.grid()

# Display the plot.
plt.show()
