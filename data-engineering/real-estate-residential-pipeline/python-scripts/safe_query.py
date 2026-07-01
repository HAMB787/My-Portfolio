import pandas as pd
from sqlalchemy import create_engine
import os

# --- Database Connection Settings ---
# It's recommended to set these in your environment for security
DB_HOST = os.getenv('CLICKHOUSE_HOST', 'localhost')
DB_PORT = os.getenv('CLICKHOUSE_PORT', '8123')
DB_USER = os.getenv('CLICKHOUSE_USER', 'default')
DB_PASSWORD = os.getenv('CLICKHOUSE_PASSWORD', '')
DB_NAME = os.getenv('CLICKHOUSE_DB', 'default')

def run_safe_query(query: str) -> pd.DataFrame:
    """
    Connects to the ClickHouse database using environment variables,
    executes a read-only SQL query, and returns the result as a pandas DataFrame.

    Args:
        query (str): The SQL query to execute. It should be a SELECT statement.

    Returns:
        pd.DataFrame: A DataFrame containing the query results. 
                      Returns an empty DataFrame if an error occurs or no data is found.
    """
    # For safety, we can do a basic check to ensure it's a read-only query.
    if not query.strip().upper().startswith('SELECT') and not query.strip().upper().startswith('WITH'):
        print("Error: Only SELECT or WITH statements are allowed for safety.")
        return pd.DataFrame()

    connection_string = f"clickhouse://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    
    try:
        engine = create_engine(connection_string)
        with engine.connect() as connection:
            df = pd.read_sql(query, connection)
            return df
    except Exception as e:
        print(f"An error occurred while executing the query: {e}")
        return pd.DataFrame()

if __name__ == '__main__':
    # Example Usage & Connection Test
    print("Testing connection to ClickHouse...")
    test_query = "SELECT 'Connection successful!' AS status;"
    result_df = run_safe_query(test_query)
    if not result_df.empty:
        print(result_df.iloc[0]['status'])
    else:
        print("Connection test failed. Please check your database connection settings and environment variables.")

