from src.tools.db import get_connection
from src.tools.run_sql import RunSqlTool


def test_run_sql_select():
    con = get_connection()
    con.execute("CREATE OR REPLACE TABLE t AS SELECT 1 AS x, 'a' AS y")
    con.close()

    tool = RunSqlTool()
    out = tool.run({"query": "SELECT * FROM t"})
    assert "1" in out
    assert "a" in out
