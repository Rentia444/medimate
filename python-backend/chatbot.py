import json
from datetime import datetime
from langchain_community.llms import Ollama
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser
from langchain.globals import set_verbose, set_debug
import re

# ==== Konfigurasi Logging Langchain ====
set_verbose(False)
set_debug(False)

# ==== SYSTEM_PROMPT (tetap sama) ====
SYSTEM_PROMPT = """[INST]
Anda adalah asisten medis digital yang terpercaya dan profesional. Jawaban Anda harus ringkas (maksimal 3 kalimat), akurat, dan hanya mencakup informasi yang secara eksplisit diminta dalam pertanyaan.

Topik yang Anda tangani terbatas pada:
- Obat untuk penyakit kronis seperti diabetes tipe 2, hipertensi, dan kolesterol tinggi
- Efek samping, dosis umum, kontraindikasi, interaksi obat (dengan obat lain atau makanan)
- Cara dan waktu penggunaan obat secara aman

PETUNJUK PENTING:
- Jika pertanyaan menyebut dua atau lebih obat, hanya berikan informasi jika Anda memiliki data valid tentang kombinasi atau interaksi tersebut.
- Jika tidak tersedia informasi pasti tentang penggunaan bersamaan atau interaksi dua obat, katakan dengan jelas bahwa informasi tidak tersedia atau perlu dikonfirmasi ke dokter.
- Jangan memberikan instruksi atau aturan pakai yang tidak spesifik dan tidak bersumber jelas (misalnya: “10-15 menit sebelum makan” tanpa dasar).
- Jangan membuat asumsi atau menebak. Jangan memberikan informasi tambahan yang tidak diminta.
- Gunakan bahasa medis yang baku namun tetap mudah dipahami pasien dewasa.
- Jangan mengulang pertanyaan pengguna dan jangan menyapa atau menutup percakapan.

# Perintah Tambahan untuk LLM (jika knowledge base tidak memiliki jawaban spesifik):
Jika pertanyaan berkaitan dengan 'mengapa', 'bagaimana', 'apa yang harus dilakukan', atau mencari penjelasan yang lebih mendalam dari data faktual, berikan jawaban yang informatif namun tetap ringkas dan fokus pada topik medis. Jika saran medis diperlukan, selalu tekankan pentingnya konsultasi dengan profesional kesehatan.
[/INST]"""

# prompt
prompt = ChatPromptTemplate.from_messages([
    ("system", SYSTEM_PROMPT),
    ("human", "{input}")
])

# ==== Logging ====
def log_chat(user_msg, bot_msg, log_path="chat_logs.jsonl"):
    log_entry = {
        "timestamp": datetime.now().isoformat(),
        "user": user_msg,
        "bot": bot_msg
    }
    with open(log_path, "a", encoding="utf-8") as f:
        f.write(json.dumps(log_entry, ensure_ascii=False) + "\n")

