import numpy as np

def build_matrix(n, edges):
    A = np.zeros((n, n), dtype=int)
    for u, v in edges:
        A[u-1][v-1] = 1
    return A

def print_matrix(name, M):
    n = len(M)
    print("\n" + name)
    print("    ", end="")
    for j in range(1, n+1):
        print(f"{j:3}", end="")
    print()
    print("    " + "---"*n)
    for i in range(n):
        print(f"{i+1:2} |", end="")
        for j in range(n):
            print(f"{M[i][j]:3}", end="")
        print()

def analyze_network(edges, t1_nodes=None, t3_nodes=None, epsilon=0.01):
    if not edges:
        print("\nՍԽԱԼ: Ցանցը դատարկ է (կապեր չեն գտնվել):")
        return

    m = max(max(u, v) for u, v in edges) # Գագաթների քանակ
    r = len(edges)                       # Կապերի քանակ
    
    # --- ԱՎՏՈՄԱՏ ԴԱՍԱԿԱՐԳՈՒՄ ---
    if t1_nodes is None or t3_nodes is None:
        has_out = set(u for u, v in edges)
        has_in = set(v for u, v in edges)
        
        t1 = has_out - has_in  # Միայն դուրս եկող (մուտքեր)
        t3 = has_in - has_out  # Միայն մտնող (ելքեր)
        t2 = has_out & has_in  # Համ մտնող, համ դուրս եկող (միջանկյալ)
    else:
        # Սա աշխատում է միայն 1-ին (դեֆոլտ լեկցիայի) տարբերակի համար
        t1 = set(t1_nodes)
        t3 = set(t3_nodes)
        all_nodes = set(range(1, m + 1))
        t2 = set()
        for node in all_nodes:
            if any(v == node for u, v in edges) and any(u == node for u, v in edges):
                t2.add(node)

    print("\n" + "="*50)
    print("--- 1. ՏԱՐՐԵՐԻ ԴԱՍԱԿԱՐԳՈՒՄ ---")
    print(f"t1 (Մուտքային)  = {len(t1)} հատ: {sorted(list(t1))}")
    print(f"t2 (Միջանկյալ) = {len(t2)} հատ: {sorted(list(t2))}")
    print(f"t3 (Ելքային)   = {len(t3)} հատ: {sorted(list(t3))}")

    t5 = sum(1 for u, v in edges if u in t2 and v in t2)
    t6 = sum(1 for u, v in edges if u in t3 and v in t3)
    
    print(f"t5 (Կապեր t2-ների միջև) = {t5}")
    print(f"t6 (Կապեր t3-ների միջև) = {t6}")

    print("\n--- 2. ՀԻՄՆԱԿԱՆ ԳՈՐԾԱԿԻՑՆԵՐ ---")
    
    K_m = len(t2) / m if m > 0 else 0
    print(f"K_մ (Միջանկյալ տարրերի գործակից) = {len(t2)} / {m} = {K_m:.3f}")

    K_nk = t5 / r if r > 0 else 0
    print(f"K_ն.կ. (Ներքին կապերի գործակից) = {t5} / {r} = {K_nk:.3f}", end="")
    if K_nk < 0.5:
        print(" -> ՑԱԾՐ")
    elif K_nk <= 0.8:
        print(" -> ՄԻՋԻՆ")
    else:
        print(" -> ԲԱՐՁՐ")

    t3_count = len(t3)
    K_krk = (2 * t6) / (t3_count * (t3_count - 1)) if t3_count > 1 else 0.0
    print(f"K_կրկ (Ինֆորմացիայի կրկնության գործակից) = 2*{t6} / ({t3_count}*{t3_count-1}) = {K_krk:.3f}")

    print("\n--- 3. ՄԱՏՐԻՑԱՅԻՆ ՀԱՇՎԱՐԿՆԵՐ ԵՎ K_մ.օ. ---")
    A = build_matrix(m, edges)
    current = A.copy()
    n = 1
    K_so_values = [] 

    while True:
        # Սկզբում տպում ենք և հաշվում ենք պարամետրերը (նույնիսկ եթե մատրիցը 0-ական է)
        print_matrix(f"Տակտ {n} -> A^{n} ՄԱՏՐԻՑ", current)

        t4_columns = [int(x) for x in np.where(np.all(current == 0, axis=0))[0] + 1]
        t4 = len(t4_columns)

        t7 = t4 - n
        K_mo_current = t7 / t4 if t4 > 0 else 0.0
        K_so_values.append(K_mo_current)

        print(f"  t4 = {t4} (զրոյական սյուներ: {t4_columns})")
        print(f"  t7 = {t4} - {n} = {t7}")
        print(f"  K_մ.օ. = {K_mo_current:.4f}")

        # Հետո նոր ստուգում ենք. եթե զրոյական էր, հաշվարկն ավարտում ենք
        if not np.any(current):
            order = n
            break

        current = current @ A
        n += 1

    print(f"\nՀամակարգի կարգը (N) = {order} տակտ")

    print("\n--- 4. ՌԱՑԻՈՆԱԼՈՒԹՅԱՆ ՍՏՈՒԳՈՒՄ ---")
    K_mo_avg = sum(K_so_values) / order if order > 0 else 0
    
    print(f"K_մ.օ. միջին = {K_mo_avg:.4f}")
    
    diff = abs(K_m - K_mo_avg)
    print(f"Ստուգում: |K_մ - K_մ.օ._միջին| <= {epsilon}")
    print(f"|{K_m:.3f} - {K_mo_avg:.4f}| = {diff:.4f}")
    
    if diff <= epsilon:
        print(f"ԱՐԴՅՈՒՆՔ: {diff:.4f} <= {epsilon} -> Բաշխման գործընթացը ՌԱՑԻՈՆԱԼ Է:")
    else:
        print(f"ԱՐԴՅՈՒՆՔ: {diff:.4f} > {epsilon} -> Բաշխման գործընթացը ՌԱՑԻՈՆԱԼ ՉԷ:")
    print("="*50 + "\n")


