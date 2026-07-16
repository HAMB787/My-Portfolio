"""
LinkedIn job postings — Streamlit dashboard (mirrors Power BI layout).

Uses `data1/fct_job_listing.csv` (grain: one row per Job_URL), built by
`src/build_fct_job_listing.py` from `linkedin_dashboard_jobs_combined.csv`.

Run from project root:
    streamlit run streamlit_app/app.py
"""

from __future__ import annotations

import re
from datetime import date
from pathlib import Path
from typing import Any, cast

import pandas as pd
import streamlit as st

try:
    import plotly.express as px  # type: ignore[import-untyped]
    import plotly.graph_objects as go  # type: ignore[import-untyped]
except ImportError:  # pragma: no cover
    px = None  # type: ignore[assignment]
    go = None  # type: ignore[assignment]

_PROJECT_ROOT = Path(__file__).resolve().parent.parent
FCT_JOB_LISTING_PATH = _PROJECT_ROOT / "data1" / "fct_job_listing.csv"

# Plotly shared look (dark, transparent canvas) — typed for pyright (avoid **/Layout conflicts)
_PLOT: dict[str, Any] = {
    "template": "plotly_dark",
    "paper_bgcolor": "rgba(0,0,0,0)",
    "plot_bgcolor": "rgba(15,23,42,0.6)",
    "font": {"color": "#e2e8f0", "size": 12},
    "title_font": {"size": 14, "color": "#f8fafc"},
    "margin": {"l": 8, "r": 8, "t": 48, "b": 8},
}

_COLORS = [
    "#6366f1", "#8b5cf6", "#ec4899", "#f97316", "#eab308", "#22c55e",
    "#06b6d4", "#3b82f6", "#a855f7", "#f43f5e", "#14b8a6", "#f59e0b",
    "#84cc16", "#64748b",
]

_UNKNOWN_FILTER = "(unknown)"


def _extract_linkedin_job_id(url: object) -> int | None:
    if not isinstance(url, str) or not url.strip():
        return None
    m = re.search(r"-(\d+)/?(?:\?.*)?$", url.strip())
    if m:
        return int(m.group(1))
    return None


def _normalize_jobs_frame(df: pd.DataFrame) -> pd.DataFrame:
    """Map fact export or legacy combined CSV columns to the internal schema."""
    if df.empty:
        return df

    # Build output from `build_fct_job_listing.py` (has date_key_* not date_key)
    if "fct_job_listing_key" in df.columns and "job_url" in df.columns:
        out = df.copy()
        if "date_key_posted" in out.columns:
            dk = cast(pd.Series, out["date_key_posted"]).fillna("").astype(str)
            out["date_key"] = dk
        elif "date_key_scrape" in out.columns:
            out["date_key"] = cast(pd.Series, out["date_key_scrape"]).fillna("").astype(str)
        else:
            out["date_key"] = pd.Series([""] * len(out), index=out.index)
        if "linkedin_job_id" in out.columns:
            lj = cast(
                pd.Series,
                pd.to_numeric(out["linkedin_job_id"], errors="coerce"),
            )
            out["linkedin_job_id"] = lj.astype("Int64")
        if "has_salary_usd" in out.columns:
            hs = cast(
                pd.Series,
                pd.to_numeric(out["has_salary_usd"], errors="coerce"),
            ).fillna(0)
            out["has_salary_usd"] = hs.astype(int)
        return out

    # Combined export (Title / Job_URL columns)
    if "Job_URL" not in df.columns:
        # Internal shape already except missing date_key
        if (
            "scraped_at" in df.columns
            and "job_url" in df.columns
            and "date_key" in df.columns
        ):
            return df
        if "scraped_at" in df.columns and "job_url" in df.columns:
            inner = df.copy()
            if "date_key" not in inner.columns:
                inner["date_key"] = pd.Series([""] * len(inner), index=inner.index)
            return inner
        return df

    out = df.rename(
        columns={
            "Title": "title",
            "Company": "company_name",
            "Location": "location_text",
            "Market": "market",
            "Work_Type": "work_type",
            "Search_Keyword": "search_keyword",
            "Experience_Level": "experience_level",
            "Original_Salary": "original_salary_text",
            "Salary_in_USD": "salary_amount_usd",
            "Job_URL": "job_url",
            "Scraped_At": "scraped_at",
        }
    )
    if "Posted_Date" in out.columns:
        posted = pd.to_datetime(out["Posted_Date"], errors="coerce")
        out["date_key"] = posted.dt.strftime("%Y%m%d").fillna("")
        out = out.drop(columns=["Posted_Date"])
    else:
        out["date_key"] = ""

    out["linkedin_job_id"] = out["job_url"].map(_extract_linkedin_job_id).astype("Int64")

    sal_num = cast(pd.Series, pd.to_numeric(out["salary_amount_usd"], errors="coerce"))
    out["has_salary_usd"] = (sal_num.notna() & (sal_num.fillna(0) > 0)).astype(int)

    return out


