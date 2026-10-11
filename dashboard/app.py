# app.py
# LoanPulse: loan portfolio health dashboard for a small finance bank.
# Runs as the ANALYST role, so customer PII is always masked.

import pandas as pd
import plotly.express as px
import streamlit as st

from db import run_query


st.set_page_config(
    page_title="LoanPulse",
    page_icon="📊",
    layout="wide",
)

ASSET_CLASS_ORDER = ["STANDARD", "SMA_0", "SMA_1", "SMA_2", "NPA"]

ASSET_CLASS_COLORS = {
    "STANDARD": "#2E7D32",
    "SMA_0": "#F9A825",
    "SMA_1": "#EF6C00",
    "SMA_2": "#D84315",
    "NPA": "#B71C1C",
}


def to_crore(amount):
    """Format rupees as crore, the unit Indian banks report in."""
    return f"₹{amount / 1e7:,.2f} Cr"


# ---------------------------------------------------------------
# Data
# ---------------------------------------------------------------

# Portfolio totals for every month (used for KPIs and trends)
portfolio = run_query(
    """
    SELECT
        snapshot_date,
        SUM(active_loans) AS active_loans,
        SUM(total_outstanding) AS total_outstanding,
        SUM(npa_outstanding) AS npa_outstanding,
        SUM(par30_outstanding) AS par30_outstanding,
        SUM(amount_due) AS amount_due,
        SUM(amount_collected) AS amount_collected
    FROM FCT_BRANCH_MONTHLY_METRICS
    GROUP BY snapshot_date
    ORDER BY snapshot_date
    """
)

portfolio["gnpa_pct"] = (
    100 * portfolio["npa_outstanding"] / portfolio["total_outstanding"]
)

portfolio["par30_pct"] = (
    100 * portfolio["par30_outstanding"] / portfolio["total_outstanding"]
)

portfolio["collection_efficiency_pct"] = (
    100 * portfolio["amount_collected"] / portfolio["amount_due"]
)


# ---------------------------------------------------------------
# Sidebar
# ---------------------------------------------------------------

st.sidebar.title("LoanPulse")
st.sidebar.caption("Loan portfolio health for a microfinance lender")

months = portfolio["snapshot_date"].tolist()

selected_month = st.sidebar.selectbox(
    "Month-end",
    options=months[::-1],  # Latest first
    format_func=lambda d: d.strftime("%b %Y"),
)

st.sidebar.divider()


st.sidebar.caption("Access role: ANALYST (customer PII masked)")


# ---------------------------------------------------------------
# Header and KPIs
# ---------------------------------------------------------------

st.title("Loan Portfolio Health")
st.caption(f"Month-end: {selected_month.strftime('%d %b %Y')}")

current = portfolio[portfolio["snapshot_date"] == selected_month].iloc[0]

position = months.index(selected_month)
previous = portfolio.iloc[position - 1] if position > 0 else current

col1, col2, col3, col4, col5 = st.columns(5)

col1.metric(
    "Outstanding",
    to_crore(current["total_outstanding"]),
)

col2.metric(
    "Active loans",
    f"{int(current['active_loans']):,}",
)

col3.metric(
    "GNPA",
    f"{current['gnpa_pct']:.2f}%",
    delta=f"{current['gnpa_pct'] - previous['gnpa_pct']:+.2f} pts",
    delta_color="inverse",  # Going up is bad
)

col4.metric(
    "PAR 30",
    f"{current['par30_pct']:.2f}%",
    delta=f"{current['par30_pct'] - previous['par30_pct']:+.2f} pts",
    delta_color="inverse",
)

col5.metric(
    "Collection efficiency",
    f"{current['collection_efficiency_pct']:.1f}%",
    delta=(
        f"{current['collection_efficiency_pct'] - previous['collection_efficiency_pct']:+.1f} pts"
    ),
)

tab_overview, tab_branches, tab_roll, tab_vintage, tab_quality = st.tabs(
    ["Portfolio", "Branches", "Roll rates", "Vintages", "Data quality"]
)


# ---------------------------------------------------------------
# Tab 1: Portfolio overview
# ---------------------------------------------------------------

