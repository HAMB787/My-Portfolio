"""
════════════════════════════════════════════════════════════════════════
  Non-Linear Balanced Transportation Problem
  Dynamic Programming  ·  Bellman's Principle
  2 Quarries  →  7 Construction Sites
════════════════════════════════════════════════════════════════════════
"""

import math
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
from matplotlib.patches import FancyBboxPatch
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.text import Text
from rich import box
from rich.rule import Rule
from rich.align import Align

console = Console()

# ════════════════════════════════════════════════════════════════════
#  CORE DP  —  MATHEMATICAL LOGIC UNTOUCHED
# ════════════════════════════════════════════════════════════════════
def solve_sand_distribution():
    b      = [10, 15, 5, 8, 12, 7, 13]
    a1     = 30
    # a2 = 40 is implicit: x2j = bj - x1j  (balanced problem)

    c1     = [13, 18, 15, 10, 16, 12, 14]
    c2     = [14, 12, 17,  8, 20, 14, 13]
    alpha1 = [0.10, 0.09, 0.08, 0.07, 0.10, 0.12, 0.10]
    alpha2 = [0.08, 0.10, 0.07, 0.12, 0.09, 0.11, 0.06]

    n      = len(b)
    dp     = [[float('inf')] * (a1 + 1) for _ in range(n + 1)]
    parent = [[0]            * (a1 + 1) for _ in range(n + 1)]
    dp[n][0] = 0.0   # base case: no remaining supply, zero cost

    stage_data = []  # accumulate display info per stage

    # ── Backward induction (Bellman equations) ──────────────────────
    for k in range(n - 1, -1, -1):
        for s in range(a1 + 1):
            for x1 in range(min(s, b[k]) + 1):
                x2         = b[k] - x1
                cost       = (c1[k] * (1 - math.exp(-alpha1[k] * x1)) +
                              c2[k] * (1 - math.exp(-alpha2[k] * x2)))
                total_cost = cost + dp[k + 1][s - x1]
                if total_cost < dp[k][s]:
                    dp[k][s]     = total_cost
                    parent[k][s] = x1

        # Collect feasible rows for this stage
        rows      = []
        stage_min = float('inf')
        for s in range(a1 + 1):
            if dp[k][s] != float('inf'):
                x1v = parent[k][s]
                rows.append((s, x1v, b[k] - x1v, dp[k][s]))
                if dp[k][s] < stage_min:
                    stage_min = dp[k][s]

        stage_data.append({
            "stage":    k + 1,
            "demand":   b[k],
            "rows":     rows,
            "min_cost": stage_min,
            "c1": c1[k], "c2": c2[k],
            "a1": alpha1[k], "a2": alpha2[k],
        })

    # ── Forward traceback to recover optimal allocation ──────────────
    x1_opt, x2_opt, costs_opt = [], [], []
    current_s = a1
    for k in range(n):
        bx1   = parent[k][current_s]
        bx2   = b[k] - bx1
        c_val = (c1[k] * (1 - math.exp(-alpha1[k] * bx1)) +
                 c2[k] * (1 - math.exp(-alpha2[k] * bx2)))
        x1_opt.append(bx1)
        x2_opt.append(bx2)
        costs_opt.append(c_val)
        current_s -= bx1

    # Հեռացվել է stage_data.reverse() հրամանը, որպեսզի փուլերը տպվեն 7-ից 1
    return dp[0][a1], x1_opt, x2_opt, costs_opt, stage_data


# ════════════════════════════════════════════════════════════════════
#  RICH  —  HEADER BANNER
# ════════════════════════════════════════════════════════════════════
def print_header():
    header = Text(justify="center")
    header.append("\n  ՈՉ ԳԾԱՅԻՆ ՓԱԿ ՏՐԱՆՍՊՈՐՏԱՅԻՆ ԽՆԴԻՐ  \n",
                  style="bold white on dark_blue")
    header.append("  Դինամիկ Ծրագրավորում  ·  Բելմանի Սկզբունք  \n",
                  style="bold cyan on dark_blue")
    header.append("  M = 2 Հանք   →   N = 7 Շին. Օբյեկտ (Շենք)  \n",
                  style="italic dim white on dark_blue")
    console.print(Panel(header, border_style="bright_blue",
                        padding=(0, 4), expand=False))
    console.print()


