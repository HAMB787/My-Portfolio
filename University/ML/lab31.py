import numpy as np

# 1. Ուսուցանող հավաքածու (Train - № 1-8)
# Սյունակներն են՝ [Ազատ անդամ (1), Տարիք, Վազք, Շարժիչ, Վիճակ]
X_train = np.array([
    [1, 5, 8, 2.0, 4],
    [1, 2, 3, 2.5, 5],
    [1, 10, 15, 1.6, 3],
    [1, 7, 10, 2.0, 4],
    [1, 1, 2, 3.5, 5],
    [1, 12, 18, 1.5, 2],
    [1, 4, 6, 2.0, 4],
    [1, 8, 12, 2.4, 3]
])
y_train = np.array([21, 31, 8, 13, 37, 2, 23, 15])

# 2. Թեստային հավաքածու (Test - № 9-10)
X_test = np.array([
    [1, 3, 5, 1.8, 5],
    [1, 6, 9, 3.0, 4]
])
y_test = np.array([26, 23])

# 3. Ամենափոքր Քառակուսիների Մեթոդի (ԱՔՄ) իրականացում
# Հաշվում ենք A մատրիցը և C վեկտորը (A*W = C)
A = np.dot(X_train.T, X_train)
C_vec = np.dot(X_train.T, y_train)

# Լուծում ենք գծային հավասարումների համակարգը W-ի համար
w = np.linalg.solve(A, C_vec)

# 4. Ուսուցման (Train) բազմության որակի գնահատում
y_pred_train = np.dot(X_train, w)

# MSE-ի հաշվարկ TRAIN-ի վրա
mse_train = np.mean((y_train - y_pred_train)**2)

# R-squared-ի հաշվարկ TRAIN-ի վրա
y_mean_train = np.mean(y_train)
ss_res_train = np.sum((y_train - y_pred_train)**2)
ss_tot_train = np.sum((y_train - y_mean_train)**2)
r2_train = 1 - (ss_res_train / ss_tot_train)

# 5. Արդյունքների արտածում
print("--- Առաջադրանք 1.1 (ԱՔՄ) ---")
print(f"Գործակիցներ (W): {np.round(w, 4)}")

print(f"\nՈւսուցման (Train) բազմության որակը:")
print(f"MSE: {mse_train:.2f}")
print(f"R^2: {r2_train:.4f}")

print(f"\nԹեստային կանխատեսումներ:")
y_pred_test = np.dot(X_test, w)
for i, p in enumerate(y_pred_test):
    print(f"Օբյեկտ №{i+9}: {p:.2f} հազ. $ (Իրական: {y_test[i]})")

# 6. Կանխատեսում 3 նոր օբյեկտի համար
X_new = np.array([
    [1, 4, 5, 2.2, 5],   # Նոր մեքենա 1
    [1, 15, 25, 1.4, 2], # Նոր մեքենա 2
    [1, 2, 2, 3.0, 4]    # Նոր մեքենա 3
])
new_preds = np.dot(X_new, w)

print(f"\nԿանխատեսում 3 նոր օբյեկտների համար:")
for i, p in enumerate(new_preds):
    print(f"Նոր օբյեկտ {i+1}: {p:.2f} հազ. $")