with tab_overview:
    left, right = st.columns(2)

    with left:
        st.subheader("Risk trend")

        trend = portfolio.melt(
            id_vars="snapshot_date",
            value_vars=["gnpa_pct", "par30_pct"],
            var_name="metric",
            value_name="percent",
        )

        trend["metric"] = trend["metric"].map(
            {
                "gnpa_pct": "GNPA %",
                "par30_pct": "PAR 30 %",
            }
        )

        fig = px.line(
            trend,
            x="snapshot_date",
            y="percent",
            color="metric",
            markers=True,
        )

        fig.update_layout(
            xaxis_title=None,
            yaxis_title="% of outstanding",
            legend_title=None,
        )

        st.plotly_chart(fig, width="stretch")

    with right:
        st.subheader("RBI asset classification")

        classes = run_query(
            """
            SELECT
                asset_class,
                COUNT(*) AS loans,
                SUM(outstanding_principal) AS outstanding
            FROM FCT_PORTFOLIO_MONTH_END_SNAPSHOT
            WHERE snapshot_date = %s
            GROUP BY asset_class
            """,
            (selected_month,),
        )

        fig = px.bar(
            classes,
            x="asset_class",
            y="outstanding",
            color="asset_class",
            text="loans",
            category_orders={"asset_class": ASSET_CLASS_ORDER},
            color_discrete_map=ASSET_CLASS_COLORS,
        )

        fig.update_layout(
            xaxis_title=None,
            yaxis_title="Outstanding (₹)",
            showlegend=False,
        )

        fig.update_traces(
            texttemplate="%{text} loans",
            textposition="outside",
        )

        st.plotly_chart(fig, width="stretch")


# ---------------------------------------------------------------
# Tab 2: Branch stress
# ---------------------------------------------------------------

with tab_branches:
    branch_names = run_query(
        """
        SELECT DISTINCT
            branch_id,
            branch_name,
            district,
            state
        FROM DIM_CUSTOMERS
        """
    )

    branches = run_query(
        """
        SELECT
            branch_id,
            active_loans,
            total_outstanding,
            gnpa_pct,
            par30_pct,
            collection_efficiency_pct
        FROM FCT_BRANCH_MONTHLY_METRICS
        WHERE snapshot_date = %s
        """,
        (selected_month,),
    )

    branches = branches.merge(
        branch_names,
        on="branch_id",
        how="left",
    )

    branches = branches.sort_values(
        "gnpa_pct",
        ascending=False,
    )

    worst = branches.iloc[0]

    st.subheader("Where is stress building?")

    st.write(
        f"**{worst['branch_name']} ({worst['district']})** "
        f"has the highest GNPA at **{worst['gnpa_pct']:.2f}%**, "
        f"with collection efficiency of "
        f"{worst['collection_efficiency_pct']:.1f}%."
    )

    fig = px.bar(
        branches,
        x="gnpa_pct",
        y="branch_name",
        orientation="h",
        color="gnpa_pct",
        color_continuous_scale="Reds",
        hover_data=[
            "district",
            "state",
            "par30_pct",
            "collection_efficiency_pct",
        ],
    )

    fig.update_layout(
        yaxis={"categoryorder": "total ascending"},
        xaxis_title="GNPA %",
        yaxis_title=None,
        coloraxis_showscale=False,
    )

    st.plotly_chart(fig, width="stretch")

    st.dataframe(
        branches[
            [
                "branch_name",
                "district",
                "state",
                "active_loans",
                "total_outstanding",
                "gnpa_pct",
                "par30_pct",
                "collection_efficiency_pct",
            ]
        ],
        hide_index=True,
        width="stretch",
        column_config={
            "branch_name": "Branch",
            "district": "District",
            "state": "State",
            "active_loans": "Active loans",
            "total_outstanding": st.column_config.NumberColumn(
                "Outstanding (₹)",
                format="%,.0f",
            ),
            "gnpa_pct": st.column_config.NumberColumn(
                "GNPA %",
                format="%.2f",
            ),
            "par30_pct": st.column_config.NumberColumn(
                "PAR 30 %",
                format="%.2f",
            ),
            "collection_efficiency_pct": st.column_config.NumberColumn(
                "Collection eff. %",
                format="%.1f",
            ),
        },
    )


# ---------------------------------------------------------------
# Tab 3: Roll rates
# ---------------------------------------------------------------