# ════════════════════════════════════════════════════════════════════
#  RICH  —  STAGE ITERATION TABLE
# ════════════════════════════════════════════════════════════════════
def print_stage_table(info: dict):
    stage    = info["stage"]
    demand   = info["demand"]
    rows     = info["rows"]
    min_cost = info["min_cost"]

    table = Table(
        title=(
            f"[bold cyan]Փուլ {stage}[/bold cyan]  ·  "
            f"Պահանջարկ b_{stage} = [bright_yellow]{demand}[/bright_yellow] տ  ·  "
            f"c₁={info['c1']}  c₂={info['c2']}  "
            f"α₁={info['a1']}  α₂={info['a2']}"
        ),
        caption=(
            f"[bold green]▶  Օպտիմալ (Մինիմալ ծախս)  φ_{stage}(Z) = {min_cost:.4f}[/bold green]"
        ),
        box=box.ROUNDED,
        border_style="bright_blue",
        header_style="bold bright_white on navy_blue",
        show_lines=False,
        expand=False,
    )

    table.add_column("Z_k  (1-ին հանքի պաշար)", justify="right",
                     style="bright_cyan",     min_width=22)
    table.add_column("X₁ₖ  (1-ին հանքից)",      justify="center",
                     style="bright_green",    min_width=18)
    table.add_column("X₂ₖ  (2-րդ հանքից)",      justify="center",
                     style="bright_magenta",  min_width=18)
    table.add_column("φ_k(Z_k)",             justify="right",
                     style="bright_yellow",   min_width=14)

    for zk, x1, x2, phi in rows:
        is_opt     = abs(phi - min_cost) < 1e-9
        row_style  = "bold on dark_green" if is_opt else ""
        marker     = "  ★" if is_opt else ""
        table.add_row(
            str(zk), str(x1), str(x2),
            f"{phi:.4f}{marker}",
            style=row_style,
        )

    console.print(Align.center(table))
    console.print()


# ════════════════════════════════════════════════════════════════════
#  RICH  —  FINAL RESULT TABLE
# ════════════════════════════════════════════════════════════════════
def print_final_table(x1_opt, x2_opt, costs_opt, min_z):
    console.print(Rule(
        "[bold bright_white]  ՕՊՏԻՄԱԼ ԼՈՒԾՈՒՄ  [/bold bright_white]",
        style="bright_yellow",
    ))
    console.print()

    table = Table(
        title="[bold bright_white]Ավազի Վերջնական Օպտիմալ Բաշխում[/bold bright_white]",
        caption=(
            f"[bold bright_green]"
            f"✔  Գլոբալ Նվազագույն Ծախս  L* = {min_z:.4f}"
            f"[/bold bright_green]"
        ),
        box=box.DOUBLE_EDGE,
        border_style="bright_yellow",
        header_style="bold black on bright_yellow",
        expand=False,
        min_width=72,
        show_lines=True, # ԱՎԵԼԱՑՎԱԾ Է, որպեսզի տերմինալը հստակ գծի բոլոր տողերը
    )

    table.add_column("Շենք",           justify="center", style="bold white",         min_width=8)
    table.add_column("Պահանջարկ (տ)",  justify="center", style="bright_cyan",        min_width=15)
    table.add_column("X₁ⱼ (1-ինից)", justify="center", style="bold bright_green",  min_width=14)
    table.add_column("X₂ⱼ (2-րդից)", justify="center", style="bold bright_magenta",min_width=14)
    table.add_column("1-ինի բաժին",       justify="center", style="green",              min_width=12)
    table.add_column("Ծախս  φⱼ",      justify="right",  style="bright_yellow",      min_width=12)

    demands    = [10, 15, 5, 8, 12, 7, 13]
    total_q1   = total_q2 = total_cost = 0

    for i in range(7):
        d   = demands[i]
        q1  = x1_opt[i]
        q2  = x2_opt[i]
        pct = f"{100 * q1 / d:.1f}%"
        table.add_row(
            f"Շենք {i + 1}", str(d),
            f"{q1} տ", f"{q2} տ", pct,
            f"{costs_opt[i]:.4f}",
        )
        total_q1   += q1
        total_q2   += q2
        total_cost += costs_opt[i]

    table.add_row(
        "[bold]ԸՆԴԱՄԵՆԸ[/bold]", "[bold]70 տ[/bold]",
        f"[bold]{total_q1} տ[/bold]", f"[bold]{total_q2} տ[/bold]",
        f"[bold]{100 * total_q1 / 70:.1f}%[/bold]",
        f"[bold bright_green]{total_cost:.4f}[/bold bright_green]",
        style="bold on grey11"
    )

    console.print(Align.center(table))
    console.print()

    # ── Constraint verification ──────────────────────────────────────
    chk = Text(justify="left")
    chk.append("  1-ին հանքի օգտագործված պաշար:  ", style="dim")
    chk.append(f"{total_q1} / 30 տ  ", style="bold bright_green")
    chk.append("✔\n" if total_q1 == 30 else "✘\n",
               style="bold green" if total_q1 == 30 else "bold red")
    chk.append("  2-րդ հանքի օգտագործված պաշար:  ", style="dim")
    chk.append(f"{total_q2} / 40 տ  ", style="bold bright_green")
    chk.append("✔\n" if total_q2 == 40 else "✘\n",
               style="bold green" if total_q2 == 40 else "bold red")
    chk.append("  Բալանսավորված (1-ին+2-րդ = 70):  ", style="dim")
    ok = (total_q1 + total_q2 == 70)
    chk.append("Այո  ✔" if ok else "Ոչ  ✘",
               style="bold bright_green" if ok else "bold red")

    console.print(Panel(chk, title="[bold]Սահմանափակումների Ստուգում[/bold]",
                        border_style="green", expand=False))
    console.print()


