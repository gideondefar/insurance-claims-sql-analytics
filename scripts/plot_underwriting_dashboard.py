#!/usr/bin/env python3
"""Create a portfolio risk-monitoring dashboard from synthetic underwriting KPIs.

Run: pip install matplotlib
     python3 scripts/plot_underwriting_dashboard.py

Input: reports/portfolio_kpis.csv
Output: assets/underwriting_performance_dashboard.png and .svg
"""
from __future__ import annotations

import csv
from datetime import date
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch

ROOT = Path(__file__).resolve().parents[1]
INPUT = ROOT / "reports" / "portfolio_kpis.csv"
OUTPUT = ROOT / "assets"
DARK, BLUE, RED, MUTED = "#14243b", "#2f71bc", "#c94a48", "#66768b"


def data_rows():
    with INPUT.open(newline="", encoding="utf-8-sig") as stream:
        rows = list(csv.DictReader(stream))
    if len(rows) != 2:
        raise ValueError("Expected exactly two reporting-period rows")
    out = []
    for r in rows:
        d = {field: float(r[field]) for field in (
            "earned_premium_gbp", "incurred_gbp", "paid_gbp", "reserves_gbp",
            "claims", "earned_policy_years", "claims_per_100_policy_years",
            "incurred_loss_ratio_pct")}
        d["period"] = "H1 " + str(date.fromisoformat(r["period_start"]).year)
        if d["earned_premium_gbp"] <= 0 or d["earned_policy_years"] <= 0:
            raise ValueError("Earned premiums and policy-years must be positive")
        if abs(d["incurred_gbp"] - d["paid_gbp"] - d["reserves_gbp"]) > .01:
            raise ValueError("Incurred claims must equal paid plus reserves")
        if abs(100*d["incurred_gbp"]/d["earned_premium_gbp"]
               - d["incurred_loss_ratio_pct"]) > .011:
            raise ValueError("Loss ratio does not reconcile")
        if abs(100*d["claims"]/d["earned_policy_years"]
               - d["claims_per_100_policy_years"]) > .011:
            raise ValueError("Claims frequency does not reconcile")
        out.append(d)
    return out


def box(fig, xywh, fill, stroke="#dbe4ed"):
    x, y, w, h = xywh
    fig.add_artist(FancyBboxPatch(
        (x, y), w, h, boxstyle="round,pad=.008,rounding_size=.012",
        transform=fig.transFigure, facecolor=fill, edgecolor=stroke,
        linewidth=1.0, zorder=0))


