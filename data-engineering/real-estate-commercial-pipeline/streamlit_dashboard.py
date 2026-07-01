"""
High-level Streamlit dashboard for Yerevan commercial real estate listings.

Input:
    Fact_CommercialRealEstate.csv

Run:
    streamlit run streamlit_dashboard.py
"""

from __future__ import annotations

from pathlib import Path

import pandas as pd
import plotly.express as px
import streamlit as st


FACT_CSV = Path("Fact_CommercialRealEstate.csv")

CATEGORY_LABELS = {
    1408: "Multifunctional",
    1401: "Retail / Commercial",
    1410: "Other Commercial",
}


st.set_page_config(
    page_title="Yerevan Commercial Real Estate Dashboard",
    page_icon="🏢",
    layout="wide",
    initial_sidebar_state="expanded",
)


@st.cache_data(show_spinner=False)
def load_data(path: Path, file_mtime_ns: int) -> pd.DataFrame:
    """Load and lightly type the fact table for dashboard use."""
    # file_mtime_ns is intentionally part of the cache key so Streamlit reloads
    # when Fact_CommercialRealEstate.csv is rebuilt.
    df = pd.read_csv(path, encoding="utf-8-sig")

    df["id"] = pd.to_numeric(df["id"], errors="coerce").astype("Int64")
    df["category_id"] = pd.to_numeric(df["category_id"], errors="coerce").astype("Int64")
    df["price_usd"] = pd.to_numeric(df["price_usd"], errors="coerce")
    df["area_sqm"] = pd.to_numeric(df["area_sqm"], errors="coerce")
    df["price_per_sqm"] = df["price_usd"] / df["area_sqm"].where(df["area_sqm"] > 0)

    for col in ["date_posted", "date_updated", "date_posted_exact", "date_updated_exact"]:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col], errors="coerce")

    text_cols = df.select_dtypes(include=["object", "string"]).columns
    df[text_cols] = df[text_cols].fillna("N/A")
    df["category"] = df["category_id"].map(CATEGORY_LABELS).fillna(df["category_id"].astype(str))
    return df


def explode_business_types(df: pd.DataFrame) -> pd.DataFrame:
    """Split comma-separated business types for correct counts."""
    exploded = df[["id", "business_type", "district", "price_usd", "area_sqm"]].copy()
    exploded["business_type"] = exploded["business_type"].fillna("General Commercial")
    exploded["business_type"] = exploded["business_type"].str.split(",")
    exploded = exploded.explode("business_type")
    exploded["business_type"] = exploded["business_type"].str.strip()
    exploded["business_type"] = exploded["business_type"].replace("", "General Commercial")
    return exploded


def format_usd(value: float | int | None) -> str:
    if pd.isna(value):
        return "N/A"
    return f"${value:,.0f}"


def sorted_filter_values(df: pd.DataFrame, column: str, include_na: bool = True) -> list[str]:
    """Return clean sorted values for sidebar multiselect filters."""
    values = df[column].fillna("N/A").astype(str).str.strip().replace("", "N/A")
    unique_values = sorted(values.unique())
    if not include_na:
        unique_values = [value for value in unique_values if value != "N/A"]
    else:
        unique_values = [value for value in unique_values if value != "N/A"] + (
            ["N/A"] if "N/A" in unique_values else []
        )
    return unique_values


def optional_multiselect_filter(
    df: pd.DataFrame,
    column: str,
    selected_values: list[str],
) -> pd.Series:
    """Empty selection means no filter; selected values restrict the dataframe."""
    if not selected_values:
        return pd.Series(True, index=df.index)
    values = df[column].fillna("N/A").astype(str).str.strip().replace("", "N/A")
    return values.isin(selected_values)


def reset_filters() -> None:
    """Clear all sidebar widget state and rerun with default empty filters."""
    for key in list(st.session_state.keys()):
        if key.startswith("filter_"):
            del st.session_state[key]


def refresh_data() -> None:
    """Clear cached dataframe after the fact table is rebuilt."""
    load_data.clear()


