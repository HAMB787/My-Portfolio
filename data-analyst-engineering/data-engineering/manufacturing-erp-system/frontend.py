"""
Manufacturing ERP · Business Intelligence Dashboard
Premium Dark Theme · Full Analytics & Navigation Optimized
"""

import streamlit as st
import requests
import pandas as pd
import plotly.express as px
from datetime import datetime
from typing import Any, Dict

# ─── ԷՋԻ ԿԱՐԳԱՎՈՐՈՒՄՆԵՐ ─────────────────────────────────────────────
st.set_page_config(
    page_title="MFG ERP · Բիզնես Հաշվետվություն",
    layout="wide",
    page_icon="📊",
    initial_sidebar_state="expanded",
)

API_URL = "http://127.0.0.1:8000"

# ─── PREMIUM CSS ՈՃԱՎՈՐՈՒՄ (Ներառյալ Նավիգացիայի թաքցնումը) ──────────
st.markdown("""
<style>
@import url('https://fonts.googleapis.com/css2?family=Rajdhani:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&family=Nunito+Sans:wght@300;400;600&display=swap');

:root {
    --bg-base:      #0d1117;
    --bg-panel:     #161b22;
    --bg-card:      #1c2333;
    --accent:       #00d4aa;
    --accent-dim:   rgba(0, 212, 170, 0.1);
    --border:       #30363d;
    --text-primary: #e6edf3;
    --text-muted:   #7d8590;
    --text-dim:     #484f58;
    --font-head:    'Rajdhani', sans-serif;
}

/* Հեռացնում է Streamlit-ի լռելյայն նավիգացիոն ցուցակը */
[data-testid="stSidebarNav"] {
    display: none !important;
}

html, body, [class*="css"] {
    font-family: 'Nunito Sans', sans-serif !important;
    background-color: var(--bg-base) !important;
    color: var(--text-primary) !important;
}

.stApp { background-color: var(--bg-base) !important; }

/* Sidebar Premium Design */
[data-testid="stSidebar"] {
    background: var(--bg-panel) !important;
    border-right: 1px solid var(--border) !important;
}

.sidebar-logo {
    font-family: var(--font-head);
    font-size: 1.8rem;
    font-weight: 700;
    letter-spacing: 2px;
    color: var(--accent);
    margin-bottom: 2px;
}

.sidebar-sub {
    font-family: 'JetBrains Mono';
    font-size: 0.6rem;
    color: var(--text-muted);
    letter-spacing: 3px;
    text-transform: uppercase;
    margin-bottom: 20px;
}

/* Sidebar Navigation Buttons Hover Effect */
div[data-testid="stPageLink"] a {
    border-radius: 10px !important;
    transition: all 0.3s ease !important;
    border: 1px solid transparent !important;
}
div[data-testid="stPageLink"] a:hover {
    background-color: var(--accent-dim) !important;
    border-color: var(--accent) !important;
    transform: translateX(5px);
}

/* Header Titles */
.main-header {
    font-family: var(--font-head);
    font-size: 2.2rem;
    font-weight: 700;
    letter-spacing: 2px;
    color: var(--text-primary);
    text-transform: uppercase;
    margin-bottom: 0px;
}
.sub-header {
    font-family: 'JetBrains Mono';
    font-size: 0.75rem;
    color: var(--accent);
    letter-spacing: 4px;
    margin-bottom: 20px;
}

/* KPI Cards */
.kpi-card {
    background: var(--bg-card);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 22px;
    transition: transform 0.2s, border-color 0.2s;
}
.kpi-card:hover {
    border-color: var(--accent);
    transform: translateY(-3px);
}

.h-divider {
    height: 1px;
    background: linear-gradient(90deg, var(--accent), var(--border) 70%, transparent);
    margin: 25px 0;
    border: none;
}
</style>
""", unsafe_allow_html=True)

