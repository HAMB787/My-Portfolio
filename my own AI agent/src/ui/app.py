"""Professional Data AI Agent — redesigned UI."""

from __future__ import annotations

import sys
from pathlib import Path

# Setup paths
ROOT = Path(__file__).resolve().parent.parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import plotly.express as px
import plotly.graph_objects as go
import streamlit as st

# Imports (assuming these exist in your project structure)
from config.settings import OLLAMA_MODEL, RAW_DIR
from src.engine.query_loop import run_agent_turn
from src.engine.report import generate_report
from src.memory.business_context import load_business_context, save_business_context
from src.tools.db import list_tables, query_df
from src.tools.load_dataset import load_file_into_table
from src.tools.profiling import classify_columns, profile_table, row_count

# ─────────────────────────────────────────── page config
st.set_page_config(
    page_title="Data AI Agent",
    page_icon="✦", # Switched to a more modern spark icon
    layout="wide",
    initial_sidebar_state="collapsed",
)

# ─────────────────────────────────────────── modern design tokens
ACCENT     = "#2563eb"   # Modern Google/Gemini style blue
ACCENT2    = "#8b5cf6"   # Deep elegant purple for gradients
SUCCESS    = "#10b981"   # Soft emerald
WARNING    = "#f59e0b"   # Warm amber
SURFACE_1  = "#09090b"   # Deepest background (almost black)
SURFACE_2  = "#18181b"   # Card / panel background (zinc-900)
SURFACE_3  = "#27272a"   # Input / hover states (zinc-800)
BORDER     = "#3f3f4680" # Semi-transparent borders for softer look
TEXT_PRI   = "#f4f4f5"   # Primary text (zinc-50)
TEXT_SEC   = "#a1a1aa"   # Muted text (zinc-400)


def hex_rgba(hex_color: str, alpha: float) -> str:
    """Plotly-safe rgba string (Plotly rejects 8-digit #RRGGBBAA hex)."""
    h = hex_color.lstrip("#")
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return f"rgba({r}, {g}, {b}, {alpha})"

