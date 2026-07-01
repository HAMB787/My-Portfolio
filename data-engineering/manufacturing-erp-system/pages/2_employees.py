import streamlit as st
import requests
import pandas as pd
import plotly.express as px

# 1. ԷՋԻ ԿԱՐԳԱՎՈՐՈՒՄՆԵՐ
st.set_page_config(
    page_title="MFG ERP · Աշխատակիցներ",
    layout="wide",
    page_icon="👥",
    initial_sidebar_state="expanded",
)

API_URL = "http://127.0.0.1:8000"

# 2. PREMIUM CSS
st.markdown("""
<style>
@import url('https://fonts.googleapis.com/css2?family=Rajdhani:wght@500;600;700&family=JetBrains+Mono:wght@400;500&display=swap');

:root {
    --bg-base:      #0d1117;
    --bg-panel:     #161b22;
    --bg-card:      #1c2333;
    --accent:       #00d4aa;
    --accent-dim:   rgba(0, 212, 170, 0.1);
    --border:       #30363d;
    --text-primary: #e6edf3;
    --text-muted:   #7d8590;
    --font-head:    'Rajdhani', sans-serif;
}

[data-testid="stSidebarNav"] { display: none !important; }
.stApp { background-color: var(--bg-base) !important; }

[data-testid="stSidebar"] {
    background: var(--bg-panel) !important;
    border-right: 1px solid var(--border) !important;
}

div[data-testid="stPageLink"] a:hover {
    background-color: var(--accent-dim) !important;
    border-color: var(--accent) !important;
    transform: translateX(5px);
    transition: 0.3s;
}

.main-header {
    font-family: var(--font-head);
    font-size: 2.2rem;
    font-weight: 700;
    color: var(--text-primary);
    text-transform: uppercase;
}

/* Expander-ի ոճավորում (Dark Theme) */
div[data-testid="stExpander"] summary {
    background-color: #161b22 !important;
    border: 1px solid #30363d !important;
    border-radius: 8px !important;
}
div[data-testid="stExpander"] p {
    color: #e6edf3 !important;
    font-weight: 600 !important;
}
div[data-testid="stExpander"] svg {
    fill: #e6edf3 !important;
}

/* Կոճակների ոճ */
div.stButton > button {
    background-color: #00d4aa !important;
    color: #0d1117 !important;
    font-weight: 700 !important;
    border: none !important;
}
div.stButton > button:hover {
    background-color: #00b38f !important;
}
</style>
""", unsafe_allow_html=True)

# 3. ՆԱՎԻԳԱՑԻԱ (SIDEBAR)
with st.sidebar:
    st.markdown("<div style='font-family:Rajdhani; font-size:1.8rem; font-weight:700; color:#00d4aa;'>⚙️ MFG ERP</div>", unsafe_allow_html=True)
    st.markdown("<p style='color:#7d8590; font-size:0.75rem; font-weight:600; letter-spacing:1px;'>ՆԱՎԻԳԱՑԻԱ</p>", unsafe_allow_html=True)
    
    st.page_link("frontend.py", label="📊 ԲԻԶՆԵՍ ՀԱՇՎԵՏՎՈՒԹՅՈՒՆ")
    st.page_link("pages/1_actions.py", label="🪑 ԱՊՐԱՆՔՆԵՐԻ ԿԱՏԱԼՈԳ")
    st.page_link("pages/2_employees.py", label="👥 ԱՇԽԱՏԱԿԻՑՆԵՐ")
    st.page_link("pages/3_customers.py", label="🤝 ՀԱՃԱԽՈՐԴՆԵՐ")
    
    st.markdown("<hr style='border-color:#30363d; margin:20px 0'>", unsafe_allow_html=True)
    if st.button("🔄 ԹԱՐՄԱՑՆԵԼ", use_container_width=True):
        st.cache_data.clear()
        st.rerun()

# 4. ՏՎՅԱԼՆԵՐԻ ԲԵՌՆՈՒՄ
@st.cache_data(ttl=30)
def fetch_employees():
    try:
        r = requests.get(f"{API_URL}/employees")
        return pd.DataFrame(r.json().get('employees', []))
    except: return pd.DataFrame()

@st.cache_data(ttl=30)
def fetch_analytics():
    try:
        r = requests.get(f"{API_URL}/analytics")
        return pd.DataFrame(r.json())
    except: return pd.DataFrame()

df_emp = fetch_employees()
df_sales = fetch_analytics()

# 5. ԲՈՎԱՆԴԱԿՈՒԹՅՈՒՆ
st.markdown("<div class='main-header'>👥 ԱՇԽԱՏԱԿԻՑՆԵՐԻ ԿԱՌԱՎԱՐՈՒՄ</div>", unsafe_allow_html=True)

# --- 🟢 ՆՈՐ: ԱՇԽԱՏԱԿՑԻ ԳՐԱՆՑՈՒՄ ---
with st.expander("➕ Գրանցել Նոր Աշխատակից"):
    c1, c2, c3 = st.columns([2, 2, 1])
    with c1:
        new_f_name = st.text_input("Անուն", placeholder="Օրինակ՝ Գոռ")
    with c2:
        new_l_name = st.text_input("Ազգանուն", placeholder="Օրինակ՝ Վարդանյան")
    with c3:
        st.markdown("<br>", unsafe_allow_html=True) # հավասարեցնում ենք դաշտերի հետ
        if st.button("Գրանցել", use_container_width=True):
            if new_f_name and new_l_name:
                res = requests.post(f"{API_URL}/employees", json={"first_name": new_f_name, "last_name": new_l_name})
                if res.status_code == 200:
                    st.success("Հաջողությամբ գրանցվեց:")
                    st.rerun()
                else:
                    st.error("Սխալ առաջացավ:")
            else:
                st.warning("Լրացրեք բոլոր դաշտերը:")

st.markdown("<hr style='border-color:#30363d;'>", unsafe_allow_html=True)

if df_emp.empty:
    st.warning("Աշխատակիցների տվյալներ չեն գտնվել:")
else:
    col_list, col_perf = st.columns([1, 1])

    with col_list:
        st.markdown("### 📋 Հաստիքացուցակ")
        # 🔴 ՈՒՂՂՈՒՄ: Այժմ ցույց է տալիս ողջ աղյուսակը, ոչ թե միայն 3 սյունակ
        st.dataframe(df_emp, use_container_width=True, hide_index=True)

    with col_perf:
        st.markdown("### 🏆 Վաճառքների Արդյունավետություն")
        if not df_sales.empty:
            perf = df_sales.groupby('manager', as_index=False)['revenue'].sum() # type: ignore
            perf = perf.sort_values(by='revenue', ascending=False) # type: ignore
            
            fig = px.bar(perf, x='revenue', y='manager', orientation='h', 
                         color_discrete_sequence=['#00d4aa'])
            
            fig.update_layout(
                paper_bgcolor="rgba(0,0,0,0)",
                plot_bgcolor="rgba(0,0,0,0)",
                font_color="#7d8590",
                xaxis=dict(gridcolor="#21293a"),
                yaxis=dict(gridcolor="#21293a"),
                margin=dict(l=10, r=10, t=40, b=10)
            )
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("Վաճառքների վիճակագրություն դեռ չկա:")

# 6. FOOTER
st.markdown("<br><hr style='border-color:#30363d;'>", unsafe_allow_html=True)
st.markdown("<div style='text-align:center; color:#484f58; font-family:monospace; font-size:0.7rem;'>ERP SYSTEM · EMPLOYEE MODULE · 2026</div>", unsafe_allow_html=True)