# ─── PLOTLY THEME ──────────────────────────────────────────────────
CHART_THEME: Dict[str, Any] = {
    "paper_bgcolor": "rgba(0,0,0,0)",
    "plot_bgcolor": "rgba(0,0,0,0)",
    "font": {"family": "Rajdhani", "color": "#7d8590"},
    "xaxis": {"gridcolor": "#21293a", "linecolor": "#30363d"},
    "yaxis": {"gridcolor": "#21293a", "linecolor": "#30363d"},
}

# ─── ՏՎՅԱԼՆԵՐԻ ԲԵՌՆՈՒՄ ──────────────────────────────────────────
@st.cache_data(ttl=30)
def load_products():
    try:
        r = requests.get(f"{API_URL}/products", timeout=5)
        if r.status_code == 200:
            data = r.json()
            return pd.DataFrame(data if isinstance(data, list) else data.get("products", []))
    except: pass
    return pd.DataFrame()

@st.cache_data(ttl=30)
def load_materials():
    try:
        r = requests.get(f"{API_URL}/materials", timeout=5)
        if r.status_code == 200:
            data = r.json()
            return pd.DataFrame(data if isinstance(data, list) else data.get("materials", []))
    except: pass
    return pd.DataFrame()

@st.cache_data(ttl=30)
def load_analytics():
    try:
        r = requests.get(f"{API_URL}/analytics", timeout=5)
        if r.status_code == 200:
            df = pd.DataFrame(r.json())
            if not df.empty and 'date' in df.columns:
                df['date'] = pd.to_datetime(df['date'])
            return df
    except: pass
    return pd.DataFrame()

df_prod = load_products()
df_mat = load_materials()
df_sales = load_analytics()

# ─── ՍԱՅԴԲԱՐ (SIDEBAR) ──────────────────────────────────────────
with st.sidebar:
    st.markdown("<div class='sidebar-logo'>⚙️ MFG ERP</div>", unsafe_allow_html=True)
    st.markdown("<p style='color:#7d8590; font-size:0.75rem; font-weight:600; letter-spacing:1px; margin-left:5px;'>ՆԱՎԻԳԱՑԻԱ</p>", unsafe_allow_html=True)
    
    # Ավելացրու այս երկու նոր տողը.
    st.page_link("frontend.py", label="📊 ԲԻԶՆԵՍ ՀԱՇՎԵՏՎՈՒԹՅՈՒՆ")
    st.page_link("pages/1_actions.py", label="🪑 ԱՊՐԱՆՔՆԵՐԻ ԿԱՏԱԼՈԳ")
    st.page_link("pages/2_employees.py", label="👥 ԱՇԽԱՏԱԿԻՑՆԵՐ")   # 🆕 ՆՈՐ
    st.page_link("pages/3_customers.py", label="🤝 ՀԱՃԱԽՈՐԴՆԵՐ")   # 🆕 ՆՈՐ
    
    st.markdown("<hr style='border-color:#30363d;margin:25px 0'>", unsafe_allow_html=True)
    if st.button("🔄 ԹԱՐՄԱՑՆԵԼ ՏՎՅԱԼՆԵՐԸ", use_container_width=True):
        st.cache_data.clear()
        st.rerun()
    st.markdown(f"<div style='color:#484f58; font-size:0.65rem; text-align:center;'>Թարմացվել է: {datetime.now():%H:%M:%S}</div>", unsafe_allow_html=True)

# ─── ԳԼԽԱԳԻՐ (HEADER) ──────────────────────────────────────────
col_title, col_stamp = st.columns([3, 1])
with col_title:
    st.markdown("<div class='main-header'>ԲԻԶՆԵՍ ՀԱՇՎԵՏՎՈՒԹՅՈՒՆ</div>", unsafe_allow_html=True)
    st.markdown("<div class='sub-header'>ԻՐԱԿԱՆ ԺԱՄԱՆԱԿԻ ՎԵՐԼՈՒԾՈՒԹՅՈՒՆ · OLTP ՄԻԱՑՎԱԾ</div>", unsafe_allow_html=True)
with col_stamp:
    st.markdown(f"<div style='text-align:right; color:#484f58; font-family:monospace; margin-top:15px'>{datetime.now():%Y-%m-%d · %H:%M}</div>", unsafe_allow_html=True)

