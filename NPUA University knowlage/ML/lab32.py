import numpy as np

# 1. Ուսուցանող հավաքածու (Train - № 1-8 ավտոմեքենաներ)
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

# 3. Կարգավորված ռեգրեսիայի իրականացում (Ridge)
A = np.dot(X_train.T, X_train)
C_vec = np.dot(X_train.T, y_train)

# Կարգավորման հաստատուն (C)
C_const = 10 

# Տետրի օրինակով C-ն գումարում ենք գլխավոր անկյունագծի ԲՈԼՈՐ տարրերին
I = np.eye(A.shape[0])
A_ridge = A + C_const * I

# Լուծում ենք համակարգը կարգավորված մատրիցով
w_ridge = np.linalg.solve(A_ridge, C_vec)

# 4. ՈՒՍՈՒՑՄԱՆ (TRAIN) բազմության վրա որակի գնահատում
y_pred_train = np.dot(X_train, w_ridge)

# MSE-ի հաշվարկ TRAIN-ի համար
mse_train = np.mean((y_train - y_pred_train)**2)

# R-squared-ի հաշվարկ TRAIN-ի համար
y_mean_train = np.mean(y_train)
ss_res_train = np.sum((y_train - y_pred_train)**2)
ss_tot_train = np.sum((y_train - y_mean_train)**2)
r2_train = 1 - (ss_res_train / ss_tot_train)

# 5. Արդյունքների արտածում
print("--- Առաջադրանք 1.2 (Ridge Regression, C=10) ---")
print(f"Կարգավորված գործակիցներ (W): {np.round(w_ridge, 4)}")

print(f"\nՄոդելի որակը (TRAIN բազմության վրա):")
print(f"MSE: {mse_train:.2f}")
print(f"R^2: {r2_train:.4f}")

print(f"\nԹեստային կանխատեսումներ №9 և №10 մեքենաների համար:")
y_pred_test = np.dot(X_test, w_ridge)
for i, p in enumerate(y_pred_test):
    print(f"Մեքենա №{i+9}: Կանխատեսված = {p:.2f} հազ. $, Իրական = {y_test[i]} հազ. $")

# 6. Կանխատեսում 3 նոր օբյեկտի համար
X_new = np.array([
    [1, 4, 5, 2.2, 5],   # Նոր մեքենա 1
    [1, 15, 25, 1.4, 2], # Նոր մեքենա 2
    [1, 2, 2, 3.0, 4]    # Նոր մեքենա 3
])
new_preds = np.dot(X_new, w_ridge)

print(f"\nԿանխատեսում 3 նոր մեքենաների համար:")
for i, p in enumerate(new_preds):
    print(f"Նոր մեքենա {i+1}: {p:.2f} հազ. $")