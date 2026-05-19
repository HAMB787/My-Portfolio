import numpy as np

# 1. Գործոնների անվանումները (K = 5) - Ըստ dasakargman.py-ի
FACTOR_NAMES = [
    "Անվտանգություն և տվյալների պաշտպանություն",
    "Համակարգի արագագործություն",
    "Ինտերֆեյսի հարմարավետություն (UX/UI)",
    "Սպասարկման և պահպանման արժեք",
    "Այլ համակարգերի հետ ինտեգրացիա"
]

# 2. Սկզբնական ռանգերը dasakargman.py-ից (1-ից 5 տեղերը)
RANK_DATA = [
    [1, 1, 2, 1, 1, 2, 1, 1], # Գործոն 1
    [2, 3, 1, 2, 3, 1, 2, 2], # Գործոն 2
    [4, 4, 4, 3, 4, 3, 4, 4], # Գործոն 3
    [5, 5, 5, 5, 5, 5, 5, 5], # Գործոն 4
    [3, 2, 3, 4, 2, 4, 3, 3]  # Գործոն 5
]

def run_pairwise_analysis(factors, rank_data):
    # Երկուական (Զույգ առ զույգ) մեթոդում մենք հաշվում ենք "հաղթանակների" (միավորների) քանակը:
    # Քանի որ ունենք 5 գործոն, ամենաբարձր 1-ին ռանգը նշանակում է հաղթանակ մյուս 4-ի նկատմամբ:
    # Հետևաբար միավորներ = K - Ռանգ
    k = len(factors)
    R_ranks = np.array(rank_data)
    n = R_ranks.shape[1]
    
    # Ձևափոխում ենք ռանգերը զույգ առ զույգ համեմատության միավորների:
    R = k - R_ranks 
    
    # --- Հաշվարկներ ԵՐԿՈՒԱԿԱՆ մեթոդով ---
    S_i = np.sum(R, axis=1) 
    S_mean = np.mean(S_i)
    S_sum_sq = np.sum((S_i - S_mean)**2) 

    # Խմբային ռանգերի որոշում:
    # Զույգ առ զույգ մեթոդում ՇԱՏ միավորն է լավագույնը, ուստի սորտավորում ենք նվազման կարգով [::-1]
    temp_indices = np.argsort(S_i)[::-1]
    group_vector = np.zeros(k, dtype=int)
    for rank, idx in enumerate(temp_indices, 1):
        group_vector[idx] = rank

    # Tj ուղղում կապակցված ռանգերի համար (Ties)
    T_total = 0
    t_j_details = []
    for j in range(n):
        unique, counts = np.unique(R[:, j], return_counts=True)
        ties = counts[counts > 1]
        T_j = np.sum(ties**3 - ties) if len(ties) > 0 else 0
        T_total += T_j
        t_j_details.append(T_j)
    
    # Կոնկորդացիայի գործակից (W)
    numerator = 12 * S_sum_sq
    denominator = (n**2 * (k**3 - k)) - (n * T_total)
    W = numerator / denominator if denominator != 0 else 0

    # --- ՏՊՈՒՄ ---
    line = "=" * 115
    print(f"\n{line}")
    print(f"{'ԵՐԿՈՒԱԿԱՆ (ԶՈՒՅԳ ԱՌ ԶՈՒՅԳ) ԴԱՍԱԿԱՐԳՄԱՆ ՄԵԹՈԴԻ ԱՐԴՅՈՒՆՔՆԵՐ':^115}")
    print(line)

    header = f"{'#':<2} | {'Գործոնի Անվանում':<42} | {'Si(միավոր)':<10} | {'|Si - Smid|':<11} | {'Շեղում^2':<9} | {'Ռանգ':<5}"
    print(header)
    print("-" * 115)

    for i in range(k):
        diff = abs(S_i[i] - S_mean) 
        diff_sq = (S_i[i] - S_mean)**2 
        print(f"{i+1:<2} | {factors[i]:<42} | {S_i[i]:<10.1f} | {diff:<11.1f} | {diff_sq:<9.2f} | {group_vector[i]:<5}")

    print("\n" + line)
    print(f"{'ՓՈՐՁԱԳԵՏՆԵՐԻ ԿԱՊԱԿՑՎԱԾ ՌԱՆԳԵՐԸ (Tj - ties)':^115}")
    print(line)
    
    half = (n + 1) // 2
    for i in range(half):
        p2_idx = i + half
        if p2_idx < n:
            print(f"Փորձագետ {i+1:<2}: Tj = {t_j_details[i]:<5} |{' ':^20}| Փորձագետ {p2_idx+1:<2}: Tj = {t_j_details[p2_idx]:<5}")
        else:
            print(f"Փորձագետ {i+1:<2}: Tj = {t_j_details[i]:<5}")

    print("\n" + line)
    print(f"Միջին գումար (S_mid):                 {S_mean:.1f}")
    print(f"Շեղումների քառակուսիների գումար (S):  {S_sum_sq:.2f}")
    print(f"Կապակցվածության ցուցանիշների գումար:  {T_total}")
    print(f"Կոնկորդացիայի գործակից (W):           {W:.4f}")
    
    if W > 0.7:
        print("ԱՐԴՅՈՒՆՔ: Փորձագետների կարծիքները ԽԻՍՏ ՀԱՄԱՁԱՅՆԵՑՎԱԾ ԵՆ:")
    elif W > 0.5:
        print("ԱՐԴՅՈՒՆՔ: Փորձագետների կարծիքները ՄԻՋԻՆ ՀԱՄԱՁԱՅՆԵՑՎԱԾՈՒԹՅՈՒՆ ՈՒՆԵՆ:")
    else:
        print("ԱՐԴՅՈՒՆՔ: Փորձագետների կարծիքները ՀԱՄԱՁԱՅՆԵՑՎԱԾ ՉԵՆ:")
    print(line + "\n")

if __name__ == "__main__":
    run_pairwise_analysis(FACTOR_NAMES, RANK_DATA)