# ════════════════════════════════════════════════════════════════════
#  MATPLOTLIB  —  4-PANEL THESIS DASHBOARD
# ════════════════════════════════════════════════════════════════════
def plot_dashboard(x1_opt, x2_opt, costs_opt, min_z):
    demands = [10, 15, 5, 8, 12, 7, 13]
    sites   = [f"Շենք {i+1}" for i in range(7)]
    n       = 7
    x       = np.arange(n)

    # ── Design tokens ───────────────────────────────────────────────
    CLR_Q1    = "#4FC3F7"   # sky-blue
    CLR_Q2    = "#CE93D8"   # soft violet
    CLR_COST  = "#FFD54F"   # amber
    CLR_BG    = "#0D1117"   # dark background
    CLR_PANEL = "#161B22"
    CLR_GRID  = "#21262D"
    CLR_TEXT  = "#E6EDF3"
    CLR_SUB   = "#8B949E"
    CLR_ACC   = "#58A6FF"
    CLR_HIGH  = "#FF7043"

    plt.rcParams.update({
        "figure.facecolor":  CLR_BG,
        "axes.facecolor":    CLR_PANEL,
        "axes.edgecolor":    CLR_GRID,
        "axes.labelcolor":   CLR_TEXT,
        "xtick.color":       CLR_TEXT,
        "ytick.color":       CLR_TEXT,
        "text.color":        CLR_TEXT,
        "grid.color":        CLR_GRID,
        "grid.linewidth":    0.8,
        "font.family":       "DejaVu Sans",
    })

    fig = plt.figure(figsize=(18, 11), facecolor=CLR_BG)
    fig.suptitle(
        "ՈՉ ԳԾԱՅԻՆ ՓԱԿ ՏՐԱՆՍՊՈՐՏԱՅԻՆ ԽՆԴԻՐ  ·  ՕՊՏԻՄԱԼ ԲԱՇԽՄԱՆ ՎԱՀԱՆԱԿ",
        fontsize=15, fontweight="bold", color=CLR_TEXT, y=0.975,
    )
    fig.text(
        0.5, 0.945,
        f"Դինամիկ Ծրագրավորում (Բելման)  "
        f"·  Գլոբալ Մինիմում  L* = {min_z:.4f}  "
        f"·  2 Հանք և 7 Շենք",
        ha="center", fontsize=11, color=CLR_ACC,
    )

    gs = gridspec.GridSpec(
        2, 3, figure=fig,
        hspace=0.44, wspace=0.34,
        left=0.06, right=0.97, top=0.90, bottom=0.07,
    )

    bar_w = 0.55  # shared bar width

    # ──────────────────────────────────────────────────────────────
    #  Panel 1 · Stacked allocation bar + demand overlay
    # ──────────────────────────────────────────────────────────────
    ax1 = fig.add_subplot(gs[0, :2])

    bars1 = ax1.bar(x, x1_opt, bar_w, label="Հանք 1",
                    color=CLR_Q1, zorder=3, alpha=0.93)
    bars2 = ax1.bar(x, x2_opt, bar_w, bottom=x1_opt,
                    label="Հանք 2",
                    color=CLR_Q2, zorder=3, alpha=0.93)
    ax1.plot(x, demands, "o--", color="#FF8A65", linewidth=2.0,
             markersize=8, label="Պահանջարկ  bⱼ", zorder=4)

    # Inline value labels
    for i, (v1, v2) in enumerate(zip(x1_opt, x2_opt)):
        if v1 > 1:
            ax1.text(i, v1 / 2, f"{v1}տ",
                     ha="center", va="center", fontsize=10,
                     fontweight="bold", color=CLR_BG, zorder=5)
        if v2 > 1:
            ax1.text(i, v1 + v2 / 2, f"{v2}տ",
                     ha="center", va="center", fontsize=10,
                     fontweight="bold", color=CLR_BG, zorder=5)

    ax1.set_title("Ավազի բաշխումն ըստ շենքերի (Հանք 1 + Հանք 2)",
                  fontsize=12, fontweight="bold", color=CLR_TEXT, pad=9)
    ax1.set_xticks(x)
    ax1.set_xticklabels(sites, fontsize=10)
    ax1.set_ylabel("Տոննա", fontsize=10)
    ax1.set_ylim(0, max(demands) * 1.28)
    ax1.yaxis.grid(True, zorder=0)
    ax1.set_axisbelow(True)
    ax1.legend(loc="upper right", fontsize=10,
               facecolor=CLR_PANEL, edgecolor=CLR_GRID, labelcolor=CLR_TEXT)

    # ──────────────────────────────────────────────────────────────
    #  Panel 2 · Donut: total Q1 vs Q2 supply
    # ──────────────────────────────────────────────────────────────
    ax2 = fig.add_subplot(gs[0, 2])
    total_q1 = sum(x1_opt)
    total_q2 = sum(x2_opt)
    wedge_kw = {"edgecolor": CLR_BG, "linewidth": 2.5, "width": 0.55}
    wedges, texts, autotexts = ax2.pie(
        [total_q1, total_q2],
        labels=["Հանք 1\n30 տ", "Հանք 2\n40 տ"],
        colors=[CLR_Q1, CLR_Q2],
        autopct="%1.1f%%",
        startangle=90,
        explode=(0.04, 0.04),
        textprops={"color": CLR_TEXT, "fontsize": 11},
        wedgeprops=wedge_kw,
        pctdistance=0.75,
    )
    for at in autotexts:
        at.set_fontsize(11)
        at.set_fontweight("bold")
        at.set_color(CLR_BG)
    # Centre label
    ax2.text(0, 0, "70 տ\nընդամենը", ha="center", va="center",
             fontsize=12, fontweight="bold", color=CLR_TEXT)
    ax2.set_title("Պաշարների Բաշխում\n(Հանք 1 և Հանք 2  ·  ընդամենը 70 տ)",
                  fontsize=12, fontweight="bold", color=CLR_TEXT, pad=11)

    # ──────────────────────────────────────────────────────────────
    #  Panel 3 · Site-level cost φⱼ
    # ──────────────────────────────────────────────────────────────
    ax3 = fig.add_subplot(gs[1, :2])
    mean_c     = np.mean(costs_opt)
    bar_colors = [CLR_COST if c <= mean_c else CLR_HIGH for c in costs_opt]
    bars3      = ax3.bar(x, costs_opt, bar_w, color=bar_colors,
                         zorder=3, alpha=0.93)
    ax3.axhline(mean_c, color=CLR_ACC, linewidth=1.6, linestyle="--",
                zorder=4, label=f"Միջին  {mean_c:.4f}")

    for bar, val in zip(bars3, costs_opt):
        ax3.text(
            bar.get_x() + bar.get_width() / 2,
            bar.get_height() + 0.04,
            f"{val:.3f}",
            ha="center", va="bottom", fontsize=10, color=CLR_TEXT, zorder=5,
        )

    ax3.set_title("Նպատակային ծախսն ըստ շենքերի  φⱼ",
                  fontsize=12, fontweight="bold", color=CLR_TEXT, pad=9)
    ax3.set_xticks(x)
    ax3.set_xticklabels(sites, fontsize=10)
    ax3.set_ylabel("φⱼ", fontsize=11)
    ax3.yaxis.grid(True, zorder=0)
    ax3.set_axisbelow(True)

    # Custom legend patches
    from matplotlib.patches import Patch
    ax3.legend(
        handles=[
            Patch(facecolor=CLR_COST, label=f"≤ միջին  ({mean_c:.3f})"),
            Patch(facecolor=CLR_HIGH, label="> միջին"),
            plt.Line2D([0], [0], color=CLR_ACC, linewidth=1.6,
                       linestyle="--", label=f"Միջին  {mean_c:.4f}"),
        ],
        fontsize=10, facecolor=CLR_PANEL,
        edgecolor=CLR_GRID, labelcolor=CLR_TEXT, loc="upper right",
    )

    # ──────────────────────────────────────────────────────────────
    #  Panel 4 · KPI summary card
    # ──────────────────────────────────────────────────────────────
    ax4 = fig.add_subplot(gs[1, 2])
    ax4.set_axis_off()
    ax4.set_xlim(0, 1)
    ax4.set_ylim(0, 7.8)

    kpis = [
        ("Գլոբալ Մինիմալ Ծախս  L*",   f"{min_z:.4f}",           CLR_ACC),
        ("1-ին Հանքից Տրամադրված",   f"{total_q1} / 30 տ",     CLR_Q1),
        ("2-րդ Հանքից Տրամադրված",   f"{total_q2} / 40 տ",     CLR_Q2),
        ("Բավարարված Պահանջարկ", "70 / 70 տ  ✔",          "#69F0AE"),
        ("Սպասարկված Շենքեր",          "7-ից 7",                  CLR_COST),
        ("Մաքսիմալ Ծախս  φ_max",  f"{max(costs_opt):.4f}",  CLR_HIGH),
        ("Մինիմալ Ծախս  φ_min",  f"{min(costs_opt):.4f}",  "#69F0AE"),
    ]

    for i, (label, value, color) in enumerate(reversed(kpis)):
        y = i * 1.05 + 0.15
        rect = FancyBboxPatch(
            (0.02, y - 0.28), 0.96, 0.78,
            boxstyle="round,pad=0.05",
            facecolor=CLR_GRID, edgecolor="none", zorder=1,
        )
        ax4.add_patch(rect)
        ax4.text(0.07, y + 0.10, label, fontsize=10,
                 color=CLR_SUB, va="center", zorder=2)
        ax4.text(0.93, y + 0.10, value, fontsize=11,
                 color=color, va="center", ha="right",
                 fontweight="bold", zorder=2)

    ax4.set_title("Լուծման Ամփոփում",
                  fontsize=12, fontweight="bold", color=CLR_TEXT, pad=9)

    # ── Save ────────────────────────────────────────────────────────
    out_path = "transportation_dp_dashboard.png"
    plt.savefig(out_path, dpi=150, bbox_inches="tight", facecolor=CLR_BG)
    console.print(
        Panel(
            f"[bold green]✔  Գրաֆիկը պահպանված է →[/bold green]  "
            f"[bright_cyan]{out_path}[/bright_cyan]",
            border_style="green", expand=False,
        )
    )
    plt.show()


# ════════════════════════════════════════════════════════════════════
#  ENTRY POINT
# ════════════════════════════════════════════════════════════════════
if __name__ == "__main__":
    print_header()

    min_z, x1_opt, x2_opt, costs_opt, stage_data = solve_sand_distribution()

    # ── Stage-by-stage Bellman tables ───────────────────────────────
    console.print(Rule(
        "[bold bright_cyan]  ԲԵԼՄԱՆԻ ՀԵՏԸՆԹԱՑ ԻՏԵՐԱՑԻՈՆ ԱՂՅՈՒՍԱԿՆԵՐ  [/bold bright_cyan]",
        style="bright_blue",
    ))
    console.print()
    for info in stage_data:
        print_stage_table(info)

    # ── Final solution ───────────────────────────────────────────────
    print_final_table(x1_opt, x2_opt, costs_opt, min_z)

    # ── Dashboard chart ─────────────────────────────────────────────
    plot_dashboard(x1_opt, x2_opt, costs_opt, min_z)