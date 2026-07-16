import pandas as pd
import clickhouse_connect

print("1. Կարդում ենք CSV ֆայլը...")
csv_path = r'C:\Users\Администратор\OneDrive\Desktop\listam_data\csv files\Yerevan_RealEstate_FINAL_DATABASE_20260313_2111.csv'
df = pd.read_csv(csv_path)

print("2. Տվյալների ֆորմատավորում ClickHouse-ի համար...")
# Եթե CSV-ի մեջ կա ավելորդ ինդեքսի սյունակ (օրինակ Unnamed: 0), հեռացնում ենք
if 'Unnamed: 0' in df.columns:
    df = df.drop(columns=['Unnamed: 0'])

# Բոլոր սյունակները ստիպողաբար դարձնում ենք տեքստ (String), բացի price_usd-ից
for col in df.columns:
    if col != 'price_usd':
        df[col] = df[col].fillna('').astype(str)

# price_usd-ն դարձնում ենք հատուկ pandas Nullable Integer, որը ClickHouse-ը կհասկանա
if 'price_usd' in df.columns:
    df['price_usd'] = pd.to_numeric(df['price_usd'], errors='coerce').astype('Int32')

print("3. Միանում ենք ClickHouse-ին...")
client = clickhouse_connect.get_client(host='localhost', port=8123, username='default', password='my_password')
print("4. Մաքրում ենք հին տվյալները բազայից (TRUNCATE)...")
client.command('TRUNCATE TABLE default.listam_real_estate')

print("5. Նոր տվյալները լցնում ենք բազա...")
client.insert_df('listam_real_estate', df)