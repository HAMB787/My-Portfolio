import streamlit as st
import requests
import base64
import os

# 1. Էջի հիմնական կարգավորումներ
st.set_page_config(page_title="MFG ERP · Ապրանքների Կատալոգ", layout="wide", page_icon="🪑")

API_URL = "http://127.0.0.1:8000"

# 2. Ֆունկցիա՝ տեղական նկարը HTML-ի համար հասանելի դարձնելու համար
def get_image_base64(path):
    if os.path.exists(path):
        with open(path, "rb") as img_file:
            return base64.b64encode(img_file.read()).decode()
    return None

# 3. Ամբողջական CSS ոճավորում
st.markdown("""
<style>
    @import url('https://fonts.googleapis.com/css2?family=Rajdhani:wght@500;600;700&display=swap');

    /* Հեռացնում է Streamlit-ի լռելյայն նավիգացիան */
    [data-testid="stSidebarNav"] { display: none !important; }

    /* Ընդհանուր ֆոն */
    .stApp { background-color: #F8F9FA; }
    
    /* Ապրանքի քարտ */
    .product-card {
        background-color: white;
        border-radius: 20px;
        padding: 20px;
        border: 1px solid #E9ECEF;
        box-shadow: 0 4px 12px rgba(0,0,0,0.03);
        margin-bottom: 20px;
        transition: 0.3s;
    }
    .product-price { color: #2D3436; font-size: 1.5rem; font-weight: 800; margin-top: 10px; }
    .product-name { color: #000000 !important; font-weight: 800; font-size: 1.2rem; margin-bottom: 5px; }
    .stock-label { color: #636E72; font-size: 0.9rem; }

    /* ԳՈՐԾՈՂՈՒԹՅՈՒՆ (Expander) ՍՏԻԼԻԶԱՑԻԱ */
    div[data-testid="stExpander"] summary {
        background-color: #F1F3F5 !important;
        border: 1px solid #E9ECEF !important;
        border-radius: 12px !important;
        padding: 12px 15px !important;
    }
    div[data-testid="stExpander"] p {
        color: #000000 !important;
        font-weight: 700 !important;
        font-size: 1rem !important;
    }

    /* ԿՈՃԱԿՆԵՐԻ ՈՃ (Սև ֆոն) */
    div.stButton > button {
        background-color: #111111 !important;
        color: #FFFFFF !important;
        border-radius: 10px !important;
        font-weight: 700 !important;
        height: 3.5rem;
        border: none !important;
        width: 100%;
    }
    div.stButton > button p { color: #FFFFFF !important; }
    div.stButton > button:hover { background-color: #333333 !important; }

    /* Սպիտակեցված + և - նշաններ */
    div[data-testid="stNumberInput"] button svg {
        fill: white !important;
        stroke: white !important;
        color: white !important;
    }

    /* Sidebar Logo */
    .sidebar-logo {
        font-family: 'Rajdhani', sans-serif;
        font-size: 1.8rem;
        font-weight: 700;
        color: #00d4aa;
        margin-bottom: 5px;
    }
</style>
""", unsafe_allow_html=True)

# 4. Տվյալների ստացում Backend-ից
def fetch_data(endpoint):
    try:
        response = requests.get(f"{API_URL}/{endpoint}")
        if response.status_code == 200:
            data = response.json()
            return data if isinstance(data, list) else data.get(endpoint, [])
    except: return []
    return []

products = fetch_data("products")
customers = fetch_data("customers")
employees = fetch_data("employees")
materials = fetch_data("materials")

# --- ՆԱՎԻԳԱՑԻԱ (SIDEBAR) ---
with st.sidebar:
    st.markdown("<div class='sidebar-logo'>⚙️ MFG ERP</div>", unsafe_allow_html=True)
    st.markdown("<p style='color:#7d8590; font-size:0.75rem; font-weight:600; letter-spacing:1px;'>ՆԱՎԻԳԱՑԻԱ</p>", unsafe_allow_html=True)
    
    st.page_link("frontend.py", label="📊 ԲԻԶՆԵՍ ՀԱՇՎԵՏՎՈՒԹՅՈՒՆ")
    st.page_link("pages/1_actions.py", label="🪑 ԱՊՐԱՆՔՆԵՐԻ ԿԱՏԱԼՈԳ")
    st.page_link("pages/2_employees.py", label="👥 ԱՇԽԱՏԱԿԻՑՆԵՐ")
    st.page_link("pages/3_customers.py", label="🤝 ՀԱՃԱԽՈՐԴՆԵՐ")
    
    st.markdown("<hr style='border-color:#30363d;margin:25px 0'>", unsafe_allow_html=True)
    if st.button("🔄 Թարմացնել Տվյալները", use_container_width=True):
        st.cache_data.clear()
        st.rerun()

# 5. Հիմնական բովանդակություն
if not products:
    st.warning("Տվյալներ չեն գտնվել: Ստուգեք Backend սերվերը:")
