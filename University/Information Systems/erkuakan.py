import numpy as np

# Տվյալները քո տետրի երկրորդ նկարի աղյուսակից (K=4 օբյեկտ, N=8 փորձագետ)
RAW_DATA = [
    [0, 1, 2, 2, 3, 2, 0, 2], # Op 1
    [2, 3, 0, 1, 1, 2, 2, 0], # Op 2
    [3, 1, 1, 0, 2, 2, 3, 1], # Op 3
    [1, 1, 3, 3, 0, 0, 1, 3]  # Op 4
]

def run_pairwise_analysis(data):
    R = np.array(data)
    k, n = R.shape

    # 1. Հաշվում ենք յուրաքանչյուր օբյեկտի ստացած ընդհանուր միավորները (Si)
    S_i = np.sum(R, axis=1) 
    
    # 2. Միջին գումարը և Շեղումների քառակուսիների գումարը (S)
    S_mean = np.mean(S_i)
    S_sum_sq = np.sum((S_i - S_mean)**2) 

    # 3. Խմբային ռանգերի որոշում: 
    # ԵՐԿՈՒԱԿԱՆՈՒՄ շատ միավորն է լավագույնը, ուստի սորտավորում ենք նվազման կարգով [::-1]
    temp_indices = np.argsort(S_i)[::-1]
    group_vector = np.zeros(k, dtype=int)
    for rank, idx in enumerate(temp_indices, 1):
        group_vector[idx] = rank

    # 4. Tj - Կապակցված ռանգերի (կրկնությունների) որոշում
    T_total = 0
    t_j_details = []
    
    for j in range(n):
        unique, counts = np.unique(R[:, j], return_counts=True)
        ties = counts[counts > 1]
        T_j = np.sum(ties**3 - ties) if len(ties) > 0 else 0
        T_total += T_j
        t_j_details.append(T_j)
    
    # 5. Կոնկորդացիայի գործակից (W)
    numerator = 12 * S_sum_sq
    denominator = (n**2 * (k**3 - k)) - (n * T_total)
    W = numerator / denominator if denominator != 0 else 0

    # ================== ՏՊԵԼՈՒ (ՆԿԱՐԵԼՈՒ) ՀԱՏՎԱԾ ==================
    line = "=" * 85
    print(f"\n{line}")
    print(f"{'ԵՐԿՈՒԱԿԱՆ (ԶՈՒՅԳ ԱՌ ԶՈՒՅԳ) ԴԱՍԱԿԱՐԳՄԱՆ ՄԵԹՈԴԻ ԱՐԴՅՈՒՆՔՆԵՐ':^85}")
    print(line)

    # Գլխավոր աղյուսակը
    header = f"{'Օբյեկտ':<8} | {'Si (Գումար)':<12} | {'|Si - Smid|':<12} | {'Շեղում^2':<10} | {'Ռանգ':<5}"
    print(header)
    print("-" * 85)

    for i in range(k):
        diff = abs(S_i[i] - S_mean) 
        diff_sq = (S_i[i] - S_mean)**2 
        print(f"Op {i+1:<5} | {S_i[i]:<12.1f} | {diff:<12.1f} | {diff_sq:<10.2f} | {group_vector[i]:<5}")

    print("\n" + line)
    print(f"{'ՓՈՐՁԱԳԵՏՆԵՐԻ ԿԱՊԱԿՑՎԱԾ ՌԱՆԳԵՐԸ (Tj - ties)':^85}")
    print(line)
    
    tj_str = ""
    for j in range(n):
        tj_str += f"P{j+1}: Tj={t_j_details[j]:<3} | "
    print(tj_str.strip(" | "))

    print("\n" + line)
    print(f"Միջին գումար (a կամ S_mid):             {S_mean:.1f}")
    print(f"Շեղումների քառակուսիների գումար (S):    {S_sum_sq:.2f}")
    print(f"Կապակցվածության ցուցանիշների գումար:    {T_total}")
    
    print(f"\nW = (12 * {S_sum_sq:.2f}) / ({n}^2 * ({k}^3 - {k}) - {n} * {T_total})")
    print(f"Կոնկորդացիայի գործակից (W) =            {W:.4f}")
    
    if W > 0.7:
        print("\nԱՐԴՅՈՒՆՔ: Փորձագետների կարծիքները ԽԻՍՏ ՀԱՄԱՁԱՅՆԵՑՎԱԾ ԵՆ:")
    elif W > 0.5:
        print("\nԱՐԴՅՈՒՆՔ: Փորձագետների կարծիքները ՄԻՋԻՆ ՀԱՄԱՁԱՅՆԵՑՎԱԾՈՒԹՅՈՒՆ ՈՒՆԵՆ:")
    else:
        print("\nԱՐԴՅՈՒՆՔ: Փորձագետների կարծիքները ՀԱՄԱՁԱՅՆԵՑՎԱԾ ՉԵՆ:")
    print(line + "\n")

if __name__ == "__main__":
    run_pairwise_analysis(RAW_DATA)