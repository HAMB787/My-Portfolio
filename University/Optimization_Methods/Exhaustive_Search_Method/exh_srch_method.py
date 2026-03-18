#lab 1, ընտրանքներ
import numpy as np
import matplotlib.pyplot as plt

# ՃԻՇՏ ֆունկցիա (ըստ գրքի)
def f(x):
    return 0.25*x**4 + x**2 - 8*x + 12

# Uniform search
def uniform_search(a, b, eps):
    n = max(1, int(np.ceil((b - a) / eps)))
    h = (b - a) / n

    x_values = []
    f_values = []

    for k in range(n + 1):
        xk = a + k*h
        x_values.append(xk)
        f_values.append(f(xk))

    min_index = np.argmin(f_values)

    return n, h, x_values, f_values, x_values[min_index], f_values[min_index]


# === Օրինակ ===
a = 0
b = 2
eps = 0.5

n, h, xs, ys, x_min, f_min = uniform_search(a, b, eps)

print("n =", n)
print("step =", h)

print("\nԱղյուսակ:")
for x, y in zip(xs, ys):
    print(f"x = {x:.1f}, f(x) = {y:.4f}")

print("\nՄոտավոր մինիմում:")
print("x_min =", x_min)
print("f_min =", f_min)

# Գրաֆիկ
x_plot = np.linspace(0, 2, 400)
plt.plot(x_plot, f(x_plot))
plt.scatter(xs, ys, color='red')
plt.scatter(x_min, f_min, color='green')
plt.title("Uniform Search (Corrected)")
plt.grid()
plt.show()