st.markdown(f"""
<style>
/* ── reset & base ──────────────────────────────────── */
html, body, [data-testid="stAppViewContainer"] {{
    background-color: {SURFACE_1};
    font-family: 'Inter', 'Google Sans', system-ui, sans-serif;
    color: {TEXT_PRI};
}}
[data-testid="stAppViewContainer"] > .main .block-container {{
    padding: 2rem 2.5rem 5rem;
    max-width: 1200px; /* Slightly narrower for better reading length */
}}
[data-testid="stSidebar"] {{ display: none; }}

/* ── hide default Streamlit chrome ─────────────────── */
#MainMenu, footer, header {{ visibility: hidden; }}
[data-testid="stToolbar"] {{ display: none; }}

/* ── header band ───────────────────────────────────── */
.agent-header {{
    display: flex;
    align-items: center;
    gap: 1.2rem;
    padding: 1rem 0 2rem;
    border-bottom: 1px solid {BORDER};
    margin-bottom: 2rem;
}}
.agent-logo {{
    font-size: 2.2rem;
    background: linear-gradient(135deg, #60a5fa, {ACCENT2});
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    font-weight: 400; /* Lighter weight for modern feel */
}}
.agent-name {{
    font-size: 1.4rem;
    font-weight: 600;
    color: {TEXT_PRI};
    letter-spacing: -0.5px;
}}
.agent-meta {{
    font-size: 0.8rem;
    color: {TEXT_SEC};
    display: flex;
    align-items: center;
    gap: 6px;
    margin-top: 4px;
}}
.status-dot {{
    display: inline-block;
    width: 8px; height: 8px;
    background: {SUCCESS};
    border-radius: 50%;
    box-shadow: 0 0 8px {SUCCESS}80;
}}

/* ── tabs ───────────────────────────────────────────── */
[data-testid="stTabs"] [role="tablist"] {{
    background: transparent;
    border-bottom: 1px solid {BORDER};
    gap: 2rem;
    margin-bottom: 2rem;
    padding-bottom: 0;
}}
[data-testid="stTabs"] [role="tab"] {{
    background: transparent;
    border: none;
    border-bottom: 2px solid transparent;
    border-radius: 0;
    padding: 0.5rem 0.2rem;
    font-size: 0.95rem;
    font-weight: 500;
    color: {TEXT_SEC};
    transition: all 0.2s ease;
}}
[data-testid="stTabs"] [role="tab"][aria-selected="true"] {{
    color: {TEXT_PRI};
    border-bottom: 2px solid {ACCENT};
}}
[data-testid="stTabs"] [role="tab"]:hover:not([aria-selected="true"]) {{
    color: {TEXT_PRI};
}}

/* ── cards ──────────────────────────────────────────── */
.kpi-card {{
    background: {SURFACE_2};
    border: 1px solid {BORDER};
    border-radius: 16px;
    padding: 1.5rem;
    position: relative;
    transition: transform 0.2s, box-shadow 0.2s;
}}
.kpi-card:hover {{ 
    transform: translateY(-2px);
    box-shadow: 0 8px 24px rgba(0,0,0,0.2);
}}
.kpi-value {{
    font-size: 2rem;
    font-weight: 700;
    color: {TEXT_PRI};
    letter-spacing: -1px;
}}
.kpi-label {{
    font-size: 0.8rem;
    font-weight: 500;
    color: {TEXT_SEC};
    margin-top: 8px;
}}

/* ── section labels ─────────────────────────────────── */
.section-label {{
    font-size: 0.75rem;
    font-weight: 600;
    letter-spacing: 0.5px;
    text-transform: uppercase;
    color: {TEXT_SEC};
    margin-bottom: 0.8rem;
}}

/* ── chat messages (Redesigned like modern AI) ──────── */
[data-testid="stChatMessage"] {{
    background: transparent !important;
    border: none !important;
    padding: 1.5rem 1rem !important;
}}
/* AI message styling */
[data-testid="stChatMessage"][data-testid*="assistant"] {{
    border-bottom: 1px solid {BORDER} !important;
    border-radius: 0 !important;
}}
/* User message styling - distinct bubble */
[data-testid="stChatMessage"][data-testid*="user"] {{
    background: {SURFACE_2} !important;
    border-radius: 16px !important;
    margin: 1rem 0 !important;
    padding: 1rem 1.5rem !important;
}}
[data-testid="stChatInputContainer"] > div {{
    background: {SURFACE_2} !important;
    border: 1px solid {BORDER} !important;
    border-radius: 24px !important;
    padding: 0.2rem 1rem !important;
}}
[data-testid="stChatInputContainer"]:focus-within > div {{
    border-color: {ACCENT} !important;
    box-shadow: 0 0 0 1px {ACCENT} !important;
}}

/* ── suggestion chips ───────────────────────────────── */
.chip {{
    background: transparent;
    border: 1px solid {BORDER};
    border-radius: 100px;
    padding: 0.5rem 1rem;
    font-size: 0.85rem;
    color: {TEXT_SEC};
    cursor: pointer;
    transition: all 0.2s;
    display: inline-block;
    margin: 0 0.4rem 0.6rem 0;
}}
.chip:hover {{
    background: {SURFACE_3};
    color: {TEXT_PRI};
    border-color: {TEXT_SEC};
}}

/* ── buttons & inputs ───────────────────────────────── */
[data-testid="stButton"] > button {{
    border-radius: 100px !important;
    font-weight: 500 !important;
    border: 1px solid {BORDER} !important;
    background: {SURFACE_2} !important;
}}
.primary-btn > button {{
    background: {ACCENT} !important;
    border-color: {ACCENT} !important;
    color: white !important;
}}
[data-testid="stFileUploader"] {{
    background: {SURFACE_2} !important;
    border: 1px dashed {BORDER} !important;
    border-radius: 16px !important;
}}

/* ── dataframe ──────────────────────────────────────── */
[data-testid="stDataFrame"] {{
    border-radius: 12px !important;
}}

/* ── misc ───────────────────────────────────────────── */
hr {{ border-color: {BORDER}; margin: 2rem 0; }}
.js-plotly-plot .plotly .bg {{ fill: transparent !important; }}
</style>
""", unsafe_allow_html=True)

