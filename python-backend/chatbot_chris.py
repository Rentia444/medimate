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

# ==== Inisialisasi LLM ====
llm = Ollama(
    model="llama3.2",
    temperature=0.0,
    top_p=0.9,
    num_ctx=2048,
    num_thread=4,
    stop=["</s>"],
    repeat_penalty=1.1,
    top_k=40
)
SYSTEM_PROMPT = """[INST]
Anda adalah asisten medis digital yang terpercaya dan profesional. Jawaban Anda harus ringkas (maksimal 3 kalimat), akurat, dan hanya mencakup informasi yang secara eksplisit diminta dalam pertanyaan.

Topik yang Anda tangani terbatas pada:
- Obat untuk penyakit kronis seperti diabetes tipe 2, hipertensi, dan kolesterol tinggi
- Efek samping, dosis umum, kontraindikasi, interaksi obat (dengan obat lain atau makanan)
- Cara dan waktu penggunaan obat secara aman

PETUNJUK PENTING:
- Jika pertanyaan menyebut dua atau lebih obat, hanya berikan informasi jika Anda memiliki data valid tentang kombinasi atau interaksi tersebut.
- Jika tidak tersedia informasi pasti tentang penggunaan bersamaan atau interaksi dua obat, katakan dengan jelas bahwa informasi tersebut tidak ada.
- Jika pertanyaan tidak relevan dengan topik medis atau obat-obatan, atau jika Anda tidak memiliki informasi yang diminta, katakan bahwa Anda tidak memiliki informasi dan sarankan pengguna untuk menanyakan hal lain.
[/INST]"""

CHAT_PROMPT = ChatPromptTemplate.from_messages([
    ("system", SYSTEM_PROMPT),
    ("human", "{question}")
])

output_parser = StrOutputParser()

chain = CHAT_PROMPT | llm | output_parser

def ask_llm(question: str) -> str:
    try:
        return chain.invoke({"question": question})
    except Exception as e:
        return f"Maaf, terjadi masalah saat menghubungi model bahasa: {str(e)}"

def log_chat(user_input: str, bot_response: str):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_entry = f"[{timestamp}] User: {user_input} | Bot: {bot_response}\n"
    with open("chat_log.txt", "a", encoding="utf-8") as f:
        f.write(log_entry)


