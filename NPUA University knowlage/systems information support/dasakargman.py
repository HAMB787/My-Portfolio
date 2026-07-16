import numpy as np

# 1. Գործոնների անվանումները (K = 5) - ՆՈՐ ՍՑԵՆԱՐ (Հավելվածի որակի չափանիշներ)
FACTOR_NAMES = [
    "Անվտանգություն և տվյալների պաշտպանություն",
    "Համակարգի արագագործություն",
    "Ինտերֆեյսի հարմարավետություն (UX/UI)",
    "Սպասարկման և պահպանման արժեք",
    "Այլ համակարգերի հետ ինտեգրացիա"
]

# 2. Նոր տվյալներ (K=5 գործոն, N=8 փորձագետ)
# 1-ը ամենակարևորն է, 5-ը՝ ամենաքիչ կարևորը
RAW_DATA = [
    [1, 1, 2, 1, 1, 2, 1, 1], # Գործոն 1 (Անվտանգությունը շատերն ընտրել են որպես #1)
    [2, 3, 1, 2, 3, 1, 2, 2], # Գործոն 2 (Արագագործությունը հիմնականում #2 կամ #3 է)
    [4, 4, 4, 3, 4, 3, 4, 4], # Գործոն 3 (UX/UI-ն հիմնականում #4 է)
    [5, 5, 5, 5, 5, 5, 5, 5], # Գործոն 4 (Արժեքը բոլորը դրել են վերջին տեղում՝ #5)
    [3, 2, 3, 4, 2, 4, 3, 3]  # Գործոն 5 (Ինտեգրացիան տատանվում է մեջտեղում)
]

def run_standard_analysis(factors, data):
    R = np.array(data)
    k, n = R.shape

    # --- Հաշվարկներ սովորական մեթոդով ---
    S_i = np.sum(R, axis=1) 
    S_mean = np.mean(S_i)
    S_sum_sq = np.sum((S_i - S_mean)**2) 

    # Խմբային ռանգերի որոշում
    temp_indices = np.argsort(S_i)
    group_vector = np.zeros(k, dtype=int)
    for rank, idx in enumerate(temp_indices, 1):
        group_vector[idx] = rank

    # tj համընկնումներ (որքանով է փորձագետի կարծիքը համընկնում խմբայինի հետ)
    t_j_list = [int(np.sum(R[:, j] == group_vector)) for j in range(n)]

    # Tj ուղղում կապակցված ռանգերի համար (եթե փորձագետը նույն գնահատականն է տվել մի քանի բանի)
    T_total = 0
    for j in range(n):
        unique, counts = np.unique(R[:, j], return_counts=True)
        T_total += np.sum(counts**3 - counts)
    
    # Կոնկորդացիայի գործակից (Սովորական մեթոդով)
    numerator = 12 * S_sum_sq
    denominator = (n**2 * (k**3 - k)) - (n * T_total)
    W = numerator / denominator if denominator != 0 else 0

    # --- ՏՊՈՒՄ ---
    line = "=" * 115
    print(f"\n{line}")
    print(f"{'ՍՈՎՈՐԱԿԱՆ ԴԱՍԱԿԱՐԳՄԱՆ ՄԵԹՈԴԻ ԱՐԴՅՈՒՆՔՆԵՐ (ՀԱՎԵԼՎԱԾԻ ՈՐԱԿԻ ԳՆԱՀԱՏՈՒՄ)':^115}")
    print(line)

    header = f"{'#':<2} | {'Գործոնի Անվանում':<42} | {'Si':<5} | {'|Si - Smid|':<11} | {'Շեղում^2':<9} | {'Ռանգ':<5}"
    print(header)
    print("-" * 115)

    for i in range(k):
        diff = abs(S_i[i] - S_mean) 
        diff_sq = (S_i[i] - S_mean)**2 
        print(f"{i+1:<2} | {factors[i]:<42} | {S_i[i]:<5.1f} | {diff:<11.1f} | {diff_sq:<9.2f} | {group_vector[i]:<5}")

    print("\n" + line)
    print(f"{'ՓՈՐՁԱԳԵՏՆԵՐԻ tj ՀԱՄԸՆԿՆՈՒՄՆԵՐԸ':^115}")
    print(line)
    
    # Տպում ենք երկու սյունակով
    half = (n + 1) // 2
    for i in range(half):
        p2_idx = i + half
        if p2_idx < n:
            print(f"Փորձագետ {i+1:<2}: tj = {t_j_list[i]:<5} |{' ':^20}| Փորձագետ {p2_idx+1:<2}: tj = {t_j_list[p2_idx]:<5}")
        else:
            print(f"Փորձագետ {i+1:<2}: tj = {t_j_list[i]:<5}")

    print("\n" + line)
    print(f"Շեղումների քառակուսիների գումար (S):  {S_sum_sq:.2f}")
    print(f"Կոնկորդացիայի գործակից (W):           {W:.4f}")
    if W > 0.7:
        print("ԱՐԴՅՈՒՆՔ: Փորձագետների կարծիքները ԽԻՍՏ ՀԱՄԱՁԱՅՆԵՑՎԱԾ ԵՆ:")
    elif W > 0.5:
        print("ԱՐԴՅՈՒՆՔ: Փորձագետների կարծիքները ՄԻՋԻՆ ՀԱՄԱՁԱՅՆԵՑՎԱԾՈՒԹՅՈՒՆ ՈՒՆԵՆ:")
    else:
        print("ԱՐԴՅՈՒՆՔ: Փորձագետների կարծիքները ՀԱՄԱՁԱՅՆԵՑՎԱԾ ՉԵՆ:")
    print(line + "\n")

run_standard_analysis(FACTOR_NAMES, RAW_DATA)