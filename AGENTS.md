## Cursor Cloud specific instructions

### Overview

This is a Python-only portfolio of standalone university coursework scripts (optimization methods, dynamic programming, Markov chains, network analysis, expert concordance). There are no web apps, APIs, databases, or Docker services.

### Dependencies

All scripts require: `numpy`, `scipy`, `matplotlib`, `rich`. Install with:

```
pip install numpy scipy matplotlib rich
```

The only `requirements.txt` is at `University/kursayin/requirements.txt` and covers a subset (no `scipy`). Use the full list above for all scripts.

### Running scripts

Each `.py` file is standalone — run with `python3 <script>.py` from its own directory. Key scripts:

| Script | Directory | Notes |
|--------|-----------|-------|
| `kursayin.py` | `University/kursayin/` | Transportation problem (DP). Uses `rich` for formatted output + `matplotlib` for plots. |
| `dynamic_optimization.py` | `University/Optimization-Methods/Dynamic Optimization/` | Pure stdlib, no external deps. |
| `exh_srch_method.py` | `University/Optimization-Methods/Exhaustive Search Method/` | Requires `numpy`, `scipy`, `matplotlib`. |
| `gld_sct_srch.py` | `University/Optimization-Methods/Golden Section Search/` | Requires `numpy`, `scipy`, `matplotlib`. |
| `int_halving_meth.py` | `University/Optimization-Methods/Interval Halving Method/` | Requires `numpy`, `scipy`, `matplotlib`. |
| `steepest_descent.py` | `University/Optimization-Methods/Steepest Descent Method/` | Requires `numpy`, `scipy`. |
| `markov_chains.py` | `University/Optimization-Methods/Markov Chains/` | Requires `numpy`, `matplotlib`. |
| `resourse_planing_and_automation.py` | `University/Resource planing/` | Requires `numpy`. Interactive — pipe `echo "1"` for default data. |
| `dasakargman.py` | `University/systems information support/` | Requires `numpy`. |
| `zuyg_ar_zuyg.py` | `University/systems information support/` | Requires `numpy`. |

### Gotchas

- **Matplotlib backend**: In headless environments, set `MPLBACKEND=Agg` before running scripts that use `matplotlib`. Plots will be generated but `plt.show()` will emit a non-blocking warning.
- **Interactive script**: `resourse_planing_and_automation.py` prompts for input. Use `echo "1" | python3 resourse_planing_and_automation.py` to select default data.
- **Committed `.venv/`**: `University/kursayin/.venv/` is a Windows-created venv checked into the repo — it is not usable on Linux. Ignore it; install deps system-wide or in a fresh venv.
- **ML lab files**: `University/ML/lab*.py` are mostly empty stubs; they import `numpy` but have no runnable logic.
- **No test framework**: There are no automated tests (pytest, unittest, etc.) in this repo. Validation is done by running scripts and checking output.
- **No linter config**: No `.flake8`, `pyproject.toml`, or linter configuration exists. Use `python3 -m py_compile <file>` for basic syntax checks.
