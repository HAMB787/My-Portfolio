import cloudscraper
from bs4 import BeautifulSoup
import pandas as pd
import time
import random
import re
import os
import shutil
from datetime import datetime, timedelta

# ==========================================
# ⚙️ SETTINGS
FILE_NAME = r"C:\Users\Администратор\OneDrive\Desktop\listam_data\csv files\Yerevan_RealEstate_FINAL_DATABASE_20260313_2111.csv"
BACKUP_NAME = r"C:\Users\Администратор\OneDrive\Desktop\listam_data\csv files\Yerevan_RealEstate_BACKUP.csv"
MAX_PAGES = 15 # Number of pages to check
# ==========================================

def clean_price_to_usd(price_text, exchange_rate=400):
    if not price_text: return None
    clean_text = price_text.replace(',', '').replace(' ', '')
    match = re.search(r'\d+', clean_text)
    if not match: return None
    numeric_value = int(match.group())
    if '֏' in clean_text: return round(numeric_value / exchange_rate)
    return numeric_value

def extract_inner_date(keyword, text):
    match = re.search(fr'{keyword}\s*(Այսօր|Երեկ|\d{{2}}\.\d{{2}}\.\d{{4}})(?:,\s*(\d{{2}}:\d{{2}}))?', text, re.IGNORECASE)
    if not match: return "" 
    
    d_str = match.group(1).lower()
    t_str = match.group(2) if match.group(2) else ""
    
    today = datetime.now()
    if "այսօր" in d_str:
        base_date = today.strftime('%Y-%m-%d')
    elif "երեկ" in d_str:
        base_date = (today - timedelta(days=1)).strftime('%Y-%m-%d')
    else:
        parts = d_str.split('.')
        base_date = f"{parts[2]}-{parts[1]}-{parts[0]}"
        
    return f"{base_date} {t_str}".strip()