def main():
    data = data_rows()
    periods = [r["period"] for r in data]
    ratios = [r["incurred_loss_ratio_pct"] for r in data]
    frequencies = [r["claims_per_100_policy_years"] for r in data]
    plt.rcParams.update({"font.family": "DejaVu Sans"})
    fig = plt.figure(figsize=(14, 9), dpi=150, facecolor="#f5f8fc")
    fig.text(.06, .948, "INSURANCE PERFORMANCE MONITOR", weight="bold",
             color=BLUE, fontsize=11)
    fig.text(.06, .903, "Underwriting signals | H1 2025 vs H1 2026",
             weight="bold", color=DARK, fontsize=23)
    fig.text(.06, .87, "Synthetic UK motor & home portfolio  •  "
             "48 fictional policies  •  10 claims across both periods",
             color=MUTED, fontsize=10)
    box(fig, (.05, .355, .435, .46), "white")
    box(fig, (.515, .355, .435, .46), "white")
    box(fig, (.05, .245, .9, .083), "white")
    box(fig, (.05, .095, .9, .125), "#fff1f0", "#efc1bf")

    for x, title, subtitle in (
        (.082, "INCURRED LOSS RATIO", "Incurred claims ÷ earned premium"),
        (.548, "CLAIMS FREQUENCY", "Claims per 100 earned policy-years")):
        fig.text(x, .785, title, color=DARK, weight="bold", fontsize=12)
        fig.text(x, .759, subtitle, color=MUTED, fontsize=9)

    def panel(rect, values, cols, labels, ymax, yticks, formatter):
        ax = fig.add_axes(rect)
        ax.set_facecolor("white")
        bars = ax.bar([0, 1], values, width=.52, color=cols, zorder=3)
        ax.set_ylim(0, ymax)
        ax.set_xticks([0, 1], periods)
        ax.set_yticks(yticks, labels)
        ax.grid(axis="y", color="#dbe4ed", linewidth=.8)
        ax.set_axisbelow(True)
        ax.tick_params(length=0, labelcolor=DARK)
        for edge in ax.spines.values():
            edge.set_visible(False)
        for bar, value in zip(bars, values):
            ax.text(bar.get_x()+bar.get_width()/2, value+ymax*.02,
                    formatter(value), ha="center", color=DARK,
                    weight="bold", fontsize=13)
        return ax

    left = panel([.085, .415, .35, .295], ratios, [BLUE, RED],
                 ["0%", "50%", "100%", "150%"], 155,
                 [0, 50, 100, 150], lambda v: f"{v:.2f}%")
    left.axhline(100, linestyle="--", color=RED, linewidth=1.4)
    left.text(-.32, 105, "100% reference", color=RED, fontsize=8)
    left.text(.5, .94, f"+{ratios[1]-ratios[0]:.2f} percentage points",
              transform=left.transAxes, ha="center", fontsize=9,
              weight="bold", color=RED,
              bbox=dict(boxstyle="round,pad=.4", facecolor="#fff1f0",
                        edgecolor="none"))

    right = panel([.55, .415, .35, .295], frequencies,
                  ["#a3c9ee", BLUE], ["0", "10", "20", "30"],
                  33, [0, 10, 20, 30], lambda v: f"{v:.2f}")
    right.text(.5, .94, f"+{100*(frequencies[1]/frequencies[0]-1):.0f}% increase",
               transform=right.transAxes, ha="center", fontsize=9,
               weight="bold", color=BLUE,
               bbox=dict(boxstyle="round,pad=.4", facecolor="#e7f1fc",
                         edgecolor="none"))

    premium_growth = 100*(data[1]["earned_premium_gbp"] /
                          data[0]["earned_premium_gbp"]-1)
    cost_growth = 100*(data[1]["incurred_gbp"]/data[0]["incurred_gbp"]-1)
    for x, big, small in (
        (.085, f"+{premium_growth:.1f}%", "Earned premium growth"),
        (.38, f"+{cost_growth:.1f}%", "Incurred claims-cost growth"),
        (.68, f'{int(data[0]["claims"])} → {int(data[1]["claims"])}',
         "Number of claims")):
        fig.text(x, .294, big, color=DARK, weight="bold", fontsize=15)
        fig.text(x, .264, small, color=MUTED, fontsize=9)

    fig.text(.081, .182, "RISK SIGNAL • INVESTIGATE, NOT A PRICING DECISION",
             color=RED, weight="bold", fontsize=11)
    fig.text(.081, .15,
             f'H1 2026 loss ratio exceeded 100%: '
             f'£{data[1]["incurred_gbp"]:,.0f} incurred vs '
             f'£{data[1]["earned_premium_gbp"]:,.0f} earned premiums.',
             color=DARK, fontsize=10.4)
    fig.text(.081, .125, "Check frequency, severity, case reserves and "
             "product/risk segments; reconcile source records.",
             color=DARK, fontsize=9.4)
    fig.text(.063, .052, "Source: reports/portfolio_kpis.csv | "
             "Two six-month periods | Reserve valuation: 31 Aug 2026",
             color=MUTED, fontsize=8.5)
    fig.text(.063, .032, "Illustrative AI-assisted sample. Not real insurer "
             "performance; insufficient for pricing inference.",
             color=MUTED, fontsize=8.5)
    OUTPUT.mkdir(exist_ok=True)
    for ext in ("svg", "png"):
        file = OUTPUT / f"underwriting_performance_dashboard.{ext}"
        fig.savefig(file, dpi=150, facecolor=fig.get_facecolor())
        print("Generated", file.relative_to(ROOT))
    plt.close(fig)


if __name__ == "__main__":
    main()
