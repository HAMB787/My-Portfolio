import pandas as pd

df = pd.read_csv(r"c:\Users\Администратор\OneDrive\Desktop\listam_data\csv files\Yerevan_RealEstate_FINAL_DATABASE_20260313_2111.csv")

if df.duplicated().any():
    print("The file contains duplicate rows.")
else:
    print("The file does not contain any duplicate rows.")