st.markdown("<hr class='h-divider'>", unsafe_allow_html=True)

# ─── ԾԱՆՈՒՑՈՒՄՆԵՐ ──────────────────────────────────────────────
if not df_prod.empty and "stock_quantity" in df_prod.columns:
    critical_prod = df_prod[df_prod["stock_quantity"] == 0]
    for _, row in critical_prod.iterrows():
        st.error(f"⛔ ՊԱՀԵՍՏԸ ԴԱՏԱՐԿ Է · **{row['product_name']}** — 0 հատ։")

# ─── KPI ՄԵՏՐԻԿԱՆԵՐ ────────────────────────────────────────────
total_revenue = sum(df_sales['revenue']) if not df_sales.empty and 'revenue' in df_sales.columns else 0.0
total_items_sold = sum(df_sales['quantity']) if not df_sales.empty and 'quantity' in df_sales.columns else 0

warehouse_val = 0.0
if not df_prod.empty:
    price_col = 'price' if 'price' in df_prod.columns else 'unit_price'
    if price_col in df_prod.columns and 'stock_quantity' in df_prod.columns:
        warehouse_val = sum(df_prod["stock_quantity"] * df_prod[price_col])

top_manager = "Չկա տվյալ"
if not df_sales.empty and 'manager' in df_sales.columns and 'revenue' in df_sales.columns:
    manager_totals = df_sales.groupby('manager', as_index=False).agg({'revenue': 'sum'})
    manager_totals = manager_totals.sort_values(by=['revenue'], ascending=False) # type: ignore
    if not manager_totals.empty:
        top_manager = str(manager_totals.iloc[0]['manager'])

st.markdown(f"""
<div class="kpi-grid" style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 15px;">
  <div class="kpi-card">
    <div style="color:#7d8590; font-size:0.7rem; letter-spacing:1px; text-transform:uppercase; margin-bottom:8px;">Ընդհանուր Եկամուտ</div>
    <div style="color:#00d4aa; font-size:2rem; font-weight:700; font-family:'Rajdhani';">{total_revenue:,.0f} ֏</div>
  </div>
  <div class="kpi-card">
    <div style="color:#7d8590; font-size:0.7rem; letter-spacing:1px; text-transform:uppercase; margin-bottom:8px;">Պահեստի Արժեք</div>
    <div style="color:#f7931e; font-size:2rem; font-weight:700; font-family:'Rajdhani';">{warehouse_val:,.0f} ֏</div>
  </div>
  <div class="kpi-card">
    <div style="color:#7d8590; font-size:0.7rem; letter-spacing:1px; text-transform:uppercase; margin-bottom:8px;">Վաճառված Քանակ</div>
    <div style="color:#6ea8fe; font-size:2rem; font-weight:700; font-family:'Rajdhani';">{total_items_sold:,} հատ</div>
  </div>
  <div class="kpi-card">
    <div style="color:#7d8590; font-size:0.7rem; letter-spacing:1px; text-transform:uppercase; margin-bottom:8px;">Լավագույն Մենեջեր</div>
    <div style="color:#e05c5c; font-size:1.6rem; font-weight:700; font-family:'Rajdhani';">{top_manager}</div>
  </div>
</div>
""", unsafe_allow_html=True)

st.markdown("<br>", unsafe_allow_html=True)