def smart_update_market():
    # 1. Create a backup for safety and load the main database
    if not os.path.isfile(FILE_NAME):
        print("❌ Main database file not found!")
        return

    shutil.copy(FILE_NAME, BACKUP_NAME)
    print(f"📦 Backup created successfully: {BACKUP_NAME}")
    
    # Read the database and convert IDs to string for accurate matching
    df_db = pd.read_csv(FILE_NAME, dtype={'id': str})
    
    scraper = cloudscraper.create_scraper()
    base_url = "https://www.list.am/category/60"
    params = "?n=1%2C2%2C3%2C4%2C5%2C6%2C7%2C8%2C9%2C10%2C13%2C11%2C12"
    
    new_listings = []
    page = 1
    
    print(f"\n🚀 Starting smart update: The database currently has {len(df_db)} listings.")

    try:
        while page <= MAX_PAGES:
            print(f"--- Checking Page {page} ---")
            url = f"{base_url}/{page}{params}"
            
            try:
                time.sleep(random.uniform(0.5, 1.5))
                response = scraper.get(url, timeout=20)
                
                # 🛑 ANTI-BOT PROTECTION HANDLING 🛑
                if response.status_code != 200:
                    print(f" ⚠️ Website blocked the request (Status: {response.status_code}): Waiting 5 sec and moving to the next page...")
                    time.sleep(5)
                    page += 1  # Force move to the next page
                    continue
                
                soup = BeautifulSoup(response.text, "html.parser")
                items = soup.find_all("a", href=True)
                valid_items = [item for item in items if item.get('href', '').startswith('/item/')]
                
                if not valid_items: 
                    print(" 🏁 No listings found on this page. Stopping the search.")
                    break

                for item in valid_items:
                    href = item.get('href', '')
                    clean_id = href.split('?')[0].replace('/item/', '')
                    
                    item_url = f"https://www.list.am/item/{clean_id}"
                    
                    try:
                        time.sleep(random.uniform(0.3, 0.7))
                        item_resp = scraper.get(item_url, timeout=10)
                        item_soup = BeautifulSoup(item_resp.text, "html.parser")
                        
                        for missing_feature in item_soup.find_all(class_="disabled"):
                            missing_feature.decompose()
                            
                        clean_text = item_soup.get_text(" ", strip=True)
                        
                        exact_updated = extract_inner_date('Թարմացվել է', clean_text)
                        
                        title_elem = item.find("div", class_="l")
                        price_elem = item.find("div", class_="p")
                        
                        title = title_elem.get_text(strip=True) if title_elem else ""
                        raw_price = price_elem.get_text(strip=True) if price_elem else ""
                        price_usd = clean_price_to_usd(raw_price)

                        if clean_id in df_db['id'].values:
                            # LOGIC 1. UPDATE EXISTING LISTING
                            idx = df_db.index[df_db['id'] == clean_id][0]
                            old_updated = str(df_db.at[idx, 'date_updated_exact'])
                            
                            if old_updated != exact_updated:
                                df_db.at[idx, 'date_updated_exact'] = exact_updated
                                df_db.at[idx, 'price_usd'] = price_usd
                                df_db.at[idx, 'price_raw'] = raw_price
                                print(f" 🔄 UPDATED TIME/PRICE: {clean_id} | New time: {exact_updated}")
                        else:
                            # LOGIC 2. ADD COMPLETELY NEW LISTING
                            exact_posted = extract_inner_date('Տեղադրված է', clean_text)
                            
                            at_elem = item.find("div", class_="at")
                            at_text = at_elem.get_text(strip=True) if at_elem else ""
                            district = at_text.split(',')[0].strip() if at_text else ""

                            tags_list = [tg.get_text(strip=True) for tg in item.find_all("div", class_="cl") if tg.get_text(strip=True)]
                            for st in ["Գործակալություն", "Շտապ", "Սեփականատեր", "Ստուգված"]:
                                if st in clean_text and st not in tags_list: tags_list.append(st)
                            if not any(x in ["Գործակալություն", "Սեփականատեր"] for x in tags_list): tags_list.append("Սեփականատեր")
                            all_tags_text = ", ".join(tags_list)
                            seller_type = "Գործակալություն" if "Գործակալություն" in all_tags_text else "Սեփականատեր"

                            rooms_match = re.search(r'(\d+)\s*սեն', clean_text.lower())
                            floor_match = re.search(r'(\d+)/(\d+)', clean_text.lower())
                            area_match = re.search(r'(\d+[\.,]?\d*)\s*քմ', clean_text.lower())
                            
                            b_match = re.search(r'Շինության տիպ\s*(Քարե|Պանելային|Մոնոլիտ|Աղյուսե|Կասետային|Փայտե)', clean_text, re.IGNORECASE)
                            r_match = re.search(r'Վերանորոգում\s*(Դիզայներական|Եվրո|Կապիտալ|Կոսմետիկ|Մասնակի|Հին|Զրոյական|Չվերանորոգված)', clean_text, re.IGNORECASE)
                            balc_match = re.search(r'Պատշգամբ\s*(Առկա չէ|Բաց|Փակ)', clean_text, re.IGNORECASE)
                            furn_match = re.search(r'Կահույք\s*(Կահույքով|Առկա չէ|Մասնակի|Համաձայնությամբ)', clean_text, re.IGNORECASE)

                            views_found = [v for v in ['Դեպի բակ', 'Դեպի փողոց', 'Դեպի քաղաք', 'Դեպի այգի', 'Դեպի Արարատ'] if re.search(v, clean_text, re.IGNORECASE)]
                            appliances_found = [a for a in ['Օդորակիչ', 'Սառնարան', 'Սալօջախ', 'Սպասք լվացող մեքենա', 'Լվացքի մեքենա', 'Չորացնող մեքենա'] if re.search(a, clean_text, re.IGNORECASE)]

                            row_data = {
                                "id": clean_id, 
                                "date_posted_exact": exact_posted, 
                                "date_updated_exact": exact_updated, 
                                "seller_type": seller_type, 
                                "tags": all_tags_text, 
                                "title": title, 
                                "price_raw": raw_price, 
                                "price_usd": price_usd, 
                                "district": district,
                                "rooms": rooms_match.group(1) if rooms_match else "", 
                                "area_sqm": area_match.group(1).replace(',', '.') if area_match else "",
                                "floor": floor_match.group(1) if floor_match else "", 
                                "total_floors": floor_match.group(2) if floor_match else "",
                                "build_type": b_match.group(1).capitalize() if b_match else "", 
                                "renovation": r_match.group(1).capitalize() if r_match else "", 
                                "elevator": "Այո" if re.search(r'Վերելակ\s*Առկա է', clean_text, re.IGNORECASE) else "", 
                                "new_build": "Այո" if re.search(r'Նորակառույց\s*Այո', clean_text, re.IGNORECASE) else "", 
                                "domofon": "Այո" if re.search(r'Դոմոֆոն', clean_text, re.IGNORECASE) else "", 
                                "concierge": "Այո" if re.search(r'Դռնապահ', clean_text, re.IGNORECASE) else "", 
                                "playground": "Այո" if re.search(r'Խաղահրապարակ', clean_text, re.IGNORECASE) else "", 
                                "scenic_views": ", ".join(views_found) if views_found else "", 
                                "appliances": ", ".join(appliances_found) if appliances_found else "", 
                                "balcony": balc_match.group(1) if balc_match else "", 
                                "furniture": furn_match.group(1) if furn_match else "", 
                                "url": item_url, 
                                "address": ""
                            }
                            
                            new_listings.append(row_data)
                            print(f" ⚡ NEWLY ADDED: {clean_id} | $ {price_usd}")

                    except Exception as e:
                        print(f" ⚠️ Error extracting data (ID {clean_id}): {e}")

            except Exception as e:
                print(f" ⚠️ Page level error: {e}")
                time.sleep(5)
                
            page += 1 # Move to the next page after a successful step

    except KeyboardInterrupt:
        print("\n⚠️ Process interrupted manually.")

    # 2. FINAL SAVE TO DATABASE
    if new_listings:
        df_new = pd.DataFrame(new_listings)
        df_db = pd.concat([df_db, df_new], ignore_index=True)
        print(f"\n✅ Inserted {len(new_listings)} new listings.")
    
    # Save back to the same file
    df_db.to_csv(FILE_NAME, index=False, encoding='utf-8')
    print(f"✅ Database ({FILE_NAME}) successfully updated and saved.")

if __name__ == "__main__":
    smart_update_market()