# ==== Chatbot Class ====
class Chatbot:
    def __init__(self, kb_source=None, kb_kombinasi_source=None):
        # Load KB utama
        self.kb = {} 
        if isinstance(kb_source, str):
            try:
                with open(kb_source, 'r', encoding='utf-8') as f:
                    self.kb = json.load(f)
            except FileNotFoundError:
                print(f"Error: File knowledge_base.json tidak ditemukan di '{kb_source}'")
            except json.JSONDecodeError as e:
                print(f"Error: Gagal mem-parsing knowledge_base.json. Pastikan format JSON benar: {e}")
            except Exception as e:
                print(f"Error tak terduga saat memuat knowledge_base.json: {e}")
        elif isinstance(kb_source, dict):
            self.kb = kb_source
        else:
            raise ValueError("Knowledge base harus berupa path file atau dict.")

        # Load KB kombinasi
        self.kb_kombinasi = [] 
        if kb_kombinasi_source:
            if isinstance(kb_kombinasi_source, str):
                try:
                    with open(kb_kombinasi_source, 'r', encoding='utf-8') as f:
                        loaded_data = json.load(f)
                        if isinstance(loaded_data, dict) and "kombinasi" in loaded_data:
                            self.kb_kombinasi = loaded_data["kombinasi"]
                        elif isinstance(loaded_data, list):
                            self.kb_kombinasi = loaded_data
                        else:
                            print(f"Peringatan: Struktur kb_kombinasi.json tidak sesuai. Harusnya list atau dict dengan kunci 'kombinasi'. Ditemukan: {type(loaded_data)}")
                except FileNotFoundError:
                    print(f"Error: File kb_kombinasi.json tidak ditemukan di '{kb_kombinasi_source}'")
                except json.JSONDecodeError as e:
                    print(f"Error: Gagal mem-parsing kb_kombinasi.json. Pastikan format JSON benar dan tidak ada karakter tersembunyi: {e}")
                except Exception as e:
                    print(f"Error tak terduga saat memuat kb_kombinasi: {e}")
            elif isinstance(kb_kombinasi_source, (list, dict)):
                if isinstance(kb_kombinasi_source, dict):
                    self.kb_kombinasi = kb_kombinasi_source.get("kombinasi", [])
                else:
                    self.kb_kombinasi = kb_kombinasi_source
            else:
                raise ValueError("kb_kombinasi harus berupa path file, list, atau dict.")

        # PENTING: Inisialisasi LLM chain di dalam __init__ Chatbot
        self.llm = Ollama(
            model="llama3.2",
            temperature=0.0,
            top_p=0.9,
            num_ctx=2048,
            num_thread=4,
            stop=["</s>"],
            repeat_penalty=1.1,
            top_k=40
        )
        self.prompt_template = ChatPromptTemplate.from_messages([
            ("system", SYSTEM_PROMPT),
            ("human", "{input}")
        ])
        self.chain = self.prompt_template | self.llm | StrOutputParser() # Buat chain di sini!

        # Debugging final untuk __init__
        print(f"Loaded KB utama (items): {len(self.kb) if isinstance(self.kb, dict) else 0}")
        print(f"Loaded kb_kombinasi (items): {len(self.kb_kombinasi)}")
        print(f"Chatbot initialized. LLM chain is {'available' if self.chain else 'NOT available'}") # DEBUG tambahan

    def normalize_text(self, text):
        return text.lower().strip()

    def find_obat_info(self, query):
        q = self.normalize_text(query)
        if isinstance(self.kb, dict):
            for cat, items in self.kb.items():
                if isinstance(items, list):
                    for item in items:
                        if self.normalize_text(item.get("nama", "")) in q:
                            return item, item.get("nama", "")
                        for merk in item.get("merk_dagang", []):
                            if self.normalize_text(merk) in q:
                                return item, item.get("nama", "")
        return None, None
    
    def get_info(self, query):
        query_norm = self.normalize_text(query)
        info = None
        info_k = None
        response_from_kb = None 

        # Map common query terms to KB categories
        disease_keywords = {
            "darah tinggi": "hipertensi",
            "hipertensi": "hipertensi",
            "kolesterol": "kolesterol",
            "gula darah": "diabetes",
            "kencing manis": "diabetes",
            "diabetes": "diabetes"
        }

        found_disease_category = None
        for keyword, category_name in disease_keywords.items():
            if keyword in query_norm and ("obat" in query_norm or "apa saja" in query_norm or "daftar" in query_norm):
                found_disease_category = category_name
                break
        
        if found_disease_category:
            if found_disease_category in self.kb:
                drugs_in_category = self.kb[found_disease_category]
                drug_names = [drug['nama'] for drug in drugs_in_category]
                if drug_names:
                    response_from_kb = f"Untuk penyakit **{found_disease_category}**, beberapa contoh obat yang sering dikonsumsi oleh penderita antara lain: **{', '.join(drug_names)}**."
                else:
                    response_from_kb = f"Saya tidak menemukan daftar obat spesifik untuk penyakit **{found_disease_category}** dalam basis data saya."
            else:
                response_from_kb = f"Saya tidak memiliki informasi tentang obat untuk penyakit **{found_disease_category}** dalam basis data saya."
            
            log_chat(query, response_from_kb)
            return response_from_kb

        # === PROSES KB KOMBINASI ===
        kombinasi_list = self.kb_kombinasi 

        for item in kombinasi_list:
            obat_a = self.normalize_text(item.get("obat_a", ""))
            obat_b = self.normalize_text(item.get("obat_b", ""))
            
            if (obat_a in query_norm and obat_b in query_norm) or \
            (obat_b in query_norm and obat_a in query_norm):
                if "bersamaan" in query_norm or "bersama" in query_norm or "kombinasi" in query_norm or "dengan" in query_norm or "barengan" in query_norm or "interaksi" in query_norm:
                    info_k = item
                    break 

        # Handle response for combination drugs first
        if info_k:
            response_from_kb = info_k.get("jawaban", None)
            if response_from_kb:
                return response_from_kb

        # === PROSES NORMAL KB (single-drug) ===
        info, _ = self.find_obat_info(query)

        if info:
            # === DETEKSI PERTANYAAN BERDASARKAN INTENT ===
            is_efek_samping = "efek samping" in query_norm or "bengkak" in query_norm or "pembengkakan" in query_norm
            is_dosis = "dosis" in query_norm or "cara minum" in query_norm or "berapa kali" in query_norm or "kapan minum" in query_norm or "kapan" in query_norm
            is_interaksi_obat = "interaksi obat" in query_norm
            is_catatan = "catatan khusus" in query_norm
            is_golongan = "golongan" in query_norm
            is_indikasi = "apa itu" in query_norm or "untuk apa" in query_norm
            is_kategori_penyakit = "kategori penyakit" in query_norm or "penyakit" in query_norm
            is_peringatan = any(keyword in query_norm for keyword in ["peringatan", "apa yang harus diperhatikan"])
            is_kontraindikasi = any(keyword in query_norm for keyword in ["kontraindikasi", "larangan", "tidak boleh diminum", "tidak boleh diberikan"])
            
            is_why_question = "mengapa" in query_norm or "kenapa" in query_norm
            is_what_to_do_question = any(k in query_norm for k in ["apa yang harus dilakukan", "bagaimana mengatasi", "solusi"])

            # Try to get direct KB answers for specific intents
            if is_golongan:
                if info.get("golongan"):
                    response_from_kb = f"Golongan obat {info['golongan']}"
            elif is_kategori_penyakit:
                if info.get("kategori_penyakit"):
                    response_from_kb = f"Kategori penyakit {info['kategori_penyakit']}"
            elif is_indikasi:
                if info.get("indikasi"):
                    response_from_kb = f"{info['indikasi']}"
            elif is_dosis:
                if info.get("dosis"):
                    if isinstance(info["dosis"], list):
                        response_from_kb = "\n".join(info["dosis"])
                    else:
                        response_from_kb = info["dosis"]
            elif is_interaksi_obat:
                if info.get("interaksi_obat") and len(info["interaksi_obat"]) > 0:
                    response_from_kb = "\n".join([f"{x['obat']}: {x['efek']}" for x in info["interaksi_obat"]])
            elif is_peringatan:
                if info.get("peringatan") and len(info["peringatan"]) > 0:
                    response_from_kb = "Peringatan:\n" + "\n".join(info["peringatan"])
            elif is_catatan:
                if info.get("catatan_khusus"):
                    response_from_kb = f"Catatan khusus:\n{info['catatan_khusus']}"
            elif is_kontraindikasi:
                if info.get("kontraindikasi") and len(info["kontraindikasi"]) > 0:
                    response_from_kb = "Kontraindikasi:\n" + "\n".join(info["kontraindikasi"])
            elif is_efek_samping: 
                if info.get("efek_samping") and len(info["efek_samping"]) > 0:
                    if not is_why_question and not is_what_to_do_question:
                        response_from_kb = ", ".join(info["efek_samping"])

        # Final decision: KB response or LLM fallback
        if response_from_kb:
            return response_from_kb
        elif self.chain: # self.chain should now always be available
            try:
                llm_response = self.chain.invoke({"input": query_norm})
                return llm_response if llm_response else "Maaf, saya belum bisa menjawab pertanyaan ini."
            except Exception as e:
                return f"Maaf, terjadi kesalahan dalam pemrosesan LLM: {str(e)}. Silakan coba lagi."
        else:
            return "Informasi tidak ditemukan. (Fallback LLM tidak tersedia)" 

    def format_full_info(self, nama, data):
        info = f"{nama}:"
        info += f"- Golongan: {data.get('golongan','-')}"
        info += f"- Kategori Penyakit: {data.get('kategori_penyakit','-')}"
        info += f"- Indikasi: {data.get('indikasi', '-')}"
        info += f"- Kontraindikasi: {', '.join(data.get('kontraindikasi', [])) or '-'}\n"
        info += f"- Dosis: {data.get('dosis', '-')}"
        info += f"- Efek Samping: {', '.join(data.get('efek_samping', [])) or '-'}\n"
        if data.get("interaksi_obat"):
            info += "- Interaksi Obat:\n" + "\n".join([f"  - {x['obat']}: {x['efek']}" for x in data['interaksi_obat']]) + "\n"
        if data.get("catatan_khusus"):
            info += f"- Catatan Khusus: {data['catatan_khusus']}\n"
        return info.strip()

# ==== Fungsi Utama ====
def get_bot_response(chatbot: Chatbot, user_input: str, priority="kb-first") -> str:
    user_input = user_input.strip()
    if not user_input:
        return "Pertanyaan tidak boleh kosong"

    try:
        response = chatbot.get_info(user_input)
        
    except Exception as e:
        response = f"Maaf, terjadi kesalahan dalam pemrosesan: {str(e)}"

    log_chat(user_input, response)
    return response

# ==== CLI ====
if __name__ == "__main__":
    try:
        bot = Chatbot(kb_source="knowledge_base.json", kb_kombinasi_source="kb_kombinasi.json") 
        print("Chatbot Medis Penyakit Kronis. Ketik 'exit' untuk keluar.")
        while True:
            user_input = input("Anda: ")
            if user_input.lower().strip() == "exit":
                break
            reply = get_bot_response(bot, user_input, priority="kb-first") 
            print(f"Bot: {reply}\n")
    except Exception as e:
        print(f"Error saat memulai chatbot: {str(e)}")
