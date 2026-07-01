import streamlit as st
import requests
import pandas as pd

st.set_page_config(page_title="MFG ERP · Հաճախորդներ", layout="wide")
API_URL = "http://127.0.0.1:8000"

st.markdown("<style>[data-testid='stSidebarNav'] { display: none !important; } .stApp { background-color: #0d1117; }</style>", unsafe_allow_html=True)

with st.sidebar:
    st.markdown("<div style='color:#00d4aa; font-size:1.8rem; font-weight:700;'>⚙️ MFG ERP</div>", unsafe_allow_html=True)
    st.page_link("frontend.py", label="📊 ԲԻԶՆԵՍ ՀԱՇՎԵՏՎՈՒԹՅՈՒՆ")
    st.page_link("pages/1_actions.py", label="🪑 ԱՊՐԱՆՔՆԵՐԻ ԿԱՏԱԼՈԳ")
    st.page_link("pages/2_employees.py", label="👥 ԱՇԽԱՏԱԿԻՑՆԵՐ")
    st.page_link("pages/3_customers.py", label="🤝 ՀԱՃԱԽՈՐԴՆԵՐ")

st.markdown("<h1 style='color:white;'>🤝 Հաճախորդների Բազա (CRM)</h1>", unsafe_allow_html=True)

try:
    cust_data = requests.get(f"{API_URL}/customers").json().get('customers', [])
    if cust_data:
        df_cust = pd.DataFrame(cust_data)
        
        # Ցուցադրում ենք որպես պրեմիում աղյուսակ
        st.markdown("### Գործընկեր Ընկերություններ")
        st.dataframe(df_cust, use_container_width=True, hide_index=True)
        
        # Կարող ենք ավելացնել նաև վիճակագրություն
        st.info(f"Ընդհանուր գրանցված հաճախորդներ՝ {len(df_cust)}")
except:
    st.error("Backend-ի հետ կապ չկա։")