def sidebar_filters(df: pd.DataFrame) -> pd.DataFrame:
    """Build sidebar filters and return the filtered dataframe."""
    st.sidebar.header("Filters")
    st.sidebar.button("Refresh data", on_click=refresh_data, use_container_width=True)
    st.sidebar.button("Clear all filters", on_click=reset_filters, use_container_width=True)
    st.sidebar.caption("Empty selections mean All.")

    districts = sorted_filter_values(df, "district", include_na=False)
    selected_districts = st.sidebar.multiselect(
        "District",
        districts,
        default=[],
        key="filter_district",
    )

    categories = sorted_filter_values(df, "category", include_na=False)
    selected_categories = st.sidebar.multiselect(
        "Category",
        categories,
        default=[],
        key="filter_category",
    )

    sellers = sorted_filter_values(df, "seller_type")
    selected_sellers = st.sidebar.multiselect(
        "Seller Type",
        sellers,
        default=[],
        key="filter_seller_type",
    )

    business_options = sorted(explode_business_types(df)["business_type"].dropna().unique())
    selected_business = st.sidebar.multiselect(
        "Business Type",
        business_options,
        default=[],
        key="filter_business_type",
    )

    street_lines = sorted_filter_values(df, "street_line")
    selected_street_lines = st.sidebar.multiselect(
        "Street Line",
        street_lines,
        default=[],
        key="filter_street_line",
        help="Armenian values usually mean Առաջին գիծ = first line, Երկրորդ գիծ = second line.",
    )

    furniture_options = sorted_filter_values(df, "furniture")
    selected_furniture = st.sidebar.multiselect(
        "Furniture",
        furniture_options,
        default=[],
        key="filter_furniture",
    )

    elevator_options = sorted_filter_values(df, "elevator")
    selected_elevator = st.sidebar.multiselect(
        "Elevator",
        elevator_options,
        default=[],
        key="filter_elevator",
    )

    entrance_options = sorted_filter_values(df, "entrance")
    selected_entrance = st.sidebar.multiselect(
        "Entrance",
        entrance_options,
        default=[],
        key="filter_entrance",
    )

    rental_type_options = sorted_filter_values(df, "rental_type")
    selected_rental_type = st.sidebar.multiselect(
        "Rental Type",
        rental_type_options,
        default=[],
        key="filter_rental_type",
    )

    date_options = {
        "All Dates": None,
        "Updated Date": "date_updated",
        "Posted Date": "date_posted",
    }
    selected_date_label = st.sidebar.selectbox(
        "Date Filter",
        options=list(date_options.keys()),
        index=0,
        key="filter_date_mode",
        help="Use Updated Date for daily monitoring, or Posted Date for original listing age.",
    )
    selected_date_col = date_options[selected_date_label]
    if selected_date_col is None:
        start_date = None
        end_date = None
    else:
        valid_dates = df[selected_date_col].dropna()
        if valid_dates.empty:
            start_date = None
            end_date = None
            st.sidebar.info(f"No values available for {selected_date_label}.")
        else:
            min_date = valid_dates.min().date()
            max_date = valid_dates.max().date()
            selected_dates = st.sidebar.date_input(
                selected_date_label,
                value=(min_date, max_date),
                min_value=min_date,
                max_value=max_date,
                key="filter_date_range",
            )
            if isinstance(selected_dates, tuple) and len(selected_dates) == 2:
                start_date, end_date = selected_dates
            else:
                start_date = selected_dates
                end_date = selected_dates

    min_price = int(df["price_usd"].min(skipna=True) or 0)
    max_price = int(df["price_usd"].max(skipna=True) or 0)
    price_range = st.sidebar.slider(
        "Monthly Price USD",
        min_value=min_price,
        max_value=max_price,
        value=(min_price, max_price),
        step=50,
        key="filter_price_range",
    )

    area_df = df[df["area_sqm"].notna()]
    min_area = int(area_df["area_sqm"].min()) if not area_df.empty else 0
    max_area = int(area_df["area_sqm"].max()) if not area_df.empty else 0
    area_range = st.sidebar.slider(
        "Area sqm",
        min_value=min_area,
        max_value=max_area,
        value=(min_area, max_area),
        step=5,
        key="filter_area_range",
    )
    include_missing_area = st.sidebar.checkbox(
        "Include missing area",
        value=True,
        key="filter_include_missing_area",
    )

    date_mask = pd.Series(True, index=df.index)
    if selected_date_col is not None and start_date is not None and end_date is not None:
        date_values = df[selected_date_col].dt.date
        date_mask = date_values.between(start_date, end_date, inclusive="both")

    area_mask = df["area_sqm"].between(area_range[0], area_range[1], inclusive="both")
    if include_missing_area:
        area_mask = area_mask | df["area_sqm"].isna()

    filtered = df[
        optional_multiselect_filter(df, "district", selected_districts)
        & optional_multiselect_filter(df, "category", selected_categories)
        & optional_multiselect_filter(df, "seller_type", selected_sellers)
        & optional_multiselect_filter(df, "street_line", selected_street_lines)
        & optional_multiselect_filter(df, "furniture", selected_furniture)
        & optional_multiselect_filter(df, "elevator", selected_elevator)
        & optional_multiselect_filter(df, "entrance", selected_entrance)
        & optional_multiselect_filter(df, "rental_type", selected_rental_type)
        & date_mask
        & df["price_usd"].between(price_range[0], price_range[1], inclusive="both")
        & area_mask
    ].copy()

    if selected_business:
        matching_ids = explode_business_types(filtered)
        matching_ids = matching_ids[matching_ids["business_type"].isin(selected_business)]["id"].unique()
        filtered = filtered[filtered["id"].isin(matching_ids)]

    return filtered


