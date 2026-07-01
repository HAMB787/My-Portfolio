import pandas as pd

df = pd.read_csv(r"c:\Users\Администратор\OneDrive\Desktop\listam_data\csv files\Yerevan_RealEstate_FINAL_DATABASE_20260313_2111.csv")
df.drop_duplicates(inplace=True)
df.to_csv(r"c:\Users\Администратор\OneDrive\Desktop\listam_data\csv files\Yerevan_RealEstate_FINAL_DATABASE_20260313_2111_deduped.csv", index=False)
