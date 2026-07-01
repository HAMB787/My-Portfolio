# 🤖 AI Data Analyst — Telegram Bot

An intelligent Telegram bot that turns **natural-language questions** into data insights. Upload a CSV, ask a question in plain English, and get answers with auto-generated charts — powered by an LLM + sandboxed Python execution pipeline.

---

## ✨ Features

- **Multi-table sessions** — Upload multiple CSVs; the bot keeps all tables in memory and can join/query across them
- **Natural language → code** — Ask questions like *"What are the top 5 products by revenue?"* and get instant answers
- **Auto-generated charts** — The bot produces Matplotlib visualizations when appropriate
- **Secure sandbox** — Generated Python code runs in an isolated executor, preventing harmful operations
- **Session management** — `/tables` to list loaded data, `/clear` to reset

## 🛠️ Tech Stack

| Component | Technology |
|---|---|
| Bot framework | `python-telegram-bot` |
| Data processing | `pandas`, `matplotlib` |
| LLM integration | OpenAI-compatible API (configurable) |
| Code execution | Sandboxed Python executor |

## 📂 Project Structure

```
ai-data-analyst-telegram-bot/
├── main.py           # Bot entry point, command & message handlers
├── llm.py            # LLM client with retry logic & prompt engineering
├── executor.py       # Sandboxed Python code execution engine
├── formatter.py      # HTML message templates for Telegram
├── src/
│   ├── __init__.py
│   └── data_analyst.py  # Core analysis pipeline
├── requirements.txt
└── .env.example      # Template for API tokens
```

## 🚀 Quick Start

1. Copy `.env.example` → `.env` and fill in your tokens:
   ```
   TELEGRAM_BOT_TOKEN=your_bot_token_here
   OPENAI_API_KEY=your_api_key_here
   ```
2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
3. Run the bot:
   ```bash
   python main.py
   ```
4. Open Telegram → send `/start` → upload a CSV → ask questions!

## 💬 Usage Examples

| You say | Bot does |
|---|---|
| *"Show me monthly revenue trends"* | Generates a line chart with revenue over time |
| *"What's the average price by category?"* | Returns a formatted table |
| *"Find the top 10 customers"* | Runs a pandas query and returns results |
