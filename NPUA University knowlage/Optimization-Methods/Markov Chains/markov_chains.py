import numpy as np
import matplotlib.pyplot as plt

# ==========================================
# PROBLEM PARAMETERS (Problem 30 - Warehouse Stock Refill)
# ==========================================
states = ['Full', 'High', 'Medium', 'Low', 'Reorder', 'Shortage']
n_states = len(states)

# Transition Matrix P
P = np.array([
    [0.65, 0.16, 0.05, 0.06, 0.02, 0.06],
    [0.13, 0.59, 0.14, 0.08, 0.03, 0.03],
    [0.05, 0.14, 0.62, 0.08, 0.03, 0.08],
    [0.11, 0.07, 0.10, 0.43, 0.18, 0.11],
    [0.05, 0.04, 0.06, 0.09, 0.62, 0.14],
    [0.02, 0.04, 0.03, 0.06, 0.27, 0.58]
])

start_state = 0  # Index for 'Full' state is 0
length = 420     # Task 1: Length 420
n_sims = 1200    # Task 2: Simulations 1200

# Helper function to simulate a single Markov chain
def simulate_markov_chain(P, start, length):
    path = np.zeros(length, dtype=int)
    path[0] = start
    for t in range(1, length):
        path[t] = np.random.choice(n_states, p=P[path[t-1]])
    return path

print("Simulations started... Please wait:")

# ==========================================
# TASK 1: Simulate and plot (first 5 simulations)
# ==========================================
plt.figure(figsize=(15, 12))
plt.suptitle("Task 1: First 5 Simulations (Length = 420)", fontsize=16, y=0.98)

for i in range(5):
    path = simulate_markov_chain(P, start_state, length)
    plt.subplot(5, 1, i + 1)
    plt.step(range(length), path, where='mid', color='#2980b9', linewidth=1)
    plt.yticks(range(n_states), states)
    plt.ylabel(f"Sim {i+1}", fontweight='bold')
    plt.grid(axis='y', linestyle='--', alpha=0.7)
    plt.xlim(0, length)
    if i == 4:
        plt.xlabel("Steps (Time)")
        
plt.tight_layout()
plt.show()

# ==========================================
# TASK 2: 1200 simulations and empirical shares
# ==========================================
# Generate 1200 simulations
all_paths = np.zeros((n_sims, length), dtype=int)
for i in range(n_sims):
    all_paths[i] = simulate_markov_chain(P, start_state, length)

# Calculate empirical share (frequency of each state across all steps)
unique, counts = np.unique(all_paths, return_counts=True)
pi_empirical = counts / counts.sum()

plt.figure(figsize=(10, 5))
plt.bar(states, pi_empirical, color='#27ae60', alpha=0.8, edgecolor='black')
plt.title("Task 2: Empirical Shares of States (1200 simulations x 420 steps)", fontsize=14)
plt.ylabel("Probability Share")
plt.grid(axis='y', linestyle='--', alpha=0.5)
plt.show()

# ==========================================
# TASK 3: Stationary distribution using 2 methods and comparison
# ==========================================

# -- Method 1: Eigenvalue Method --
# Find eigenvalues and eigenvectors of P^T
eigenvalues, eigenvectors = np.linalg.eig(P.T)
# Find the index of the eigenvalue closest to 1
idx = np.argmin(np.abs(eigenvalues - 1.0))
# Take the corresponding eigenvector and normalize it (so the sum is 1)
pi_eigen = np.real(eigenvectors[:, idx])
pi_eigen = pi_eigen / np.sum(pi_eigen)

# -- Method 2: Solving Linear System (P^T - I)pi = 0 --
# Create the (P^T - I) matrix
A = P.T - np.eye(n_states)
# Since the determinant is 0, replace one row (e.g., the last one) with 1s
A[-1] = np.ones(n_states)
# The constants vector is zeros, except for the last element which is 1 (sum of probabilities = 1)
b = np.zeros(n_states)
b[-1] = 1.0
pi_linear = np.linalg.solve(A, b)

# -- Print the results in the terminal --
print("\n--- RESULTS FOR TASK 3 ---")
print(f"{'State':<10} | {'Empirical':<15} | {'Eigen Method':<15} | {'Linear Sys Method':<15}")
print("-" * 65)
for i in range(n_states):
    print(f"{states[i]:<10} | {pi_empirical[i]:<15.6f} | {pi_eigen[i]:<15.6f} | {pi_linear[i]:<15.6f}")

# -- Plot the comparison chart --
x = np.arange(n_states)
width = 0.25

plt.figure(figsize=(12, 6))
plt.bar(x - width, pi_empirical, width, label='Empirical', color='#27ae60', edgecolor='black')
plt.bar(x, pi_eigen, width, label='Method 1: Eigenvalue', color='#2980b9', edgecolor='black')
plt.bar(x + width, pi_linear, width, label='Method 2: Linear System', color='#f39c12', edgecolor='black')

plt.title("Task 3: Comparison of Stationary Distributions (Empirical vs. Theoretical)", fontsize=14)
plt.ylabel("Probability Share")
plt.xticks(x, states)
plt.legend()
plt.grid(axis='y', linestyle='--', alpha=0.5)
plt.show()