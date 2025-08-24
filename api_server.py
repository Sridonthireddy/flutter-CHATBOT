# api_server.py — Flask wrapper for Tina
from flask import Flask, request, jsonify
from flask_cors import CORS
import tina_core

app = Flask(__name__)
CORS(app)

tina_core.load_knowledge()

@app.route("/ping", methods=["GET"])
def ping():
    return jsonify({"ok": True, "name": "Tina", "version": "0.1"})

@app.route("/chat", methods=["POST"])
def chat():
    data = request.get_json()
    msg = data.get("message", "")   # must match Flutter's "message"
    allow_web = data.get("allow_web", False)
    reply = tina_core.respond(msg, allow_web=allow_web)
    return jsonify({"reply": reply})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5050, debug=True)