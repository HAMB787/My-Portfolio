"""Dynamic programming (backward induction) with readable terminal output."""

from __future__ import annotations

import os
import shutil
import sys
from typing import Iterable


def _init_stdout() -> None:
    """Avoid mojibake in Windows consoles when printing math symbols."""
    reconf = getattr(sys.stdout, "reconfigure", None)
    if callable(reconf):
        try:
            reconf(encoding="utf-8", errors="replace")
        except (OSError, ValueError):
            pass


def fmt(n: float | int) -> float | int:
    """
    Format numbers: drop trailing .0 for integers, else round for display.
    """
    return int(n) if n == int(n) else round(n, 4)


def _term_w() -> int:
    return max(40, min(shutil.get_terminal_size(fallback=(88, 24)).columns, 100))


def _ansi(codes: str, text: str) -> str:
    if not sys.stdout.isatty() or os.environ.get("NO_COLOR"):
        return text
    return f"\033[{codes}m{text}\033[0m"


def _rule(char: str = "=", title: str | None = None) -> str:
    w = _term_w()
    if not title:
        return char * w
    pad = max(0, w - len(title) - 4)
    left = pad // 2
    right = pad - left
    return f"{char * left} {title} {char * right}"


def _print_banner(title: str, subtitle: str | None = None) -> None:
    line = _rule("=")
    print(_ansi("1;36", line))
    print(_ansi("1;36", title.center(_term_w())))
    if subtitle:
        print(_ansi("2", subtitle.center(_term_w())))
    print(_ansi("1;36", line))


def _print_param_block(W: Iterable[float], phi: Iterable[float], T: int) -> None:
    print(_ansi("1", "Parameters"))
    w_list = list(W)
    p_list = list(phi)
    w_col = max(len(str(w)) for w in w_list)
    print(f"  {'w':<{w_col}}    phi")
    for w, p in zip(w_list, p_list, strict=True):
        print(f"  {w:<{w_col}}    {p}")
    print(f"  horizon T = {T}")
    print()


def _print_step_header(t: int, note: str = "") -> None:
    print()
    print(_ansi("1;33", _rule("-", f" Step t = {t} ")))
    if note:
        print(_ansi("2", f"  {note}"))


def _print_value_table(t: int, V: dict[float, float]) -> None:
    rows = sorted(V.items(), key=lambda x: x[0])
    hdr_r = f"V_{t}(w)"
    w_w = max(3, max(len(str(w)) for w, _ in rows))
    v_w = max(len(hdr_r), max(len(str(fmt(v))) for _, v in rows))
    sep = f"+{'-' * (w_w + 2)}+{'-' * (v_w + 2)}+"
    print(_ansi("2", "  Value function"))
    print(f"  {sep}")
    print(
        f"  | {_ansi('1', 'w'.center(w_w))} | "
        f"{_ansi('1', hdr_r.center(v_w))} |"
    )
    print(f"  {sep}")
    for w, v in rows:
        print(f"  | {str(w):^{w_w}} | {str(fmt(v)):^{v_w}} |")
    print(f"  {sep}")


def calculate_dp_detailed(W: list[float], phi: list[float], T: int) -> dict[float, float]:
    """
    Backward induction DP; prints structured steps for the terminal.
    """
    _init_stdout()
    _print_banner(
        "Dynamic programming",
        "max{ take w now, wait for E[V_{t+1}(W)] }",
    )
    _print_param_block(W, phi, T)

    V = {w: w for w in W}
    _print_step_header(T, "Terminal values: V_T(w) = w")
    print(_ansi("2", f"  V_{T}(W) = max{{ w, 0 }} => w"))
    _print_value_table(T, V)

    for t in range(T - 1, 0, -1):
        _print_step_header(t)

        formula_parts: list[str] = []
        subst_parts: list[str] = []
        prod_parts: list[str] = []
        expected_value = 0.0

        for i in range(len(W)):
            w = W[i]
            p = phi[i]
            v_next = V[w]
            term_val = v_next * p
            expected_value += term_val
            formula_parts.append(f"V_{t+1}({w}) * phi_{i+1}")
            subst_parts.append(f"{fmt(v_next)} * {p}")
            prod_parts.append(f"{fmt(term_val)}")

        print(_ansi("1", "  Expectation"))
        indent = "    "
        print(f"{indent}E[V_{t+1}(W)] = " + " + ".join(formula_parts))
        print(f"{indent}           = " + " + ".join(subst_parts))
        print(f"{indent}           = " + " + ".join(prod_parts) + f" = {_ansi('1;32', str(fmt(expected_value)))}")

        new_V: dict[float, float] = {}
        print(_ansi("1", "  Bellman update"))
        for w in W:
            new_V[w] = max(w, expected_value)
            taken = "stop (take w)" if new_V[w] == w else "wait (E[.])"
            print(
                f"    V_{t}({w}) = max{{ {w}, {fmt(expected_value)} }} "
                f"= {_ansi('1;37', str(fmt(new_V[w])))}  {_ansi('2', f'({taken})')}"
            )

        _print_value_table(t, new_V)
        V = new_V

    print()
    print(_ansi("1;36", _rule("=", " Done ")))
    return V


if __name__ == "__main__":
    W_values = [20, 35, 45]
    phi_probabilities = [0.18, 0.42, 0.4]
    total_time_steps = 7

    calculate_dp_detailed(W_values, phi_probabilities, total_time_steps)