# ─── ԳՐԱՖԻԿՆԵՐ ────────────────────────────────────────────────
if not df_sales.empty and 'date' in df_sales.columns:
    col_line, col_pie = st.columns([2, 1])

    with col_line:
        daily_rev = df_sales.groupby('date', as_index=False).agg({'revenue': 'sum'})
        fig_line = px.area(daily_rev, x='date', y='revenue', color_discrete_sequence=["#00d4aa"])
        fig_line.update_layout(**CHART_THEME) # type: ignore
        fig_line.update_layout(title="Եկամտի Դինամիկա", margin=dict(l=10, r=10, t=40, b=10))
        st.plotly_chart(fig_line, use_container_width=True)

    with col_pie:
        prod_rev = df_sales.groupby('product_name', as_index=False).agg({'revenue': 'sum'})
        fig_pie = px.pie(prod_rev, names='product_name', values='revenue', hole=0.5,
                         color_discrete_sequence=["#00d4aa","#f7931e","#6ea8fe","#e05c5c"])
        fig_pie.update_layout(**CHART_THEME) # type: ignore
        fig_pie.update_layout(title="Եկամուտ ըստ Ապրանքի", margin=dict(l=10, r=10, t=40, b=10))
        st.plotly_chart(fig_pie, use_container_width=True)

# ─── ՄԵՆԵՋԵՐՆԵՐԻ ԳՐԱՖԻԿ ԵՎ ԱՂՅՈՒՍԱԿ ────────────────────────────
st.markdown("<br>", unsafe_allow_html=True)
if not df_sales.empty:
    col_bar, col_table = st.columns([1, 1])
    
    with col_bar:
        manager_sales = df_sales.groupby('manager', as_index=False).agg({'revenue': 'sum'})
        manager_sales = manager_sales.sort_values(by=['revenue'], ascending=True) # type: ignore
        fig_bar = px.bar(manager_sales, x='revenue', y='manager', orientation='h', color_discrete_sequence=["#6ea8fe"])
        fig_bar.update_layout(**CHART_THEME) # type: ignore
        fig_bar.update_layout(title="Մենեջերների Աշխատանքը", margin=dict(l=10, r=10, t=40, b=10))
        st.plotly_chart(fig_bar, use_container_width=True)

    with col_table:
        st.markdown("<div style='font-family:Rajdhani; font-size:1.1rem; font-weight:600; color:#7d8590; margin-bottom:10px;'>ՎԵՐՋԻՆ ՎԱՃԱՌՔՆԵՐ</div>", unsafe_allow_html=True)
        recent = df_sales[['date', 'product_name', 'quantity', 'revenue', 'manager']].sort_values(by=['date'], ascending=False).head(6) # type: ignore
        recent['date'] = recent['date'].dt.strftime('%Y-%m-%d')
        st.dataframe(recent, use_container_width=True, hide_index=True)

# ─── ՊԱՀԵՍՏԻ ՄՆԱՑՈՐԴՆԵՐ (ԱՂՅՈՒՍԱԿՆԵՐ) ─────────────────────────
st.markdown("<hr class='h-divider'>", unsafe_allow_html=True)
col_p, col_m = st.columns(2)

with col_p:
    st.markdown("<div style='font-family:Rajdhani; font-size:1.1rem; font-weight:600; color:#7d8590; margin-bottom:10px;'>ՊԱՏՐԱՍՏԻ ԱՐՏԱԴՐԱՆՔ</div>", unsafe_allow_html=True)
    if not df_prod.empty:
        st.dataframe(df_prod[['product_name', 'stock_quantity', 'price']], use_container_width=True, hide_index=True)

with col_m:
    st.markdown("<div style='font-family:Rajdhani; font-size:1.1rem; font-weight:600; color:#7d8590; margin-bottom:10px;'>ՀՈՒՄՔԻ ՄՆԱՑՈՐԴՆԵՐ</div>", unsafe_allow_html=True)
    if not df_mat.empty:
        # Այստեղ օգտագործում ենք քո բազայի ճիշտ սյունակի անունը՝ stock_quantity
        st.dataframe(df_mat[['material_name', 'stock_quantity']], use_container_width=True, hide_index=True)

# ─── FOOTER ──────────────────────────────────────────────────
st.markdown("<hr class='h-divider'>", unsafe_allow_html=True)
st.markdown("""
<div style='font-family:monospace; font-size:0.65rem; color:#484f58; text-align:center; padding-bottom:20px'>
BUSINESS INTELLIGENCE SYSTEM · PRESET 2026 · DEVELOPED BY HAMBARDZUM
</div>
""", unsafe_allow_html=True)