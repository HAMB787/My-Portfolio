import math

def solve_sand_distribution():
    b = [10, 15, 5, 8, 12, 7, 13]  
    a1 = 30  
    a2 = 40  
    
    c1 = [13, 18, 15, 10, 16, 12, 14]
    c2 = [14, 12, 17, 8, 20, 14, 13]
    
    alpha1 = [0.1, 0.09, 0.08, 0.07, 0.1, 0.12, 0.1]
    alpha2 = [0.08, 0.1, 0.07, 0.12, 0.09, 0.11, 0.06]

    n = len(b) 
    
    dp = [[float('inf')] * (a1 + 1) for _ in range(n + 1)]
    parent = [[0] * (a1 + 1) for _ in range(n + 1)]

    dp[n][0] = 0  

    for k in range(n - 1, -1, -1):
        for s in range(a1 + 1):
            for x1 in range(min(s, b[k]) + 1):
                x2 = b[k] - x1  
                
                cost = c1[k] * (1 - math.exp(-alpha1[k] * x1)) + \
                       c2[k] * (1 - math.exp(-alpha2[k] * x2))
                
                total_cost = cost + dp[k+1][s - x1]
                
                if total_cost < dp[k][s]:
                    dp[k][s] = total_cost
                    parent[k][s] = x1

    x1_opt = []
    x2_opt = []
    costs_opt = []
    current_s = a1  
    
    for k in range(n):
        best_x1 = parent[k][current_s]
        best_x2 = b[k] - best_x1
        
        c_val = c1[k] * (1 - math.exp(-alpha1[k] * best_x1)) + \
                c2[k] * (1 - math.exp(-alpha2[k] * best_x2))
                
        x1_opt.append(best_x1)
        x2_opt.append(best_x2)
        costs_opt.append(c_val)
        
        current_s -= best_x1  

    return dp[0][a1], x1_opt, x2_opt, costs_opt



if __name__ == "__main__":
    min_z, res_x1, res_x2, res_costs = solve_sand_distribution()

    print("=" * 65)
    print(f"{'Շին. օբյեկտ':<15} | {'1-ին հանք':<10} | {'2-րդ հանք':<10} | {'Ծախս (L_j)':<15}")
    print("-" * 65)
    for i in range(7):
        print(f"Շենք {i+1:<9} | {res_x1[i]:<6} տ | {res_x2[i]:<6} տ | {res_costs[i]:.4f}")
    print("-" * 65)
    print(f"{'ԸՆԴԱՄԵՆԸ':<15} | {sum(res_x1):<6} տ | {sum(res_x2):<6} տ | {min_z:.4f}")
    print("=" * 65)