else:
    # --- ՎԵՐԵՎԻ ԲԼՈԿՆԵՐ (Պահեստ և Գրանցում) ---
    st.markdown("<h3 style='color: black;'>⚙️ Արագ Գործողություններ</h3>", unsafe_allow_html=True)
    
    col_restock, col_register = st.columns(2)
    
    with col_restock:
        with st.expander("📦 Ավելացնել հումք (Մատակարարում)"):
            if not materials:
                st.warning("Հումք չկա:")
            else:
                mat_map = {m['material_name']: m['material_id'] for m in materials}
                selected_mat = st.selectbox("Հումք", list(mat_map.keys()))
                restock_qty = st.number_input("Քանակ", min_value=1, value=10, key="mat_qty")
                if st.button("📥 Ավելացնել Պահեստում", key="restock_btn"):
                    res = requests.post(f"{API_URL}/restock", json={"material_id": mat_map[selected_mat], "quantity": restock_qty})
                    if res.status_code == 200: st.rerun()

    with col_register:
        with st.expander("➕ Գրանցել Նոր Հաճախորդ / Մենեջեր"):
            reg_type = st.radio("Ի՞նչ եք ցանկանում ավելացնել", ["Հաճախորդ", "Մենեջեր"], horizontal=True)
            
            if reg_type == "Հաճախորդ":
                new_cust = st.text_input("Ընկերության անունը")
                if st.button("Գրանցել Հաճախորդին", use_container_width=True):
                    if new_cust:
                        requests.post(f"{API_URL}/customers", json={"company_name": new_cust})
                        st.success("Գրանցվեց:")
                        st.rerun()
            else:
                c1, c2 = st.columns(2)
                with c1: new_f = st.text_input("Անուն")
                with c2: new_l = st.text_input("Ազգանուն")
                if st.button("Գրանցել Մենեջերին", use_container_width=True):
                    if new_f and new_l:
                        requests.post(f"{API_URL}/employees", json={"first_name": new_f, "last_name": new_l})
                        st.success("Գրանցվեց:")
                        st.rerun()

    st.markdown("<hr style='border-color: #E9ECEF;'>", unsafe_allow_html=True)

    # --- ԿԱՏԱԼՈԳ ԵՎ ՎԱՃԱՌՔ ---
    cust_map = {c['company_name']: c['customer_id'] for c in customers}
    emp_map = {f"{e['first_name']} {e['last_name']}": e['employee_id'] for e in employees}

    st.markdown("<h3 style='color: black;'>🪑 Ապրանքների Կատալոգ</h3>", unsafe_allow_html=True)
    cols = st.columns(3)

    for i, p in enumerate(products):
        with cols[i % 3]:
            img_path = os.path.join("images", f"{p['product_id']}.jpeg")
            img_b64 = get_image_base64(img_path)
            img_src = f"data:image/jpeg;base64,{img_b64}" if img_b64 else "https://via.placeholder.com/400x300?text=No+Image"

            with st.container():
                st.markdown(f"""
                <div class="product-card">
                    <img src="{img_src}" style="width:100%; height:250px; object-fit:cover; border-radius:15px;">
                    <div class="product-price">{p.get('price', p.get('unit_price', 0)):,.0f} ֏</div>
                    <div class="product-name">{p['product_name']}</div>
                    <div class="stock-label">Պահեստում՝ <b>{p['stock_quantity']}</b> հատ</div>
                </div>
                """, unsafe_allow_html=True)
                
                with st.expander("⚙️ Կառավարել Գործողությունը"):
                    qty = st.number_input("Քանակ", min_value=1, value=1, key=f"qty_{p['product_id']}")
                    
                    if not cust_map or not emp_map:
                        st.error("Նախ գրանցեք հաճախորդ և մենեջեր վերևի բլոկից:")
                    else:
                        customer = st.selectbox("Հաճախորդ", list(cust_map.keys()), key=f"cust_{p['product_id']}")
                        employee = st.selectbox("Մենեջեր", list(emp_map.keys()), key=f"emp_{p['product_id']}")

                        b_col1, b_col2 = st.columns(2)
                        with b_col1:
                            if st.button("🛒 Վաճառել", key=f"sell_{p['product_id']}"):
                                res = requests.post(f"{API_URL}/sell", json={
                                    "product_id": p['product_id'], "customer_id": cust_map[customer],
                                    "employee_id": emp_map[employee], "quantity": qty
                                })
                                if res.status_code == 200: st.rerun()
                                else: st.error(res.json().get('detail'))

                        with b_col2:
                            if st.button("🛠 Արտադրել", key=f"man_{p['product_id']}"):
                                res = requests.post(f"{API_URL}/manufacture", json={
                                    "product_id": p['product_id'], "quantity": qty
                                })
                                if res.status_code == 200: st.rerun()
                                else: st.error(res.json().get('detail'))