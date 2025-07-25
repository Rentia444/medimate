from flask import Flask, request, jsonify
from chatbot import Chatbot, get_bot_response

# Inisialisasi chatbot
chatbot = Chatbot("knowledge_base.json","kb_kombinasi.json")

app = Flask(__name__)

@app.route("/chat", methods=["POST"])
def chat():
    try:
        data = request.get_json()
        user_message = data.get("message", "")
        if not user_message:
            return jsonify({"error": "Pesan kosong"}), 400
        response = get_bot_response(chatbot, user_message, priority="kb-first")
        return jsonify({"reply": response})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/", methods=["GET"])
def index():
    return "Chatbot API siap digunakan."

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