# ─────────────────────────────────────────── plotly base theme
PLOTLY_THEME = dict(
    template="plotly_dark",
    paper_bgcolor='rgba(0,0,0,0)', # Transparent background for charts
    plot_bgcolor='rgba(0,0,0,0)',
    font_color=TEXT_PRI,
    font_family="Inter, system-ui, sans-serif",
    font_size=13,
    margin=dict(l=10, r=10, t=30, b=10),
    colorway=[ACCENT, ACCENT2, SUCCESS, WARNING, "#ef4444", "#f97316"],
)

def apply_theme(fig):
    fig.update_layout(**PLOTLY_THEME)
    # Subtle grid lines
    fig.update_xaxes(gridcolor=BORDER, linecolor=BORDER, zeroline=False)
    fig.update_yaxes(gridcolor=BORDER, linecolor=BORDER, zeroline=False)
    return fig

# ─────────────────────────────────────────── helpers
def kpi_card(label: str, value: str) -> str:
    # Removed the background icon for a cleaner, modern look
    return f"""
    <div class="kpi-card">
        <div class="kpi-value">{value}</div>
        <div class="kpi-label">{label}</div>
    </div>"""

def section(eyebrow: str, title: str = "") -> None:
    st.markdown(f'<div class="section-label">{eyebrow}</div>', unsafe_allow_html=True)
    if title:
        st.markdown(f'### {title}', unsafe_allow_html=True) # Using markdown headers for semantic HTML

# ─────────────────────────────────────────── global header
st.markdown(f"""
<div class="agent-header">
    <div class="agent-logo">✦</div>
    <div>
        <div class="agent-name">Data AI Agent</div>
        <div class="agent-meta">
            <span class="status-dot"></span>
            Local Environment · <code>{OLLAMA_MODEL}</code>
        </div>
    </div>
</div>
""", unsafe_allow_html=True)

# ─────────────────────────────────────────── tabs
tab_chat, tab_data, tab_dash, tab_ctx = st.tabs(
    ["Chat", "Data Management", "Dashboards", "Business Context"] # Cleaner tab names without emojis
)

# ══════════════════════════════════════════ CHAT
with tab_chat:
    if "messages" not in st.session_state:
        st.session_state.messages = []

    left, right = st.columns([3, 1], gap="large")

    # ── right panel: prompts
    with right:
        section("Suggestions")
        prompts = [
            "Show top 5 rows of every table",
            "Top 3 products by revenue",
            "Which columns have missing values?",
            "Average revenue per product",
        ]
        
        for p in prompts:
            if st.button(p, key=f"chip_{p}", use_container_width=True):
                st.session_state.messages.append({"role": "user", "content": p})
                with st.spinner("Analyzing data..."):
                    reply = run_agent_turn(p, st.session_state.messages[:-1])
                st.session_state.messages.append({"role": "assistant", "content": reply})
                st.rerun()

        st.markdown("<br>", unsafe_allow_html=True)
        if st.button("Clear chat", use_container_width=True):
            st.session_state.messages = []
            st.rerun()

    # ── left panel: chat
    with left:
        chat_container = st.container()
        with chat_container:
            if not st.session_state.messages:
                # Modern empty state
                st.markdown(f"""
                <div style="
                    text-align:center;
                    padding: 4rem 2rem;
                    color: {TEXT_SEC};
                ">
                    <div style="font-size:3rem; margin-bottom:1rem; color:{ACCENT}">✧</div>
                    <h3 style="color:{TEXT_PRI}; font-weight:500; margin-bottom:0.5rem;">How can I help with your data today?</h3>
                    <p style="font-size:0.9rem;">Upload a dataset in the Data tab to get started.</p>
                </div>
                """, unsafe_allow_html=True)
            else:
                for msg in st.session_state.messages:
                    with st.chat_message(msg["role"]):
                        st.markdown(msg["content"])

        if prompt := st.chat_input("Message Data AI Agent..."):
            st.session_state.messages.append({"role": "user", "content": prompt})
            with st.chat_message("user"):
                st.markdown(prompt)
            with st.chat_message("assistant"):
                with st.spinner("Thinking..."):
                    reply = run_agent_turn(prompt, st.session_state.messages[:-1])
                st.markdown(reply)
            st.session_state.messages.append({"role": "assistant", "content": reply})

