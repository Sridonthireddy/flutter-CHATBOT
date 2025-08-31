import os
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
print("DEBUG GEMINI KEY:", GEMINI_API_KEY[:6], "...")
GEMINI_MODEL = "gemini-1.5-flash"
GEMINI_URL = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent?key={GEMINI_API_KEY}"

def ask_gemini(prompt: str) -> str:
    try:
        response = requests.post(
            GEMINI_URL,
            headers={"Content-Type": "application/json"},
            json={"contents": [{"parts": [{"text": prompt}]}]},
        )
        data = response.json()
        print("DEBUG GEMINI RESPONSE:", data)
        return data["candidates"][0]["content"]["parts"][0]["text"]
    except Exception as e:
        print("DEBUG GEMINI ERROR:", e)
        return f"(Gemini error: {e})"

from datetime import datetime
import requests


def get_reply(user_message: str, allow_web: bool) -> str:
    """
    Basic chatbot core logic.
    Extend with AI/LLM integration or other features later.
    If allow_web is True, attempt to fetch info from Gemini.
    """
    if not user_message or not user_message.strip():
        return "Please say something 🙂"

    msg = user_message.lower().strip()
    if "hello" in msg or "hi" in msg:
        return "Hello! I'm Tina 🌸 How can I assist you today?"
    elif "bye" in msg or "goodbye" in msg:
        return "Goodbye! Talk to you soon 👋"
    elif "your name" in msg or "who are you" in msg:
        return "I'm Tina, your friendly chatbot assistant."
    elif "time" in msg:
        return f"The current time is {datetime.now().strftime('%H:%M')}."
    elif "date" in msg:
        return f"Today's date is {datetime.now().strftime('%Y-%m-%d')}."
    elif "weather" in msg:
        return "I can't give live weather updates yet, but you can check a weather app 🌤️"
    elif "help" in msg:
        return "Sure! Tell me what you need help with."
    elif allow_web:
        return ask_gemini(user_message)
    else:
        return f"I'm not able to search the web right now. You said: {user_message}"