with tab_roll:
    st.subheader("Where did last month's loans move?")

    st.caption(
        "Each row is last month's category. Each cell is the % of those "
        "loans in this month's category. Rows add up to 100%."
    )

    roll = run_query(
        """
        SELECT
            from_class,
            to_class,
            pct_of_from_class
        FROM FCT_MONTHLY_ROLL_RATES
        WHERE snapshot_date = %s
        """,
        (selected_month,),
    )

    if roll.empty:
        st.info(
            "No roll rates for the first month "
            "(there is no previous month)."
        )
    else:
        matrix = (
            roll.pivot(
                index="from_class",
                columns="to_class",
                values="pct_of_from_class",
            )
            .reindex(
                index=ASSET_CLASS_ORDER,
                columns=ASSET_CLASS_ORDER,
            )
            .fillna(0)
        )

        fig = px.imshow(
            matrix,
            text_auto=".1f",
            color_continuous_scale="Reds",
            labels={
                "x": "This month",
                "y": "Last month",
                "color": "%",
            },
            aspect="auto",
        )

        st.plotly_chart(fig, width="stretch")

        sma1_to_sma2 = matrix.loc["SMA_1", "SMA_2"]
        sma0_cure = matrix.loc["SMA_0", "STANDARD"]

        st.write(
            f"**{sma0_cure:.0f}%** of SMA-0 loans cured back to Standard, "
            f"but **{sma1_to_sma2:.0f}%** of SMA-1 loans rolled forward "
            "to SMA-2. Collections effort pays off most at the SMA-0 stage."
        )


# ---------------------------------------------------------------
# Tab 4: Vintage analysis
# ---------------------------------------------------------------

with tab_vintage:
    st.subheader("Are newer loans riskier than older ones?")

    st.caption(
        "Each line is a group of loans disbursed in the same month. "
        "It shows the % of those loans that were more than 30 days late, "
        "by months since disbursement."
    )

    vintages = run_query(
        """
        SELECT
            vintage_month,
            months_on_book,
            loans_disbursed,
            par30_loans_pct
        FROM FCT_VINTAGE_PERFORMANCE
        ORDER BY vintage_month, months_on_book
        """
    )

    vintages["vintage"] = (
        pd.to_datetime(vintages["vintage_month"]).dt.strftime("%b %Y")
    )

    all_vintages = vintages["vintage"].unique().tolist()

    default_vintages = [
        vintage
        for vintage in ["Jan 2025", "Apr 2025", "Jul 2025", "Oct 2025"]
        if vintage in all_vintages
    ]

    chosen = st.multiselect(
        "Vintages",
        all_vintages,
        default=default_vintages,
    )

    fig = px.line(
        vintages[vintages["vintage"].isin(chosen)],
        x="months_on_book",
        y="par30_loans_pct",
        color="vintage",
        markers=True,
    )

    fig.update_layout(
        xaxis_title="Months since disbursement",
        yaxis_title="% of loans 30+ days late",
        legend_title="Disbursed in",
    )

    st.plotly_chart(fig, width="stretch")


# ---------------------------------------------------------------
# Tab 5: Data quality and governance
# ---------------------------------------------------------------

with tab_quality:
    st.subheader("Reported vs restated")

    st.caption(
        "Month-end numbers are frozen when reported. Payments recorded "
        "after month-end can change a loan's real status. This shows how "
        "many loans were later reclassified."
    )

    restatements = run_query(
        """
        SELECT
            snapshot_date,
            loans_reported,
            loans_reclassified,
            reported_npa_outstanding,
            restated_npa_outstanding
        FROM RPT_MONTH_END_RESTATEMENTS
        ORDER BY snapshot_date
        """
    )

    fig = px.bar(
        restatements,
        x="snapshot_date",
        y="loans_reclassified",
    )

    fig.update_layout(
        xaxis_title=None,
        yaxis_title="Loans reclassified after reporting",
    )

    st.plotly_chart(fig, width="stretch")

    st.write(
        f"Total reclassifications across all months: "
        f"**{int(restatements['loans_reclassified'].sum()):,}**"
    )

    st.divider()

    st.subheader("Customer lookup")

    st.caption(
        "This dashboard uses the ANALYST role. "
        "Name, phone and Aadhaar are masked."
    )

    customer_id = st.text_input(
        "Customer ID",
        value="CUST00001",
    )

    if customer_id:
        customer = run_query(
            """
            SELECT
                customer_id,
                full_name,
                phone,
                aadhaar_number,
                occupation,
                branch_name,
                district
            FROM DIM_CUSTOMERS
            WHERE customer_id = %s
            """,
            (customer_id.strip().upper(),),
        )

        if customer.empty:
            st.warning("Customer not found.")
        else:
            st.dataframe(
                customer,
                hide_index=True,
                width="stretch",
            )