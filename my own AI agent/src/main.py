"""
CLI entry point.

Phase 1: read user messages in a loop and send them to the agent engine.
"""

from src.engine.query_loop import run_agent_turn


def main() -> None:
    print("Thesis AI Agent — type 'exit' to quit\n")
    history: list[dict] = []

    while True:
        user_input = input("You: ").strip()
        if not user_input:
            continue
        if user_input.lower() in {"exit", "quit"}:
            print("Goodbye.")
            break

        reply = run_agent_turn(user_input, history)
        history.append({"role": "user", "content": user_input})
        history.append({"role": "assistant", "content": reply})
        print(f"\nAgent: {reply}\n")


if __name__ == "__main__":
    main()
