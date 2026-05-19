import numpy as np
from scipy.optimize import minimize_scalar

# ---------------------------------------------------------
# Define the objective function f(X)
# ---------------------------------------------------------
def f(x):
    """
    Calculates the value of the objective function.
    f(x1, x2, x3) = 0.5 * (7x1^2 + 2x1x2 - 4x1x3 + 8x2^2 - 2x2x3 + 7x3^2) - 5x1 + 15x2
    """
    x1, x2, x3 = x
    return 0.5 * (7*x1**2 + 2*x1*x2 - 4*x1*x3 + 8*x2**2 - 2*x2*x3 + 7*x3**2) - 5*x1 + 15*x2

# ---------------------------------------------------------
# Define the gradient vector \nabla f(X)
# ---------------------------------------------------------
def gradient(x):
    """
    Calculates the gradient (partial derivatives) of the function at point X.
    """
    x1, x2, x3 = x
    
    # Partial derivatives computed analytically
    df_dx1 = 7*x1 + x2 - 2*x3 - 5
    df_dx2 = x1 + 8*x2 - x3 + 15
    df_dx3 = -2*x1 - x2 + 7*x3
    
    return np.array([df_dx1, df_dx2, df_dx3])

# ---------------------------------------------------------
# Steepest Descent Algorithm
# ---------------------------------------------------------
def steepest_descent(x0, epsilon=1e-3, max_iter=1000):
    """
    Minimizes the function using the Steepest Descent Method with exact line search.
    """
    x = np.array(x0, dtype=float)
    
    
    print(f"{'Iter':<5} | {'x1':<8} | {'x2':<8} | {'x3':<8} | {'f(X)':<10} | {'Gradient [dx1, dx2, dx3]':<28} | {'Max|Grad|':<10}")
    print("-" * 95)
    
    for k in range(max_iter):
        # 1. Calculate gradient at current point
        grad = gradient(x)
        
        # We use the maximum absolute value of partial derivatives for the stopping criterion 
        # (similar to your textbook's requirement <= epsilon)
        max_grad = np.max(np.abs(grad))
        
        grad_str = f"[{grad[0]:.4f}, {grad[1]:.4f}, {grad[2]:.4f}]"
        
        # Print current iteration details (Ավելացրել ենք grad_str փոփոխականը)
        print(f"{k:<5} | {x[0]:<8.4f} | {x[1]:<8.4f} | {x[2]:<8.4f} | {f(x):<10.4f} | {grad_str:<28} | {max_grad:<10.4f}")
        
        # 2. Check stopping condition
        if max_grad <= epsilon:
            print(f"\nSuccess! Convergence reached after {k} iterations.")
            break
            
        # 3. Determine the direction of steepest descent (negative gradient)
        direction = -grad
        
        # 4. Exact Line Search: Find optimal step size alpha > 0
        # This solves: g(alpha) = f(X_k + alpha * direction) -> min
        def g(alpha):
            return f(x + alpha * direction)
            
        # Using SciPy's scalar minimizer to find the best alpha
        res = minimize_scalar(g)
        alpha_opt = res.x
        
        # 5. Calculate next point: X_{k+1} = X_k + alpha * Y_k
        x = x + alpha_opt * direction
        
    return x, f(x)

# ---------------------------------------------------------
# Execution Block
# ---------------------------------------------------------
if __name__ == "__main__":
    # Initial point: X^0 = (0, 2, 1)^T
    x_initial = [0, 2, 1]
    
    # Tolerance level: epsilon = 10^-3
    eps = 1e-3
    
    # Run the optimization
    x_optimal, f_minimum = steepest_descent(x_initial, eps)
    
    # Print the final result
    print("\n" + "="*30)
    print("      FINAL RESULTS      ")
    print("="*30)
    print(f"Optimal Point X* = [{x_optimal[0]:.6f}, {x_optimal[1]:.6f}, {x_optimal[2]:.6f}]")
    print(f"Minimum Value f(X*) = {f_minimum:.6f}")