# ══════════════════════════════════════════ DATA
with tab_data:
    up_col, table_col = st.columns([1, 2], gap="large")

    with up_col:
        section("Upload")
        st.caption("Supported: CSV, JSON, NDJSON, Parquet. Files are indexed locally in DuckDB.")
        
        uploaded = st.file_uploader(
            "Drop file here",
            type=["csv", "json", "ndjson", "parquet"],
            accept_multiple_files=True,
            label_visibility="collapsed",
        )
        if uploaded:
            RAW_DIR.mkdir(parents=True, exist_ok=True)
            for f in uploaded:
                dest = RAW_DIR / f.name
                dest.write_bytes(f.getbuffer())
                table_name = Path(f.name).stem.lower().replace(" ", "_").replace("-", "_")
                result = load_file_into_table(f.name, table_name)
                if result.startswith(("Error", "Load error")):
                    st.error(f"Failed to load {f.name}: {result}")
                else:
                    st.success(f"Indexed {f.name} as `{table_name}`")

    with table_col:
        tables = list_tables()
        section("Local Warehouse", f"{len(tables)} active tables")
        
        if not tables:
            st.info("Your local warehouse is empty. Upload data to begin.")
        else:
            for t in tables:
                rc = row_count(t)
                with st.expander(f"**{t}** —  {rc:,} rows", expanded=False):
                    inner_l, inner_r = st.columns([3, 2])
                    with inner_l:
                        st.caption("Data Preview")
                        st.dataframe(
                            query_df(f'SELECT * FROM "{t}" LIMIT 50'),
                            use_container_width=True,
                            height=250,
                        )
                    with inner_r:
                        st.caption("Schema Profile")
                        st.dataframe(profile_table(t), use_container_width=True, height=250)

