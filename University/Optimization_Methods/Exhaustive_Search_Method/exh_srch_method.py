# Lab 1: Exhaustive Search Method
import numpy as np
import matplotlib.pyplot as plt

# Define the interval [A, B] for the search
A = 0.5
B = 4

# Epsilon (not directly used in this version of exhaustive search, but often part of the problem statement)
EPS = 0.5
# N is the number of intervals to divide the search space into.
N = 7

# This is the objective function we want to minimize.
def f(x):
    return (x - 2) ** 2 + np.sqrt(x)

# This function implements the Exhaustive Search Method.
# It finds the minimum of a function f(x) on a given interval [a, b].
def exhaustive_search(a, b, n):
    # The step size 'h' is calculated by dividing the interval [a, b] into 'n' equal parts.
    h = (b - a) / n

    # Lists to store the x coordinates and the corresponding function values f(x).
    x_values = []
    f_values = []

    # This loop iterates from k=0 to n, calculating x_k at each step.
    # x_k starts at 'a' and increases by 'h' in each iteration.
    for k in range(n + 1):
        xk = a + k * h
        x_values.append(xk)
        f_values.append(f(xk))

    # Find the index of the minimum value in the f_values list.
    min_index = np.argmin(f_values)

    # Return the number of intervals, step size, lists of x and f(x) values,
    # and the coordinates (x, f(x)) of the minimum point found.
    return n, h, x_values, f_values, x_values[min_index], f_values[min_index]


# Set the search interval and number of divisions from the global constants.
a = A
b = B
n_intervals = N

# Call the exhaustive search function to find the minimum.
n, h, xs, ys, x_min, f_min = exhaustive_search(a, b, n_intervals)

# Print the results of the search.
print("Number of intervals (n) =", n)
print("Step size (h) =", h)

print("\nCalculated values:")
for x, y in zip(xs, ys):
    print(f"x = {x:.1f}, f(x) = {y:.4f}")

print("\nMinimum point found:")
print("x_min =", x_min)
print("f_min =", f_min)

# --- Plotting the results ---
# Generate a range of x values for a smooth plot of the function.
x_plot = np.linspace(a, b, 400)
# Plot the function f(x).
plt.plot(x_plot, f(x_plot), label="f(x) = (x-2)^2 + sqrt(x)")
# Plot the points that were evaluated by the exhaustive search.
plt.scatter(xs, ys, color="red", label="Evaluated Points")
# Highlight the minimum point found.
plt.scatter(x_min, f_min, color="green", zorder=5, label="Minimum Point")
plt.title("Exhaustive Search Method")
plt.xlabel("x")
plt.ylabel("f(x)")
plt.legend()
plt.grid()
plt.show()
