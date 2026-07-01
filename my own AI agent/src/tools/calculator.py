"""Example tool for Phase 1 — safe, read-only, easy to test."""

from __future__ import annotations

import ast
import operator
from typing import Any

from src.tools.base import Tool

_OPS = {
    ast.Add: operator.add,
    ast.Sub: operator.sub,
    ast.Mult: operator.mul,
    ast.Div: operator.truediv,
}


def _safe_eval(expr: str) -> float:
    node = ast.parse(expr, mode="eval").body

    def _eval(n: ast.AST) -> float:
        if isinstance(n, ast.Constant) and isinstance(n.value, (int, float)):
            return float(n.value)
        if isinstance(n, ast.BinOp) and type(n.op) in _OPS:
            return _OPS[type(n.op)](_eval(n.left), _eval(n.right))
        if isinstance(n, ast.UnaryOp) and isinstance(n.op, ast.USub):
            return -_eval(n.operand)
        raise ValueError("Unsupported expression")

    return _eval(node)


class CalculatorTool(Tool):
    name = "calculator"
    description = "Evaluate a simple math expression, e.g. '(2 + 3) * 4'."

    def parameters_schema(self) -> dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "expression": {
                    "type": "string",
                    "description": "Math expression to evaluate",
                }
            },
            "required": ["expression"],
        }

    def run(self, arguments: dict[str, Any]) -> str:
        expr = arguments.get("expression", "")
        try:
            result = _safe_eval(expr)
            return str(result)
        except Exception as e:
            return f"Calculator error: {e}"
