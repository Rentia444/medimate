# app.py

import gradio as gr
import time
from chatbot import Chatbot, get_bot_response
from functools import wraps

# Inisialisasi objek Chatbot sekali saja
chatbot_obj = Chatbot('knowledge_base.json')

# Decorator untuk mengukur waktu respons
def timing_decorator(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        start_time = time.time()
        result = func(*args, **kwargs)
        end_time = time.time()
        print(f"Response time: {end_time - start_time:.2f} seconds")
        return result
    return wrapper

# Fungsi pembungkus agar sesuai dengan signature Gradio (terima user_input dan chat_history)
def gradio_get_bot_response(user_input, chat_history=None):
    return get_bot_response(chatbot_obj, user_input)

# Terapkan decorator timing ke fungsi pembungkus
timed_get_response = timing_decorator(gradio_get_bot_response)

description = """
🧠 Asisten Medis AI (Optimized)
• Prioritaskan pertanyaan ke basis pengetahuan
• Model AI hanya untuk pertanyaan kompleks
"""

css = """
.message { 
    padding: 10px; 
    border-radius: 5px; 
    margin: 5px 0;
    color: inherit;
}
.message.user { 
    background-color: #e0e0e0;
    color: #000000;
}
.message.bot { 
    background-color: #f0f0f0;
    color: #000000;
}
@media (prefers-color-scheme: dark) {
    .message.user {
        background-color: #2d3748;
        color: #ffffff;
    }
    .message.bot {
        background-color: #4a5568;
        color: #ffffff;
    }
}
.prose { 
    max-width: 800px; 
    margin: auto; 
}
"""

iface = gr.ChatInterface(
    fn=timed_get_response,
    title="Asisten Medis Cepat",
    description=description,
    theme="soft",
    examples=[
        ["Bagaimana cara minum metformin?"],
        ["Apakah aman olahraga dengan hipertensi?"]
    ],
    css=css
)

if __name__ == "__main__":
    iface.launch(
        share=True,
        server_port=7860,
        server_name="0.0.0.0"
    )


# import json
# import gradio as gr
# import subprocess

# # Load knowledge base
# with open("knowledge_base.json", "r") as f:
#     knowledge_base = json.load(f)

# def query_knowledge_base(question):
#     question_lower = question.lower()
#     for entry in knowledge_base:
#         if entry["question"].lower() in question_lower:
#             return entry["answer"]
#     return None

# def call_ollama_phi3(question):
#     try:
#         result = subprocess.run(
#             ["ollama", "chat", "phi-3", "--prompt", question],
#             capture_output=True,
#             text=True,
#             check=True
#         )
#         return result.stdout.strip()
#     except Exception as e:
#         return "Gagal memanggil Ollama: " + str(e)

# def chatbot_response(question):
#     answer = query_knowledge_base(question)
#     if answer:
#         return answer
#     else:
#         return call_ollama_phi3(question)

# iface = gr.Interface(fn=chatbot_response, inputs="text", outputs="text", title="Chatbot Edukasi Obat")

# if __name__ == "__main__":
#     iface.launch()