# ══════════════════════════════════════════ DASHBOARD
with tab_dash:
    tables = list_tables()
    if not tables:
        st.info("Upload data first to unlock visualizations and reporting.")
    else:
        ctrl_l, ctrl_r = st.columns([3, 1], gap="large")
        with ctrl_l:
            table = st.selectbox("Active Dataset", tables)
        with ctrl_r:
            st.markdown("<div class='primary-btn'>", unsafe_allow_html=True)
            gen_btn = st.button("Generate Report", use_container_width=True)
            st.markdown("</div>", unsafe_allow_html=True)
            
            if gen_btn:
                with st.spinner("Compiling analysis..."):
                    st.session_state["report"] = generate_report(table)
            if st.session_state.get("report"):
                st.download_button(
                    "Download Report (.md)",
                    st.session_state["report"],
                    file_name=f"{table}_analysis.md",
                    use_container_width=True,
                )

        st.markdown("<br>", unsafe_allow_html=True)

        # ── KPI row
        cols_meta = classify_columns(table)
        prof = profile_table(table)
        rc = row_count(table)
        total_nulls = int(prof["nulls"].sum())
        null_pct = round(total_nulls / max(rc * len(prof), 1) * 100, 1)

        k1, k2, k3, k4 = st.columns(4)
        k1.markdown(kpi_card("Total Rows", f"{rc:,}"), unsafe_allow_html=True)
        k2.markdown(kpi_card("Features", str(len(prof))), unsafe_allow_html=True)
        k3.markdown(kpi_card("Numeric Metrics", str(len(cols_meta["numeric"]))), unsafe_allow_html=True)
        k4.markdown(kpi_card("Data Sparsity", f"{null_pct}%"), unsafe_allow_html=True)

        st.markdown("<br><br>", unsafe_allow_html=True)

        # ── charts row
        chart_l, chart_r = st.columns(2, gap="large")

        with chart_l:
            section("Categorical Breakdown")
            if cols_meta["categorical"] and cols_meta["numeric"]:
                cc1, cc2, cc3 = st.columns(3)
                dim     = cc1.selectbox("Group by", cols_meta["categorical"], key="bar_dim")
                measure = cc2.selectbox("Metric",  cols_meta["numeric"],     key="bar_m")
                agg     = cc3.selectbox("Function", ["SUM","AVG","COUNT","MAX","MIN"], key="bar_a")
                
                df_bar  = query_df(
                    f'SELECT "{dim}" AS cat, {agg}("{measure}") AS val '
                    f'FROM "{table}" GROUP BY "{dim}" ORDER BY val DESC LIMIT 15'
                )
                fig_bar = px.bar(
                    df_bar, x="cat", y="val",
                    color="val",
                    color_continuous_scale=[ACCENT, ACCENT2],
                )
                fig_bar.update_traces(marker_line_width=0, border_radius=4)
                fig_bar.update_coloraxes(showscale=False)
                st.plotly_chart(apply_theme(fig_bar), use_container_width=True)
            else:
                st.info("Requires 1 categorical and 1 numeric column.")

        with chart_r:
            section("Time Series / Distribution")
            if cols_meta["temporal"] and cols_meta["numeric"]:
                tc1, tc2 = st.columns(2)
                tcol    = tc1.selectbox("Time axis", cols_meta["temporal"], key="ln_t")
                measure = tc2.selectbox("Metric",   cols_meta["numeric"],  key="ln_m")
                
                df_line = query_df(
                    f'SELECT "{tcol}" AS t, SUM("{measure}") AS val '
                    f'FROM "{table}" GROUP BY "{tcol}" ORDER BY t'
                )
                fig_line = px.line(
                    df_line, x="t", y="val",
                    color_discrete_sequence=[ACCENT],
                )
                fig_line.update_traces(line_width=3)
                st.plotly_chart(apply_theme(fig_line), use_container_width=True)
            elif cols_meta["numeric"]:
                measure  = st.selectbox("Feature", cols_meta["numeric"], key="hist_m")
                df_hist  = query_df(f'SELECT "{measure}" AS val FROM "{table}"')
                fig_hist = px.histogram(
                    df_hist, x="val", nbins=40,
                    color_discrete_sequence=[ACCENT2],
                )
                fig_hist.update_traces(marker_line_width=0)
                st.plotly_chart(apply_theme(fig_hist), use_container_width=True)

# ══════════════════════════════════════════ BUSINESS CONTEXT
with tab_ctx:
    c_left, c_right = st.columns([3, 2], gap="large")

    with c_left:
        section("System Instructions")
        st.caption("Provide domain knowledge to ground the AI's responses.")

        current = load_business_context()
        text = st.text_area(
            "Context",
            value=current,
            height=300,
            label_visibility="collapsed",
            placeholder=(
                "e.g., 'Revenue' is calculated as price * quantity minus discounts.\n"
                "Our core users are categorized into 'Active' and 'Churned'."
            ),
        )
        
        st.markdown("<div class='primary-btn'>", unsafe_allow_html=True)
        if st.button("Update Agent Context", use_container_width=False):
            save_business_context(text)
            st.success("Context successfully updated.")
        st.markdown("</div>", unsafe_allow_html=True)

    with c_right:
        section("Best Practices")
        st.markdown("""
        To get the most accurate analysis, define:
        * **Domain Jargon**: Explain acronyms specific to your company.
        * **Metric Logic**: How do you calculate complex KPIs?
        * **Timeframes**: Do you use a specific fiscal calendar?
        * **Data Caveats**: Are there known bugs or missing periods in your data?
        """)