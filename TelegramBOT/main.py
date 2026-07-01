"""AI Data Analyst Telegram bot."""

from __future__ import annotations

import io
import logging
import os

import pandas as pd
from dotenv import load_dotenv
from telegram import Update
from telegram.constants import ParseMode
from telegram.ext import (
    ApplicationBuilder,
    CommandHandler,
    ContextTypes,
    MessageHandler,
    filters,
)

from formatter import (
    fmt_analyzing,
    fmt_chart_caption,
    fmt_cleared,
    fmt_csv_error,
    fmt_csv_loaded,
    fmt_no_data,
    fmt_no_result,
    fmt_ping,
    fmt_question_too_long,
    fmt_start,
    fmt_table_added_to_session,
    fmt_tables_overview,
    fmt_wrong_file_type,
)
from llm import query_with_retry

load_dotenv()

logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    level=logging.INFO,
)
logger = logging.getLogger(__name__)

TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
MAX_QUESTION_LENGTH = 500

# ─── Session helpers ─────────────────────────────────────────────────────────

def _get_tables(context: ContextTypes.DEFAULT_TYPE) -> dict[str, pd.DataFrame]:
    """Return the user's table dict, creating it if absent."""
    if context.user_data is None:
        return {}
    if "tables" not in context.user_data:
        context.user_data["tables"] = {}
    return context.user_data["tables"]  # type: ignore[return-value]


def _set_table(
    context: ContextTypes.DEFAULT_TYPE,
    name: str,
    df: pd.DataFrame,
) -> None:
    tables = _get_tables(context)
    tables[name] = df


# ─── HTML reply shortcut ─────────────────────────────────────────────────────

async def _reply_html(update: Update, text: str) -> None:
    if update.message:
        await update.message.reply_text(text, parse_mode=ParseMode.HTML)


# ─── Command handlers ─────────────────────────────────────────────────────────

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    await _reply_html(update, fmt_start())


async def ping(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    await _reply_html(update, fmt_ping())


async def tables_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """/tables — list all loaded DataFrames."""
    await _reply_html(update, fmt_tables_overview(_get_tables(context)))


async def clear_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """/clear — drop all loaded DataFrames from the session."""
    if context.user_data is not None:
        context.user_data["tables"] = {}
    await _reply_html(update, fmt_cleared())


# ─── CSV upload handler ───────────────────────────────────────────────────────

async def handle_csv(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Load an uploaded CSV into the multi-table session."""
    message = update.message
    if message is None or message.document is None:
        return

    document = message.document
    if not document.file_name or not document.file_name.lower().endswith(".csv"):
        await _reply_html(update, fmt_wrong_file_type())
        return

    await message.reply_chat_action("typing")

    telegram_file = await document.get_file()
    raw_bytes = await telegram_file.download_as_bytearray()
    buffer = io.BytesIO(bytes(raw_bytes))

    try:
        df = pd.read_csv(buffer)
    except Exception as exc:
        logger.exception("CSV parse failed")
        await _reply_html(update, fmt_csv_error(exc))
        return

    # Filename stem used as the table key (e.g. "sales.csv" → "sales")
    stem = document.file_name.rsplit(".", 1)[0]
    _set_table(context, stem, df)

    tables = _get_tables(context)
    if len(tables) == 1:
        # First table: show full summary card
        await _reply_html(update, fmt_csv_loaded(stem, df))
    else:
        # Additional table: show a short notification + updated count
        await _reply_html(update, fmt_csv_loaded(stem, df))
        await _reply_html(update, fmt_table_added_to_session(stem, len(tables)))


# ─── Question handler ─────────────────────────────────────────────────────────

async def handle_question(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Route natural-language questions to the LLM + sandbox pipeline."""
    message = update.message
    if message is None or message.text is None:
        return

    tables = _get_tables(context)
    if not tables:
        await _reply_html(update, fmt_no_data())
        return

    question = message.text.strip()
    if not question:
        return

    if len(question) > MAX_QUESTION_LENGTH:
        await _reply_html(update, fmt_question_too_long(len(question), MAX_QUESTION_LENGTH))
        return

    await message.reply_chat_action("typing")
    status = await message.reply_text(
        fmt_analyzing(), parse_mode=ParseMode.HTML
    )

    text, image = await query_with_retry(question, tables)

    if image is not None:
        try:
            await status.delete()
        except Exception:
            pass
        await message.reply_photo(
            photo=io.BytesIO(image),
            caption=fmt_chart_caption(text),
            parse_mode=ParseMode.HTML,
        )
        return

    await status.edit_text(
        text or fmt_no_result(),
        parse_mode=ParseMode.HTML,
    )


# ─── App entry point ──────────────────────────────────────────────────────────

def main() -> None:
    if not TOKEN:
        raise RuntimeError("Set TELEGRAM_BOT_TOKEN in your .env file")

    app = ApplicationBuilder().token(TOKEN).build()

    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("ping", ping))
    app.add_handler(CommandHandler("tables", tables_cmd))
    app.add_handler(CommandHandler("clear", clear_cmd))
    app.add_handler(MessageHandler(filters.Document.FileExtension("csv"), handle_csv))
    app.add_handler(
        MessageHandler(filters.TEXT & ~filters.COMMAND, handle_question)
    )

    print("Bot is running...")
    app.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == "__main__":
    main()