def render_kpis(df: pd.DataFrame) -> None:
    """Top dashboard KPI cards."""
    total_listings = len(df)
    median_price = df["price_usd"].median()
    avg_price = df["price_usd"].mean()
    median_area = df["area_sqm"].median()
    median_ppsqm = df["price_per_sqm"].median()

    c1, c2, c3, c4, c5 = st.columns(5)
    c1.metric("Listings", f"{total_listings:,}")
    c2.metric("Median Price", format_usd(median_price))
    c3.metric("Avg Price", format_usd(avg_price))
    c4.metric("Median Area", "N/A" if pd.isna(median_area) else f"{median_area:,.0f} sqm")
    c5.metric("Median $ / sqm", format_usd(median_ppsqm))


def render_overview(df: pd.DataFrame) -> None:
    left, right = st.columns(2)

    with left:
        district_stats = (
            df.groupby("district", dropna=False)
            .agg(listings=("id", "count"), median_price=("price_usd", "median"))
            .reset_index()
            .sort_values("listings", ascending=False)
            .head(12)
        )
        fig = px.bar(
            district_stats,
            x="district",
            y="listings",
            color="median_price",
            title="Top Districts by Listing Count",
            labels={"district": "District", "listings": "Listings", "median_price": "Median Price"},
        )
        st.plotly_chart(fig, use_container_width=True)

    with right:
        category_stats = (
            df.groupby("category", dropna=False)
            .agg(listings=("id", "count"), median_price=("price_usd", "median"))
            .reset_index()
            .sort_values("listings", ascending=False)
        )
        fig = px.pie(
            category_stats,
            names="category",
            values="listings",
            title="Listings by Category",
            hole=0.35,
        )
        st.plotly_chart(fig, use_container_width=True)

    left, right = st.columns(2)
    with left:
        fig = px.histogram(
            df[df["price_usd"].notna()],
            x="price_usd",
            nbins=50,
            title="Price Distribution",
            labels={"price_usd": "Monthly Price USD"},
        )
        st.plotly_chart(fig, use_container_width=True)

    with right:
        fig = px.scatter(
            df[df["area_sqm"].notna() & df["price_usd"].notna()],
            x="area_sqm",
            y="price_usd",
            color="district",
            hover_data=["id", "business_type", "url"],
            title="Price vs Area",
            labels={"area_sqm": "Area sqm", "price_usd": "Monthly Price USD"},
        )
        st.plotly_chart(fig, use_container_width=True)


def render_business_type(df: pd.DataFrame) -> None:
    business = explode_business_types(df)
    stats = (
        business.groupby("business_type", dropna=False)
        .agg(
            listings=("id", "nunique"),
            median_price=("price_usd", "median"),
            median_area=("area_sqm", "median"),
        )
        .reset_index()
        .sort_values("listings", ascending=False)
    )

    fig = px.bar(
        stats.head(15),
        x="listings",
        y="business_type",
        orientation="h",
        color="median_price",
        title="Business Type Demand",
        labels={"business_type": "Business Type", "listings": "Listings"},
    )
    fig.update_layout(yaxis={"categoryorder": "total ascending"})
    st.plotly_chart(fig, use_container_width=True)

    st.dataframe(
        stats,
        use_container_width=True,
        hide_index=True,
        column_config={
            "median_price": st.column_config.NumberColumn("Median Price", format="$%d"),
            "median_area": st.column_config.NumberColumn("Median Area", format="%.0f sqm"),
        },
    )