class Chatbot:
    def __init__(self, kb_source="knowledge_base.json", kb_kombinasi_source="kb_kombinasi.json"):
        self.knowledge_base = self._load_json(kb_source)
        self.kombinasi_base = self._load_json(kb_kombinasi_source)
        self.all_drug_names = self._extract_all_drug_names()

    def _load_json(self, file_path):
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                return json.load(f)
        except FileNotFoundError:
            print(f"Error: File {file_path} not found.")
            return {}
        except json.JSONDecodeError:
            print(f"Error: Could not decode JSON from {file_path}. Check file format.")
            return {}

    def _extract_all_drug_names(self):
        names = set()
        for category_data in self.knowledge_base.values():
            for drug in category_data:
                names.add(drug['nama'].lower())
                for brand in drug.get('merk_dagang', []):
                    names.add(brand.lower())
        
        # Add drug names from kombinasi_base as well
        if 'kombinasi' in self.kombinasi_base:
            for combo in self.kombinasi_base['kombinasi']:
                names.add(combo['obat_a'].lower())
                names.add(combo['obat_b'].lower())
        return list(names)

    def _find_drug_in_kb(self, drug_name):
        for category, drugs in self.knowledge_base.items():
            for drug in drugs:
                if drug_name.lower() == drug['nama'].lower() or \
                   drug_name.lower() in [m.lower() for m in drug.get('merk_dagang', [])]:
                    return drug
        return None

    def get_info(self, user_input: str) -> str:
        user_input_lower = user_input.lower()

        # Define keywords for specific information requests
        specific_keywords = {
            'dosis': ['dosis', 'berapa kali minum', 'takaran'],
            'efek_samping': ['efek samping', 'efek sampingnya', 'efek negatif'],
            'kontraindikasi': ['kontraindikasi', 'tidak boleh untuk', 'siapa yang tidak boleh'],
            'indikasi': ['indikasi', 'untuk apa', 'fungsi'],
            'peringatan': ['peringatan', 'hati-hati'],
            'interaksi_obat': ['interaksi obat', 'interaksi dengan', 'berinteraksi dengan', 'digunakan bersama']
        }

        # Check for specific information request
        requested_info_type = None
        for info_type, keywords in specific_keywords.items():
            for keyword in keywords:
                if keyword in user_input_lower:
                    requested_info_type = info_type
                    break
            if requested_info_type:
                break

        # Try to find drug combinations first
        if 'kombinasi' in self.kombinasi_base:
            for combo in self.kombinasi_base['kombinasi']:
                obat_a_lower = combo['obat_a'].lower()
                obat_b_lower = combo['obat_b'].lower()

                # Use word boundaries for combination checks too for precision
                pattern_a = r'\b' + re.escape(obat_a_lower) + r'\b'
                pattern_b = r'\b' + re.escape(obat_b_lower) + r'\b'

                if (re.search(pattern_a, user_input_lower) and re.search(pattern_b, user_input_lower)):
                    if requested_info_type == 'interaksi_obat' or requested_info_type is None:
                        return combo['jawaban']
                    else:
                        # If a specific info type other than interaction is asked for a combo,
                        # it's usually not relevant, so we'll indicate specific info is not found for combo
                        return f"Saya tidak memiliki informasi spesifik tentang {requested_info_type.replace('_',' ')} untuk kombinasi {combo['obat_a']} dan {combo['obat_b']}."
        
        # Try to find individual drug information
        found_drugs = []
        for drug_name_candidate in self.all_drug_names:
            # Use word boundary regex to find drug names as whole words
            pattern = r'\b' + re.escape(drug_name_candidate) + r'\b'
            if re.search(pattern, user_input_lower):
                found_drugs.append(drug_name_candidate)


        if len(found_drugs) == 1:
            drug_info = self._find_drug_in_kb(found_drugs[0])
            if drug_info:
                drug_name = drug_info['nama']
                if requested_info_type:
                    if requested_info_type == 'dosis':
                        dosis = drug_info.get('dosis')
                        return f"Dosis untuk {drug_name}: {', '.join(dosis) if dosis else 'Tidak tersedia informasi dosis.'}"
                    elif requested_info_type == 'efek_samping':
                        efek_samping = drug_info.get('efek_samping')
                        return f"Efek samping umum {drug_name}: {', '.join(efek_samping) if efek_samping else 'Tidak tersedia informasi efek samping.'}"
                    elif requested_info_type == 'kontraindikasi':
                        kontraindikasi = drug_info.get('kontraindikasi')
                        return f"Kontraindikasi {drug_name}: {', '.join(kontraindikasi) if kontraindikasi else 'Tidak tersedia informasi kontraindikasi.'}"
                    elif requested_info_type == 'indikasi':
                        indikasi = drug_info.get('indikasi')
                        return f"Indikasi {drug_name}: {indikasi if indikasi else 'Tidak tersedia informasi indikasi.'}"
                    elif requested_info_type == 'peringatan':
                        peringatan = drug_info.get('peringatan')
                        return f"Peringatan untuk {drug_name}: {', '.join(peringatan) if peringatan else 'Tidak tersedia informasi peringatan.'}"
                    elif requested_info_type == 'interaksi_obat':
                        interactions = drug_info.get('interaksi_obat', [])
                        
                        # Identify ALL drugs found in the user input for interaction check
                        # This should usually be 1 (the main drug) for unknown substance interactions.
                        drugs_in_query_for_interaction_check = []
                        for drug_name_candidate_inner in self.all_drug_names:
                            pattern_inner = r'\b' + re.escape(drug_name_candidate_inner) + r'\b'
                            if re.search(pattern_inner, user_input_lower):
                                drugs_in_query_for_interaction_check.append(drug_name_candidate_inner)

                        # Logic for determining if it's an interaction with an unknown substance
                        # Condition: only one known drug found AND an interaction keyword is present
                        if len(drugs_in_query_for_interaction_check) == 1 and any(phrase in user_input_lower for phrase in specific_keywords['interaksi_obat']):
                            found_known_interaction_drug_in_query = False
                            for interaction_entry in interactions:
                                known_inter_drug_name = interaction_entry.get('obat', '').lower()
                                # Check if any of the known interacting drugs (from this drug's KB entry) are present in the user input
                                # Use word boundary regex for precise matching of known interacting drugs
                                if known_inter_drug_name: # Ensure it's not empty
                                    pattern_inter_drug = r'\b' + re.escape(known_inter_drug_name) + r'\b'
                                    if re.search(pattern_inter_drug, user_input_lower):
                                        found_known_interaction_drug_in_query = True
                                        break
                            
                            # If an interaction is implied, but not with a known interacting drug from its KB entry
                            if not found_known_interaction_drug_in_query:
                                return f"Saya tidak memiliki informasi spesifik tentang interaksi {drug_name} dengan zat yang Anda sebutkan."
                        
                        # Fallback to existing interaction display if a known interaction is found or no specific unknown interaction was implied
                        if interactions:
                            response = f"Interaksi obat untuk {drug_name}:\n"
                            for i in interactions:
                                response += f"  - Dengan {i.get('obat', 'N/A')}: {i.get('efek', 'N/A')}\n"
                            return response
                        else:
                            return f"Tidak tersedia informasi interaksi obat untuk {drug_name}."
                    else:
                        # Fallback to comprehensive if type is not specifically handled but exists
                        pass 
                
                # Default comprehensive response if no specific keyword or if specific keyword not found in the drug info
                response = f"Informasi untuk {drug_name}:\n"
                response += f"- Kategori Penyakit: {drug_info.get('kategori_penyakit', 'N/A')}\n"
                response += f"- Indikasi: {drug_info.get('indikasi', 'N/A')}\n"
                response += f"- Dosis: {', '.join(drug_info.get('dosis', ['N/A']))}\n"
                response += f"- Efek Samping Umum: {', '.join(drug_info.get('efek_samping', ['N/A']))}\n"
                
                interactions = drug_info.get('interaksi_obat', [])
                if interactions:
                    response += "- Interaksi Obat:\n"
                    for i in interactions:
                        response += f"  - Dengan {i.get('obat', 'N/A')}: {i.get('efek', 'N/A')}\n"
                
                warnings = drug_info.get('peringatan', [])
                if warnings:
                    response += "- Peringatan: {', '.join(warnings)}\n"
                
                contraindications = drug_info.get('kontraindikasi', [])
                if contraindications:
                    response += "- Kontraindikasi: {', '.join(contraindications)}\n"

                return response
            else:
                return f"Maaf, informasi tentang {found_drugs[0]} tidak ditemukan dalam basis data."
        elif len(found_drugs) > 1:
            # If multiple drugs are found but no specific combination in kb_kombinasi.json was found earlier,
            # this indicates a multi-drug query not handled by KB.
            return "Saya menemukan beberapa nama obat dalam pertanyaan Anda. Jika Anda ingin mengetahui interaksi spesifik antar obat, mohon sebutkan dengan jelas kombinasi obatnya. Saya tidak memiliki informasi spesifik dalam basis data."
        
        # If no drugs found or no specific keyword, this is likely irrelevant to KB,
        # so return a message that triggers LLM fallback.
        return "Maaf, saya tidak memiliki informasi spesifik yang Anda minta dari basis data saya. Silakan ajukan pertanyaan lain."

