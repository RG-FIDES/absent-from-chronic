# noqa: E501
# AI agents: mirror the structural conventions of ./analysis/eda-2/eda-2.R when editing this file.
# Each "---- section ---" comment corresponds to a named chunk in eda-2.R.

# ---- load-packages -----------------------------------------------------------
# Standard library
import os
import sys
from pathlib import Path

# -- venv guard ----------------------------------------------------------------
# Detect whether we are running inside the project virtual environment.
# If not, print the correct command and exit early instead of failing with
# a cryptic ModuleNotFoundError.
_in_venv = (
    hasattr(sys, "real_prefix")  # virtualenv
    or (hasattr(sys, "base_prefix") and sys.base_prefix != sys.prefix)  # venv
)
if not _in_venv:
    _script = Path(__file__).resolve()
    _root   = _script.parent.parent.parent
    _py     = _root / ".venv" / "Scripts" / "python.exe"  # Windows
    if not _py.exists():
        _py = _root / ".venv" / "bin" / "python"          # Linux / macOS
    print("\n[ERROR] This script must be run with the project virtual environment.")
    print("        Your current interpreter has no third-party packages installed.")
    print("\n  Option 1 - run directly with the venv Python:")
    print(f"    {_py} {_script}")
    print("\n  Option 2 - activate first, then run normally:")
    print("    .venv\\Scripts\\activate        (PowerShell / Command Prompt)")
    print(f"    python {_script.name}")
    print("\n  If .venv does not exist yet, initialise it first:")
    print("    python utility/init-venv.py --yes\n")
    sys.exit(1)

# Third-party — install via:  python utility/init-venv.py --yes
import sqlite3
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")   # non-interactive backend: saves to file without a GUI
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

# ---- declare-globals ---------------------------------------------------------
# Resolve project root regardless of where the script is invoked from.
# Mirrors the root-detection logic in eda-2.R (declare-globals chunk).

_here = Path(__file__).resolve().parent          # analysis/eda-2/
_root = _here.parent.parent                       # repo root

local_root         = _here
local_data         = local_root / "data-local"
prints_folder      = local_root / "prints"
data_private_derived = _root / "data-private" / "derived" / "eda-2"
db_path            = _root / "data-private" / "derived" / "cchs-3.sqlite"

# Auto-create output directories (idempotent — mirrors eda-2.R)
local_data.mkdir(parents=True, exist_ok=True)
prints_folder.mkdir(parents=True, exist_ok=True)
data_private_derived.mkdir(parents=True, exist_ok=True)

# Graph output dimensions in inches — same as R ggsave defaults (8.5 × 5.5)
FIG_W, FIG_H, FIG_DPI = 8.5, 5.5, 300

# ---- declare-functions -------------------------------------------------------
def save_fig(fig: plt.Figure, filename: str) -> None:
    """Save figure to prints_folder at the standard resolution."""
    out = prints_folder / filename
    fig.savefig(out, dpi=FIG_DPI, bbox_inches="tight")
    print(f"  [SAVED] {out}")


def bin_absence_days(series: pd.Series) -> pd.Series:
    """
    Bin absence_days_total into the same interpretable ranges used in eda-2.R.
    Returns an ordered Categorical.
    """
    labels = ["0 days", "1–3 days", "4–7 days", "8–14 days",
              "15–30 days", "31–90 days", "91+ days"]
    bins   = [-1, 0, 3, 7, 14, 30, 90, np.inf]
    return pd.cut(series, bins=bins, labels=labels, right=True)


# ---- load-data ---------------------------------------------------------------
# Source: cchs_employed table from Lane 3 output (cchs-3.sqlite)
# Each row = one employed survey respondent
# Key variable: absence_days_total — total work days missed due to any health reason
print(f"[INFO]  Connecting to: {db_path}")

if not db_path.exists():
    sys.exit(f"[ERROR] Database not found: {db_path}\n"
             "        Run manipulation/3-ellis.R first to generate cchs-3.sqlite.")

con = sqlite3.connect(db_path)
ds0 = pd.read_sql_query("SELECT * FROM cchs_employed", con)
con.close()

print(f"[INFO]  Data loaded:")
print(f"        - ds0 (cchs_employed): {len(ds0):,} employed respondents")