def render_districts(df: pd.DataFrame) -> None:
    district = (
        df.groupby("district", dropna=False)
        .agg(
            listings=("id", "count"),
            median_price=("price_usd", "median"),
            avg_price=("price_usd", "mean"),
            median_area=("area_sqm", "median"),
            median_price_per_sqm=("price_per_sqm", "median"),
        )
        .reset_index()
        .sort_values("listings", ascending=False)
    )

    st.dataframe(
        district,
        use_container_width=True,
        hide_index=True,
        column_config={
            "median_price": st.column_config.NumberColumn("Median Price", format="$%d"),
            "avg_price": st.column_config.NumberColumn("Avg Price", format="$%d"),
            "median_area": st.column_config.NumberColumn("Median Area", format="%.0f sqm"),
            "median_price_per_sqm": st.column_config.NumberColumn("Median $ / sqm", format="$%d"),
        },
    )


def render_listing_table(df: pd.DataFrame) -> None:
    table_cols = [
        "id",
        "district",
        "category",
        "business_type",
        "price_usd",
        "area_sqm",
        "price_per_sqm",
        "seller_type",
        "date_updated",
        "title",
        "url",
    ]
    table = df[[col for col in table_cols if col in df.columns]].sort_values(
        ["date_updated", "price_usd"],
        ascending=[False, False],
    )

    st.dataframe(
        table,
        use_container_width=True,
        hide_index=True,
        column_config={
            "price_usd": st.column_config.NumberColumn("Price USD", format="$%d"),
            "area_sqm": st.column_config.NumberColumn("Area", format="%.0f sqm"),
            "price_per_sqm": st.column_config.NumberColumn("$ / sqm", format="$%d"),
            "url": st.column_config.LinkColumn("Listing URL"),
        },
    )

    csv_bytes = table.to_csv(index=False, encoding="utf-8-sig").encode("utf-8-sig")
    st.download_button(
        "Download filtered listings",
        data=csv_bytes,
        file_name="filtered_commercial_real_estate.csv",
        mime="text/csv",
    )


def render_data_quality(df: pd.DataFrame) -> None:
    quality = pd.DataFrame(
        [
            {"check": "Rows", "value": len(df)},
            {"check": "Unique IDs", "value": df["id"].nunique()},
            {"check": "Duplicate IDs", "value": len(df) - df["id"].nunique()},
            {"check": "Missing price_usd", "value": int(df["price_usd"].isna().sum())},
            {"check": "Missing area_sqm", "value": int(df["area_sqm"].isna().sum())},
            {"check": "Missing district", "value": int((df["district"] == "N/A").sum())},
        ]
    )
    st.dataframe(quality, use_container_width=True, hide_index=True)


def main() -> None:
    st.title("Yerevan Commercial Real Estate Dashboard")
    st.caption("Source: Fact_CommercialRealEstate.csv | Grain: one row per listing ID")

    if not FACT_CSV.exists():
        st.error(f"Missing file: {FACT_CSV}. Run build_fact_commercial_real_estate.py first.")
        st.stop()

    source_mtime_ns = FACT_CSV.stat().st_mtime_ns
    df = load_data(FACT_CSV, source_mtime_ns)
    filtered = sidebar_filters(df)

    st.sidebar.divider()
    st.sidebar.write(f"Filtered rows: **{len(filtered):,}** / {len(df):,}")
    st.sidebar.write(f"Last source refresh: **{pd.to_datetime(source_mtime_ns)}**")

    render_kpis(filtered)

    tab_overview, tab_business, tab_districts, tab_listings, tab_quality = st.tabs(
        ["Overview", "Business Types", "Districts", "Listings", "Data Quality"]
    )

    with tab_overview:
        render_overview(filtered)

    with tab_business:
        render_business_type(filtered)

    with tab_districts:
        render_districts(filtered)

    with tab_listings:
        render_listing_table(filtered)

    with tab_quality:
        render_data_quality(filtered)


if __name__ == "__main__":
    main()
