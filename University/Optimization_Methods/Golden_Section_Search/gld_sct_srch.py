# Lab: Golden Section Search Method
import numpy as np
import matplotlib.pyplot as plt

# Define the initial interval [A, B] for the search.
A = 0.5
B = 4
# Epsilon, a tolerance for the interval length (not used in this iteration-based implementation).
EPS = 0.5
# N is the number of iterations to perform.
N = 7

# This is the objective function we want to minimize.
def f(x):
    return (x - 2) ** 2 + np.sqrt(x)

# This function implements the Golden Section Search algorithm.
# It finds the minimum of a unimodal function f(x) on a given interval [a, b].
def golden_section_search(a, b, iterations=N):
    # The golden ratio constants.
    # r1 is approximately (3 - sqrt(5)) / 2
    # r2 is approximately (sqrt(5) - 1) / 2, which is the golden ratio conjugate (1/phi)
    r1 = 0.3819
    r2 = 0.6180

    print("--- Golden Section Search Iterations ---")
    print("k\t a\t\t b\t\t x1\t\t x2\t\t f(x1)\t\t f(x2)")
    print("-" * 70)

    # The loop runs for a fixed number of iterations to narrow down the interval.
    for k in range(iterations):
        # Calculate two interior points, x1 and x2, using the golden ratio constants.
        x1 = a + r1 * (b - a)
        x2 = a + r2 * (b - a)

        # Evaluate the function at the interior points.
        f1 = f(x1)
        f2 = f(x2)

        # Print the values for the current iteration in a formatted table.
        print(f"{k}\t{a:.4f}\t{b:.4f}\t{x1:.4f}\t{x2:.4f}\t{f1:.4f}\t{f2:.4f}")

        # The core of the algorithm: reduce the search interval.
        # If f(x1) is greater than f(x2), the minimum cannot be in the interval [a, x1].
        # So, we update 'a' to be x1 for the next iteration.
        if f1 > f2:
            a = x1
        # Otherwise, the minimum cannot be in the interval [x2, b].
        # So, we update 'b' to be x2 for the next iteration.
        else:
            b = x2

    # After the iterations, the minimum is estimated as the midpoint of the final interval [a, b].
    x_star = (a + b) / 2
    f_star = f(x_star)

    print("\n--- Minimum Point Found ---")
    print(f"x* = {x_star:.4f}")
    print(f"f(x*) = {f_star:.4f}")

    return x_star, f_star


# --- Execution ---
# Call the golden section search function with the initial interval and number of iterations.
x_star, f_star = golden_section_search(A, B, N)


# --- Plotting the results ---
# Generate a range of x values for a smooth plot of the function.
x = np.linspace(A, B, 400)
y = f(x)

# Plot the function f(x).
plt.plot(x, y, label="f(x) = (x-2)^2 + sqrt(x)")
# Highlight the minimum point found by the algorithm.
plt.scatter(x_star, f_star, color="red", s=80, zorder=5, label="Minimum Found")

plt.title("Golden Section Search Method")
plt.xlabel("x")
plt.ylabel("f(x)")
plt.legend()
plt.grid()

# Display the plot.
plt.show()