@st.cache_data(ttl=60)
def load_jobs() -> pd.DataFrame:
    if not FCT_JOB_LISTING_PATH.exists():
        return pd.DataFrame()
    raw = pd.read_csv(FCT_JOB_LISTING_PATH, encoding="utf-8-sig")
    return _normalize_jobs_frame(raw)


def _prep(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    scraped = pd.to_datetime(out["scraped_at"], errors="coerce")
    out["scraped_at"] = scraped
    if bool(scraped.isna().all()) and "date_key" in out.columns:
        out["posted_dt"] = pd.to_datetime(
            out["date_key"].astype(str), format="%Y%m%d", errors="coerce"
        )
    else:
        out["posted_dt"] = scraped
    if "has_salary_usd" in out.columns:
        num_sal = pd.to_numeric(out["has_salary_usd"], errors="coerce")
        out["has_salary_usd"] = num_sal.fillna(0) if isinstance(num_sal, pd.Series) else 0
    if "salary_amount_usd" in out.columns:
        out["salary_amount_usd_num"] = pd.to_numeric(
            out["salary_amount_usd"], errors="coerce"
        )
    return out


def _filter_options(series: pd.Series) -> list[str]:
    """Known values plus an explicit bucket for null/blank (excluded from dropna().unique())."""
    known = sorted(series.dropna().astype(str).str.strip().replace("", pd.NA).dropna().unique())
    if series.isna().any() or (series.astype(str).str.strip() == "").any():
        return [*known, _UNKNOWN_FILTER]
    return known


def _match_filter(series: pd.Series, selected: list[str]) -> pd.Series:
    if not selected:
        return pd.Series(True, index=series.index)
    known = [v for v in selected if v != _UNKNOWN_FILTER]
    mask = series.isin(known)
    if _UNKNOWN_FILTER in selected:
        blank = series.isna() | (series.astype(str).str.strip() == "")
        mask = mask | blank
    return mask


def _apply_filters(
    df: pd.DataFrame,
    roles: list[str],
    exps: list[str],
    markets: list[str],
    d0: date,
    d1: date,
) -> pd.DataFrame:
    f: pd.DataFrame = df.copy()
    if roles:
        f = f.loc[_match_filter(cast(pd.Series, f["search_keyword"]), roles)]
    if exps:
        f = f.loc[_match_filter(cast(pd.Series, f["experience_level"]), exps)]
    if markets:
        f = f.loc[_match_filter(cast(pd.Series, f["market"]), markets)]
    if "posted_dt" in f.columns:
        posted = f["posted_dt"]
        mask = posted.notna() & (posted.dt.date >= d0) & (posted.dt.date <= d1)
        f = f.loc[mask]
    return f


def main() -> None:
    st.set_page_config(
        page_title="LinkedIn job postings",
        layout="wide",
        initial_sidebar_state="collapsed",
    )

    if px is None or go is None:
        st.error(
            "Plotly is not installed. Run: `pip install -r streamlit_app/requirements.txt` "
            "then restart the app."
        )
        st.stop()

    st.markdown(
        """
        <style>
        .block-container { padding-top: 1.2rem; padding-bottom: 2rem; max-width: 1400px; }
        div[data-testid="stMetric"] {
            background: linear-gradient(145deg, #1e293b 0%, #0f172a 100%);
            border: 1px solid #334155;
            border-radius: 10px;
            padding: 12px;
        }
        .dashboard-title {
            font-size: 1.75rem;
            font-weight: 700;
            letter-spacing: 0.06em;
            color: #f8fafc;
            margin-bottom: 0.25rem;
        }
        .footer-banner {
            background: linear-gradient(90deg, #1e3a5f 0%, #0f172a 100%);
            color: #e2e8f0;
            padding: 14px 20px;
            border-radius: 8px;
            text-align: center;
            font-weight: 600;
            letter-spacing: 0.12em;
            margin-top: 2rem;
            border: 1px solid #334155;
        }
        </style>
        """,
        unsafe_allow_html=True,
    )

    df_raw = load_jobs()
    if df_raw.empty:
        st.error(f"No data. Expected: `{FCT_JOB_LISTING_PATH.resolve()}`")
        st.stop()

    df = _prep(df_raw)
    pmin = df["posted_dt"].min()
    pmax = df["posted_dt"].max()
    if not isinstance(pmin, pd.Timestamp) or not isinstance(pmax, pd.Timestamp):
        st.error("No valid scrape timestamps in the dataset.")
        st.stop()
    if bool(pd.isna(pmin)) or bool(pd.isna(pmax)):
        st.error("No valid scrape timestamps in the dataset.")
        st.stop()
    d_start, d_end = pmin.date(), pmax.date()

    st.markdown('<p class="dashboard-title">LINKEDIN JOB POSTINGS</p>', unsafe_allow_html=True)
    st.caption(
        f"Source: `{FCT_JOB_LISTING_PATH.relative_to(_PROJECT_ROOT)}` — dates reflect **scrape** time. "
        "Regenerate with `python src/build_fct_job_listing.py` after CSV updates."
    )

    # —— Top filters (Power BI–style slicers) ——
    fc1, fc2, fc3, fc4 = st.columns([1.1, 1.1, 1.0, 1.4])
    all_roles = _filter_options(cast(pd.Series, df["search_keyword"]))
    all_exp = _filter_options(cast(pd.Series, df["experience_level"]))
    all_mkt = _filter_options(cast(pd.Series, df["market"]))

    with fc1:
        roles = st.multiselect("Search role (keyword)", options=all_roles, default=all_roles)
    with fc2:
        exps = st.multiselect("Experience level", options=all_exp, default=all_exp)
    with fc3:
        markets = st.multiselect("Market", options=all_mkt, default=all_mkt)
    with fc4:
        dr = st.date_input(
            "Scrape date range",
            value=(d_start, d_end),
            min_value=d_start,
            max_value=d_end,
            format="MM/DD/YYYY",
        )
        if isinstance(dr, tuple):
            if len(dr) >= 2:
                d0, d1 = dr[0], dr[1]
            elif len(dr) == 1:
                d0 = d1 = dr[0]
            else:
                d0, d1 = d_start, d_end
        else:
            d0 = d1 = cast(date, dr)
        if d0 > d1:
            d0, d1 = d1, d0

    f = _apply_filters(df, roles, exps, markets, d0, d1)
    if f.empty:
        st.warning("No rows match the current filters.")
        st.stop()

    # —— KPI row (days-on-board not in fct — use salary coverage instead) ——
    pmin_f = f["posted_dt"].min()
    pmax_f = f["posted_dt"].max()
    unique_scrape_days = (
        int(f["posted_dt"].dt.date.nunique()) if bool(f["posted_dt"].notna().any()) else 0
    )
    if "has_salary_usd" in f.columns:
        with_salary = int(f["has_salary_usd"].to_numpy().sum())
    else:
        with_salary = 0

    k1, k2, k3, k4, k5, k6 = st.columns(6)
    k1.metric("TOTAL POSTINGS", f"{len(f):,}")
    k2.metric("UNIQUE COMPANIES", f"{f['company_name'].nunique():,}")
    k3.metric("SCRAPE DAYS", f"{unique_scrape_days:,}")
    k4.metric("MARKETS", f"{f['market'].nunique():,}")
    k5.metric("WITH SALARY (USD)", f"{with_salary:,}")
    with k6:
        st.markdown("**Date range (filtered)**")
        pmin_ok = not bool(pd.isna(pmin_f))
        pmax_ok = not bool(pd.isna(pmax_f))
        if pmin_ok and pmax_ok:
            st.caption(f"MIN: {pmin_f:%m/%d/%Y %H:%M}")
            st.caption(f"MAX: {pmax_f:%m/%d/%Y %H:%M}")
        else:
            st.caption("—")

    st.markdown("")

    # —— Row 1: donuts + market split ——
    r1a, r1b, r1c = st.columns([1.0, 1.0, 1.0])

    with r1a:
        role_counts = f["search_keyword"].value_counts().reset_index()
        role_counts.columns = ["search_keyword", "count"]
        fig_roles = px.pie(
            role_counts,
            names="search_keyword",
            values="count",
            title="Jobs by search role (keyword)",
            hole=0.52,
            color_discrete_sequence=_COLORS,
        )
        fig_roles.update_traces(textposition="inside", textinfo="percent+label")
        fig_roles.update_layout(
            **_PLOT,
            showlegend=True,
            legend=dict(
                orientation="v",
                yanchor="middle",
                y=0.5,
                bgcolor="rgba(30,41,59,0.9)",
                borderwidth=0,
            ),
        )
        st.plotly_chart(fig_roles, use_container_width=True)

    with r1b:
        exp_counts = f["experience_level"].value_counts().reset_index()
        exp_counts.columns = ["experience_level", "count"]
        fig_exp = px.pie(
            exp_counts,
            names="experience_level",
            values="count",
            title="Experience level",
            hole=0.52,
            color_discrete_sequence=_COLORS,
        )
        fig_exp.update_traces(textposition="inside", textinfo="percent+label")
        fig_exp.update_layout(**_PLOT)
        st.plotly_chart(fig_exp, use_container_width=True)

    with r1c:
        mkt = cast(pd.DataFrame, f.groupby("market", as_index=False).size())
        mkt.columns = ["market", "count"]
        mkt = mkt.sort_values(by="count", ascending=True)
        fig_mkt = px.bar(
            mkt,
            x="count",
            y="market",
            orientation="h",
            title="Market split",
            color="market",
            color_discrete_sequence=_COLORS,
        )
        fig_mkt.update_layout(**_PLOT, showlegend=False)
        fig_mkt.update_xaxes(title="Postings")
        fig_mkt.update_yaxes(title="")
        st.plotly_chart(fig_mkt, use_container_width=True)

    # —— Row 2: top companies + top locations (replaces “posting age” — not in fact export) ——
    r2a, r2b = st.columns(2)

    with r2a:
        top_co = f["company_name"].value_counts().head(12).reset_index()
        top_co.columns = ["company_name", "count"]
        fig_co = px.bar(
            top_co,
            x="count",
            y="company_name",
            orientation="h",
            title="Top companies by postings",
            color="count",
            color_continuous_scale="Viridis",
        )
        fig_co.update_layout(**_PLOT, showlegend=False, yaxis=dict(categoryorder="total ascending"))
        fig_co.update_xaxes(title="Postings")
        st.plotly_chart(fig_co, use_container_width=True)

    with r2b:
        loc = f["location_text"].fillna("").replace("", "(blank)")
        top_loc = loc.value_counts().head(15).reset_index()
        top_loc.columns = ["location_text", "count"]
        fig_loc = go.Figure(
            go.Bar(
                x=top_loc["count"],
                y=top_loc["location_text"],
                orientation="h",
                marker_color="#8b5cf6",
                marker_line_width=0,
            )
        )
        fig_loc.update_layout(
            **_PLOT,
            title="Top location strings",
            showlegend=False,
            yaxis=dict(categoryorder="total ascending"),
        )
        fig_loc.update_xaxes(title="Postings")
        fig_loc.update_yaxes(title="")
        st.plotly_chart(fig_loc, use_container_width=True)

    # —— Row 3: timeline ——
    tl = f[f["posted_dt"].notna()].copy()
    tl["day"] = cast(pd.Series, tl["posted_dt"]).dt.date
    daily = cast(pd.DataFrame, tl.groupby("day", as_index=False).size())
    daily.columns = ["day", "count"]
    fig_tl = px.bar(daily, x="day", y="count", title="Scrape timeline (day)")
    fig_tl.update_traces(marker_color="#6366f1", marker_line_width=0)
    fig_tl.update_layout(**_PLOT, showlegend=False)
    fig_tl.update_xaxes(title="Scrape date (UTC/local as in CSV)")
    fig_tl.update_yaxes(title="Postings")
    st.plotly_chart(fig_tl, use_container_width=True)

    # —— Row 4: stacked + grouped ——
    r4a, r4b = st.columns(2)

    with r4a:
        pivot = cast(
            pd.DataFrame,
            f.groupby(["search_keyword", "experience_level"]).size().reset_index(),
        )
        pivot.columns = ["search_keyword", "experience_level", "count"]
        fig_stack = px.bar(
            pivot,
            x="search_keyword",
            y="count",
            color="experience_level",
            title="Role × experience level",
            color_discrete_sequence=_COLORS,
        )
        fig_stack.update_layout(**_PLOT, barmode="stack", xaxis_tickangle=-35)
        fig_stack.update_xaxes(title="")
        fig_stack.update_yaxes(title="Postings")
        st.plotly_chart(fig_stack, use_container_width=True)

    with r4b:
        pivot2 = cast(
            pd.DataFrame,
            f.groupby(["search_keyword", "market"]).size().reset_index(),
        )
        pivot2.columns = ["search_keyword", "market", "count"]
        fig_grp = px.bar(
            pivot2,
            x="search_keyword",
            y="count",
            color="market",
            title="Role × market",
            barmode="group",
            color_discrete_sequence=_COLORS,
        )
        fig_grp.update_layout(**_PLOT, xaxis_tickangle=-35)
        fig_grp.update_xaxes(title="")
        fig_grp.update_yaxes(title="Postings")
        st.plotly_chart(fig_grp, use_container_width=True)

    # —— Detail table ——
    with st.expander("Job detail table", expanded=False):
        detail_cols = [
            "date_key",
            "market",
            "search_keyword",
            "experience_level",
            "company_name",
            "title",
            "location_text",
            "has_salary_usd",
            "salary_amount_usd",
            "original_salary_text",
            "job_url",
            "linkedin_job_id",
        ]
        if "work_type" in f.columns:
            detail_cols.insert(6, "work_type")
        show = cast(pd.DataFrame, f[[c for c in detail_cols if c in f.columns]])
        show = show.sort_values(by="company_name", ascending=True, kind="stable")
        show = show.sort_values(by="date_key", ascending=False, kind="stable")
        st.dataframe(
            show,
            hide_index=True,
            use_container_width=True,
            column_config={
                "location_text": st.column_config.TextColumn(
                    "Location",
                    help="LinkedIn card location line.",
                ),
                "job_url": st.column_config.LinkColumn("Link", display_text="Open"),
                "linkedin_job_id": st.column_config.NumberColumn("Job ID", format="%d"),
            },
        )

    st.markdown(
        '<div class="footer-banner">LINKEDIN JOB POSTINGS ▶</div>',
        unsafe_allow_html=True,
    )


if __name__ == "__main__":
    main()