# ---- tweak-data-0 ------------------------------------------------------------
# Coerce absence_days_total to numeric; no rows are dropped (NAs stay for
# transparency — mirrors the R tweak-data-0 chunk).
ds0["absence_days_total"] = pd.to_numeric(ds0["absence_days_total"], errors="coerce")
ds0["has_any_absence"] = ds0["absence_days_total"].apply(
    lambda x: None if pd.isna(x) else (x > 0)
)

# ---- inspect-data-0 ----------------------------------------------------------
print("\n[INFO]  Data Overview:")
print(f"        - ds0 (cchs_employed): {len(ds0):,} rows x {len(ds0.columns)} cols")
print(f"        - NA absence_days_total: {ds0['absence_days_total'].isna().sum():,}")
print(f"        - 0 days absent:         {(ds0['absence_days_total'] == 0).sum():,}")
print(f"        - 1+ days absent:        {(ds0['absence_days_total'] >= 1).sum():,}")

# ---- inspect-data-1 ----------------------------------------------------------
print("\n[INFO]  DS0 Structure (cchs_employed):")
print(ds0.dtypes.to_string())

# ---- inspect-data-2 ----------------------------------------------------------
print("\n[INFO]  Key Variables Summary:")
print(ds0[["absence_days_total", "abs_chronic_days", "sex_label",
           "age_group_3", "survey_cycle_label"]].describe(include="all"))

# ---- g1 ----------------------------------------------------------------------
# Overview: how many employed people had ANY absence days vs. none?
# Purpose: quick orientation — scale of the absence problem.
# Mirrors g1 (g1_absence_overview) from eda-2.R.

abs_share = (
    ds0.dropna(subset=["absence_days_total"])
    .assign(absence_group=lambda d: np.where(d["absence_days_total"] == 0,
                                             "No absence\n(0 days)",
                                             "Any absence\n(1+ days)"))
    .groupby("absence_group", sort=False)
    .size()
    .reset_index(name="n_people")
)
abs_share["pct"] = abs_share["n_people"] / abs_share["n_people"].sum() * 100
abs_share = abs_share.set_index("absence_group").loc[
    ["No absence\n(0 days)", "Any absence\n(1+ days)"]
].reset_index()

COLORS_G1 = ["steelblue", "firebrick"]

fig_g1, ax_g1 = plt.subplots(figsize=(FIG_W, FIG_H))
bars = ax_g1.bar(
    abs_share["absence_group"],
    abs_share["n_people"],
    color=COLORS_G1,
    alpha=0.85,
    width=0.5,
)
for bar, (_, row) in zip(bars, abs_share.iterrows()):
    ax_g1.text(
        bar.get_x() + bar.get_width() / 2,
        bar.get_height() + abs_share["n_people"].max() * 0.01,
        f"{row['n_people']:,}\n({row['pct']:.1f}%)",
        ha="center", va="bottom", fontsize=10,
    )
ax_g1.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"{x:,.0f}"))
ax_g1.set_xlabel("")
ax_g1.set_ylabel("Number of respondents", fontsize=11)
ax_g1.set_title(
    "Work Absence Among Employed Canadians\n"
    "Original data (ds0 = cchs_employed) — CCHS 2010-11 & 2013-14 pooled",
    fontsize=12,
)
ax_g1.set_ylim(0, abs_share["n_people"].max() * 1.18)
ax_g1.spines[["top", "right"]].set_visible(False)
fig_g1.text(0.5, -0.02,
            "Source: Statistics Canada, CCHS cycles 2010-2011 and 2013-2014",
            ha="center", fontsize=8, color="grey")
fig_g1.tight_layout()
save_fig(fig_g1, "py_g1_absence_overview.png")
plt.close(fig_g1)  # free memory; use plt.show() instead for interactive sessions

# ---- g2-data-prep ------------------------------------------------------------
# Prepare data for the g2 family: "How are absence days distributed?"
# Conceptual anchor: absence day distribution among employed respondents.
# Mirrors the g2-data-prep chunk in eda-2.R — same bins, same logic.

n_na = ds0["absence_days_total"].isna().sum()

