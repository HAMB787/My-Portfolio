import cloudscraper
from bs4 import BeautifulSoup
import csv
import time
import random
import re
import os
from datetime import datetime, timedelta

# ==========================================
# ⚙️ SETTINGS
START_PAGE = 1  # Change this if the script stops and you want to resume from a specific page
FILE_NAME = "Yerevan_RealEstate_FINAL_DATABASE_20260313_2111.csv" # Your main Power BI database file
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

def scrape_resumable_market():
    scraper = cloudscraper.create_scraper()
    base_url = "https://www.list.am/category/60"
    params = "?n=1%2C2%2C3%2C4%2C5%2C6%2C7%2C8%2C9%2C10%2C13%2C11%2C12&sname=&s=&cmtype=&crc=&price1=&price2=&sq_price1=&sq_price2=&_a5=&_a39=&_a40=&_a85=&_a73=&_a3_1=&_a3_2=&_a37=&_a36=&_a11_1=&_a11_2=&_a47=&_a78=&_a82=&_a77="
    
    seen_ids = set()
    page = START_PAGE
    
    fieldnames = ['id', 'date_posted_exact', 'date_updated_exact', 'seller_type', 'tags', 'title', 'price_raw', 'price_usd', 
                  'district', 'rooms', 'area_sqm', 'floor', 'total_floors', 'build_type', 
                  'renovation', 'elevator', 'new_build', 'domofon', 'concierge', 'playground', 
                  'scenic_views', 'appliances', 'balcony', 'furniture', 'url']

    # Handle file creation or resumption based on START_PAGE
    if START_PAGE == 1:
        print(f"⚠️ Creating a new database: Existing data in '{FILE_NAME}' will be overwritten.")
        with open(FILE_NAME, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
    else:
        file_exists = os.path.isfile(FILE_NAME)
        if file_exists:
            with open(FILE_NAME, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader: seen_ids.add(row['id'])

    print(f"\n🚀 MASS DATA COLLECTION INITIATED (Enhanced V2):")
    
    try:
        while True:
            print(f"--- Opening Main Page {page} ---")
            url = f"{base_url}/{page}{params}"
            
            try:
                time.sleep(random.uniform(0.5, 1.0))
                response = scraper.get(url, timeout=20)
                if response.status_code != 200:
                    print(f" ⚠️ Blocked (Status: {response.status_code}): Waiting 10 seconds...")
                    time.sleep(10)
                    continue
                
                soup = BeautifulSoup(response.text, "html.parser")
                items = soup.find_all("a", href=True)
                valid_items = [item for item in items if item.get('href', '').startswith('/item/')]
                
                if not valid_items: 
                    print(" 🏁 No valid items found. Ending scraping process.")
                    break

                new_items_on_page = 0

                for item in valid_items:
                    href = item.get('href', '')
                    clean_id = href.split('?')[0].replace('/item/', '')
                    
                    if clean_id in seen_ids: continue 
                    seen_ids.add(clean_id)
                    new_items_on_page += 1
                    
                    title_elem = item.find("div", class_="l")
                    price_elem = item.find("div", class_="p")
                    at_elem = item.find("div", class_="at")
                    if not (title_elem and price_elem): continue

                    title = title_elem.get_text(strip=True)
                    raw_price = price_elem.get_text(strip=True)
                    at_text = at_elem.get_text(strip=True) if at_elem else ""
                    
                    price_usd = clean_price_to_usd(raw_price)
                    district = at_text.split(',')[0].strip()

                    tags_list = [tg.get_text(strip=True) for tg in item.find_all("div", class_="cl") if tg.get_text(strip=True)]
                    all_text_content = item.get_text(" ", strip=True)
                    for st in ["Գործակալություն", "Շտապ", "Սեփականատեր", "Ստուգված"]:
                        if st in all_text_content and st not in tags_list: tags_list.append(st)
                    if not any(x in ["Գործակալություն", "Սեփականատեր"] for x in tags_list): tags_list.append("Սեփականատեր")
                    all_tags_text = ", ".join(tags_list)
                    seller_type = "Agency" if "Գործակալություն" in all_tags_text else "Owner"

                    rooms_match = re.search(r'(\d+)\s*սեն', all_text_content.lower())
                    floor_match = re.search(r'(\d+)/(\d+)', all_text_content.lower())
                    area_match = re.search(r'(\d+[\.,]?\d*)\s*քմ', all_text_content.lower())
                    clean_area = area_match.group(1).replace(',', '.') if area_match else ""

                    item_url = f"https://www.list.am/item/{clean_id}"
                    
                    exact_posted, exact_updated = "", ""
                    build_type, renovation = "", ""
                    elevator, new_build, domofon, concierge, playground = "", "", "", "", ""
                    scenic_views, appliances, balcony, furniture = "", "", "", ""

                    try:
                        item_resp = scraper.get(item_url, timeout=10)
                        item_soup = BeautifulSoup(item_resp.text, "html.parser")
                        
                        # Remove disabled/greyed-out features from the parsed HTML
                        for missing_feature in item_soup.find_all(class_="disabled"):
                            missing_feature.decompose()
                            
                        clean_text = item_soup.get_text(" ", strip=True)

                        exact_posted = extract_inner_date('Տեղադրված է', clean_text)
                        exact_updated = extract_inner_date('Թարմացվել է', clean_text)

                        b_match = re.search(r'Շինության տիպ\s*(Քարե|Պանելային|Մոնոլիտ|Աղյուսե|Կասետային|Փայտե)', clean_text, re.IGNORECASE)
                        if b_match: build_type = b_match.group(1).capitalize()

                        r_match = re.search(r'Վերանորոգում\s*(Դիզայներական|Եվրո|Կապիտալ|Կոսմետիկ|Մասնակի|Հին|Զրոյական|Չվերանորոգված)', clean_text, re.IGNORECASE)
                        if r_match: renovation = r_match.group(1).capitalize()

                        if re.search(r'Նորակառույց\s*Այո', clean_text, re.IGNORECASE): new_build = "Այո"
                        if re.search(r'Վերելակ\s*Առկա է', clean_text, re.IGNORECASE): elevator = "Այո"
                        if re.search(r'Դոմոֆոն', clean_text, re.IGNORECASE): domofon = "Այո"
                        if re.search(r'Դռնապահ', clean_text, re.IGNORECASE): concierge = "Այո"
                        if re.search(r'Խաղահրապարակ', clean_text, re.IGNORECASE): playground = "Այո"

                        balc_match = re.search(r'Պատշգամբ\s*(Առկա չէ|Բաց|Փակ)', clean_text, re.IGNORECASE)
                        if balc_match: balcony = balc_match.group(1)

                        furn_match = re.search(r'Կահույք\s*(Կահույքով|Առկա չէ|Մասնակի|Համաձայնությամբ)', clean_text, re.IGNORECASE)
                        if furn_match: furniture = furn_match.group(1)

                        views_found = []
                        for v in ['Դեպի բակ', 'Դեպի փողոց', 'Դեպի քաղաք', 'Դեպի այգի', 'Դեպի Արարատ']:
                            if re.search(v, clean_text, re.IGNORECASE): views_found.append(v)
                        if views_found: scenic_views = ", ".join(views_found)

                        appliances_found = []
                        for a in ['Օդորակիչ', 'Սառնարան', 'Սալօջախ', 'Սպասք լվացող մեքենա', 'Լվացքի մեքենա', 'Չորացնող մեքենա']:
                            if re.search(a, clean_text, re.IGNORECASE): appliances_found.append(a)
                        if appliances_found: appliances = ", ".join(appliances_found)

                    except Exception:
                        pass # Ignore individual item extraction errors to keep script running

                    row_data = {
                        "id": clean_id, "date_posted_exact": exact_posted, "date_updated_exact": exact_updated, 
                        "seller_type": seller_type, "tags": all_tags_text, "title": title, 
                        "price_raw": raw_price, "price_usd": price_usd, "district": district,
                        "rooms": rooms_match.group(1) if rooms_match else "", 
                        "area_sqm": clean_area,
                        "floor": floor_match.group(1) if floor_match else "", 
                        "total_floors": floor_match.group(2) if floor_match else "",
                        "build_type": build_type, "renovation": renovation, 
                        "elevator": elevator, "new_build": new_build, 
                        "domofon": domofon, "concierge": concierge, "playground": playground, 
                        "scenic_views": scenic_views, "appliances": appliances, "balcony": balcony, "furniture": furniture, "url": item_url
                    }
                    
                    with open(FILE_NAME, 'a', newline='', encoding='utf-8') as f:
                        writer = csv.DictWriter(f, fieldnames=fieldnames)
                        writer.writerow(row_data)

                    print(f"  ⚡ Saved: {clean_id} | $ {price_usd} | {district} | Building: {build_type}")
                    time.sleep(random.uniform(0.3, 0.7))

                if new_items_on_page == 0:
                    print(f"🛑 All listings on Page {page} are already in the database. Moving to the next page.")
                
                page += 1

            except Exception as e:
                print(f" ⚠️ Page level error: {e}")
                time.sleep(10)

    except KeyboardInterrupt:
        print(f"\n⚠️ Process stopped manually. You reached PAGE {page}.")

if __name__ == "__main__":
    scrape_resumable_market()