def main():
    print("Ընտրեք տվյալների մուտքագրման տարբերակը.")
    print("1. Օգտագործել նախնական հաստատուն տվյալները (ըստ քո նկարի)")
    print("2. Մուտքագրել նոր կապեր (ՄԻԱՅՆ ԿԱՊԵՐԸ, մնացածը ավտոմատ է)")
    
    choice = input("\nՁեր ընտրությունը (1 կամ 2): ").strip()
    
    if choice == '1':
        edges = [
            (1, 3), (1, 4), (1, 5), (1, 6),
            (2, 5), (2, 6), (2, 7), (2, 8),
            (3, 14), (3, 15), (3, 13),
            (4, 13), (4, 16), (4, 12),
            (5, 12), (5, 11),
            (6, 11), (6, 20), (6, 10),
            (7, 10), (7, 9),
            (8, 9),
            (14, 17), (12, 18), (11, 16),
            (10, 18), (9, 19), (20, 16)
        ]
        t1_nodes = [1, 2]
        t3_nodes = [13, 15, 16, 17, 18, 19, 20]
        epsilon = 0.01
        analyze_network(edges, t1_nodes, t3_nodes, epsilon)
        
    elif choice == '2':
        edges = []
        print("\nՄուտքագրեք կապերը զույգերով՝ բաժանված բացատով (օրինակ՝ 1 4):")
        print("Ավարտելու համար պարզապես սեղմեք Enter դատարկ տողի վրա:")
        
        while True:
            line = input("Կապ (u v): ").strip()
            if not line or line.lower() == 'done':
                break
            try:
                parts = line.replace(',', ' ').split()
                if len(parts) != 2:
                    print("  Մուտքագրեք ճիշտ 2 թիվ:")
                    continue
                u, v = int(parts[0]), int(parts[1])
                edges.append((u, v))
            except ValueError:
                print("  Սխալ։ Միայն ամբողջ թվեր մուտքագրեք:")
                
        if not edges:
            print("Կապեր չեն մուտքագրվել: Ծրագիրը ավարտվում է:")
            return

        eps_input = input("\nՄուտքագրեք Էպսիլոնի արժեքը (դեֆոլտ 0.1): ").strip()
        try:
            epsilon = float(eps_input) if eps_input else 0.1
        except ValueError:
            epsilon = 0.1
            
        # ՏԵՍ, ԱՅՍՏԵՂ ԼՐԻՎ ԱՎՏՈՄԱՏ Է, ՉԻ ՀԱՐՑՆՈՒՄ T1/T3
        analyze_network(edges, epsilon=epsilon)
            
    else:
        print("Սխալ ընտրություն:")

if __name__ == "__main__":
    main()