g2_data = (
    ds0.dropna(subset=["absence_days_total"])
    .assign(absence_bin=lambda d: bin_absence_days(d["absence_days_total"]))
    .groupby("absence_bin", observed=True)
    .size()
    .reset_index(name="n_people")
)
g2_data["pct"] = g2_data["n_people"] / g2_data["n_people"].sum() * 100
g2_data["is_zero"] = g2_data["absence_bin"].astype(str) == "0 days"

print(f"\n[INFO]  g2_data prepared: {len(g2_data)} absence-day bins | {n_na:,} NAs excluded from display")

# ---- g2 ----------------------------------------------------------------------
# Full distribution: number of people per absence-day bin (all bins incl. 0)
# Mirrors g2 (g2_absence_dist) from eda-2.R.

bar_colors_g2 = ["steelblue" if z else "firebrick" for z in g2_data["is_zero"]]

fig_g2, ax_g2 = plt.subplots(figsize=(FIG_W, FIG_H))
bars_g2 = ax_g2.bar(
    g2_data["absence_bin"].astype(str),
    g2_data["n_people"],
    color=bar_colors_g2,
    alpha=0.85,
)
for bar, (_, row) in zip(bars_g2, g2_data.iterrows()):
    ax_g2.text(
        bar.get_x() + bar.get_width() / 2,
        bar.get_height() + g2_data["n_people"].max() * 0.005,
        f"{row['n_people']:,}\n({row['pct']:.1f}%)",
        ha="center", va="bottom", fontsize=8,
    )
ax_g2.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"{x:,.0f}"))
ax_g2.set_xlabel("Absence days (binned)", fontsize=11)
ax_g2.set_ylabel("Number of respondents", fontsize=11)
ax_g2.set_title(
    "Distribution of Work Absence Days\n"
    f"g2_data — employed respondents by absence-day band "
    f"(NAs excluded: n = {n_na:,})",
    fontsize=12,
)
ax_g2.set_ylim(0, g2_data["n_people"].max() * 1.18)
ax_g2.spines[["top", "right"]].set_visible(False)
fig_g2.text(0.5, -0.02,
            "Source: Statistics Canada, CCHS 2010-2011 & 2013-2014",
            ha="center", fontsize=8, color="grey")
fig_g2.tight_layout()
save_fig(fig_g2, "py_g2_absence_distribution.png")
plt.close(fig_g2)

# ---- g21 ---------------------------------------------------------------------
# Family member: zoom into the 1+ days group — same g2_data, zero bin removed.
# Purpose: reveal the within-absent distribution without the dominant zero bar.
# Mirrors g21 (g21_absent_only) from eda-2.R.

g21_data = g2_data[~g2_data["is_zero"]].copy()

fig_g21, ax_g21 = plt.subplots(figsize=(FIG_W, FIG_H))
bars_g21 = ax_g21.bar(
    g21_data["absence_bin"].astype(str),
    g21_data["n_people"],
    color="firebrick",
    alpha=0.85,
)
for bar, (_, row) in zip(bars_g21, g21_data.iterrows()):
    ax_g21.text(
        bar.get_x() + bar.get_width() / 2,
        bar.get_height() + g21_data["n_people"].max() * 0.01,
        f"{row['n_people']:,}\n({row['pct']:.1f}% of all)",
        ha="center", va="bottom", fontsize=9,
    )
ax_g21.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"{x:,.0f}"))
ax_g21.set_xlabel("Absence days (binned)", fontsize=11)
ax_g21.set_ylabel("Number of respondents", fontsize=11)
ax_g21.set_title(
    "Absence Day Distribution — Among Those With Any Absence\n"
    "Same g2_data, zero-day group excluded to reveal within-absent pattern",
    fontsize=12,
)
ax_g21.set_ylim(0, g21_data["n_people"].max() * 1.18)
ax_g21.spines[["top", "right"]].set_visible(False)
fig_g21.text(0.5, -0.02,
             "Source: Statistics Canada, CCHS 2010-2011 & 2013-2014",
             ha="center", fontsize=8, color="grey")
fig_g21.tight_layout()
save_fig(fig_g21, "py_g21_absent_only_distribution.png")
plt.close(fig_g21)

print("\n[DONE]  eda-2.py complete -- 3 graphs saved to", prints_folder)
