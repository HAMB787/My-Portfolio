from src.tools.calculator import CalculatorTool


def test_calculator_basic():
    tool = CalculatorTool()
    assert tool.run({"expression": "(2 + 3) * 4"}) == "20.0"