# ==== get_bot_response (Fungsi yang memanggil Chatbot dan LLM) ====
def get_bot_response(chatbot: Chatbot, user_input: str, priority="kb-first") -> str:
    user_input = user_input.strip()
    if not user_input:
        return "Pertanyaan tidak boleh kosong"

    try:
        kb_response = chatbot.get_info(user_input)
        
        # Check if KB response explicitly states it lacks specific information or is a general "not found"
        if kb_response and ("tidak memiliki informasi spesifik" in kb_response.lower() or "tidak ditemukan" in kb_response.lower()):
            # If KB couldn't give a specific answer, defer to LLM
            response = ask_llm(user_input)
        elif kb_response:
            # If KB provided a valid and specific answer
            response = kb_response
        else:
            # Fallback if kb_response is empty (for safety, though get_info should always return a string)
            response = ask_llm(user_input)

    except Exception as e:
        response = f"Maaf, terjadi kesalahan dalam pemrosesan: {str(e)}"

    log_chat(user_input, response)
    return response

# ==== CLI ====\
if __name__ == "__main__":
    try:
        bot = Chatbot(kb_source="knowledge_base.json", kb_kombinasi_source="kb_kombinasi.json")
        print("Chatbot Medis Penyakit Kronis. Ketik 'exit' untuk keluar.")
        while True:
            user_input = input("Anda: ")
            if user_input.lower().strip() == 'exit':
                break
            
            response = get_bot_response(bot, user_input) # Menggunakan get_bot_response
            print(f"Chatbot: {response}")

    except Exception as e:
        print(f"Terjadi kesalahan fatal saat inisialisasi chatbot: {e}")