import random
import math
import datetime
import json
import os
import requests

knowledge_file = "knowledge.json"
knowledge = {}

last_entity = None
conversation_history = []

def load_knowledge():
    global knowledge
    if os.path.exists(knowledge_file):
        with open(knowledge_file, "r") as f:
            knowledge = json.load(f)

def save_knowledge():
    with open(knowledge_file, "w") as f:
        json.dump(knowledge, f)

def evaluate_math(expr):
    try:
        return str(eval(expr, {"__builtins__": {}}, math.__dict__))
    except Exception:
        return None

def convert_units(text):
    return None  # placeholder

def get_joke():
    jokes = [
        "Why don't scientists trust atoms? Because they make up everything!",
        "I told my computer I needed a break, and it said 'No problem – I'll go to sleep.'"
    ]
    return random.choice(jokes)

def get_riddle():
    riddles = [
        "What has keys but can't open locks? A piano.",
        "The more you take, the more you leave behind. What am I? Footsteps."
    ]
    return random.choice(riddles)

def get_quote():
    quotes = [
        "The best way to predict the future is to create it.",
        "Life is 10% what happens to us and 90% how we react to it."
    ]
    return random.choice(quotes)

def calculate_bmi(text):
    return None  # placeholder

def answer_qa(text):
    return None

def detect_intent(text):
    lower = text.lower().strip()
    if any(word in lower for word in ["hi", "hello", "hey"]):
        return "greeting"
    if "joke" in lower:
        return "joke"
    if "riddle" in lower:
        return "riddle"
    if "quote" in lower:
        return "quote"
    if any(ch.isdigit() for ch in lower):
        return "math"
    if "time" in lower:
        return "time"
    return "unknown"

def web_search_duckduckgo(query):
    try:
        url = "https://api.duckduckgo.com/"
        params = {
            "q": query,
            "format": "json",
            "t": "tina-bot",
            "no_html": 1,
            "skip_disambig": 1
        }
        res = requests.get(url, params=params, timeout=8)
        res.raise_for_status()
        data = res.json()

        if data.get("AbstractText"):
            return data["AbstractText"]
        elif data.get("Answer"):
            return data["Answer"]
        elif data.get("Definition"):
            return data["Definition"]
        elif data.get("RelatedTopics"):
            for topic in data["RelatedTopics"]:
                if isinstance(topic, dict) and topic.get("Text"):
                    return topic["Text"]

        return "I searched DuckDuckGo but couldn’t find anything useful."
    except Exception as e:
        return f"Search error: {e}"

def respond(user_text, allow_web=True):
    global last_entity, conversation_history

    if last_entity:
        if "her" in user_text.lower():
            user_text = user_text.replace("her", last_entity)
        if "him" in user_text.lower():
            user_text = user_text.replace("him", last_entity)
        if "their" in user_text.lower():
            user_text = user_text.replace("their", last_entity)

    intent = detect_intent(user_text)
    conversation_history.append({"role": "user", "text": user_text})

    if intent == "joke":
        return get_joke()
    elif intent == "greeting":
        return random.choice([
            "Hey! How can I help you?",
            "Hello 👋",
            "Hi there! Ready to chat?"
        ])
    elif intent == "riddle":
        return get_riddle()
    elif intent == "quote":
        return get_quote()
    elif intent == "math":
        res = evaluate_math(user_text)
        if res:
            return res
    elif intent == "time":
        now = datetime.datetime.now()
        return now.strftime("The time is %H:%M:%S")

    # --- Step 2: Friendly fallback first ---
    fallback_responses = [
        "I'm here to help! Ask me for a joke, riddle, quote, or math calculation.",
        "What can I do for you today?",
        "Feel free to ask me anything!",
        "I'm listening. How can I assist you?",
        "Let's chat! What would you like to know?"
    ]
    fallback = random.choice(fallback_responses)

    # --- Step 3: If web search allowed, try DuckDuckGo ---
    if allow_web:
        result = web_search_duckduckgo(user_text)
        if result:
            last_entity = user_text  # store last search subject
            conversation_history.append({"role": "tina", "text": result})
            return result

    conversation_history.append({"role": "tina", "text": fallback})
    return fallback


def tina_reply(msg, allow_web=False):
    return respond(msg, allow_web=allow_web)

load_knowledge()
