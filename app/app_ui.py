import streamlit as st
import requests
import time
import os
import base64
from dotenv import load_dotenv

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
load_dotenv(os.path.join(BASE_DIR, ".env"))

st.set_page_config(page_title="Psikoloji AI", page_icon="🧠", layout="wide")

API_BASE_URL = os.getenv("API_BASE_URL", "http://127.0.0.1:8000")

if "user" not in st.session_state:
    st.session_state.user = None 
if "access_token" not in st.session_state:
    st.session_state.access_token = None
if "refresh_token" not in st.session_state:
    st.session_state.refresh_token = None
if "current_session_id" not in st.session_state:
    st.session_state.current_session_id = None
if "messages" not in st.session_state:
    st.session_state.messages = []
if "bg_image" not in st.session_state:
    st.session_state.bg_image = "linear-gradient(to right, #e0eafc, #cfdef3)"

def get_headers():
    return {"Authorization": f"Bearer {st.session_state.access_token}"} if st.session_state.access_token else {}

THEMES = {
    "Soft Mavi (Varsayılan)": "linear-gradient(to right, #e0eafc, #cfdef3)",
    "Sıcak Bej": "linear-gradient(to right, #fdfbfb, #ebedee)",
    "Mistik Dağlar": "url('https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=1920&q=80')",
    "Sakin Orman": "url('https://images.unsplash.com/photo-1441974231531-c6227db76b6e?auto=format&fit=crop&w=1920&q=80')",
    "Huzurlu Okyanus": "url('https://images.unsplash.com/photo-1505118380757-91f5f5632de0?auto=format&fit=crop&w=1920&q=80')",
    "Yıldızlı Gece": "url('https://images.unsplash.com/photo-1419242902214-272b3f66ee7a?auto=format&fit=crop&w=1920&q=80')"
}

st.markdown(f"""
<style>
    /* Ana Arka Plan */
    .stApp {{
        background: {st.session_state.bg_image};
        background-size: cover;
        background-position: center;
        background-attachment: fixed;
    }}

    /* Yazı Renkleri */
    .stMarkdown, .stText, h1, h2, h3, p {{ color: #333333 !important; }}
    .stTextInput input {{ background-color: #ffffff !important; color: #333333 !important; border: 1px solid #d1d5db; }}
    
    /* Sidebar */
    section[data-testid="stSidebar"] {{ background-color: rgba(255, 255, 255, 0.95) !important; border-right: 1px solid #e5e7eb; }}
    section[data-testid="stSidebar"] * {{ color: #333333 !important; }}

    /* Sohbet Balonları */
    .chat-user {{
        background-color: #2563eb; color: white !important; padding: 15px 20px;
        border-radius: 20px 20px 5px 20px; margin: 10px 0; text-align: right;
        box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1); display: inline-block; font-size: 16px;
    }}
    .chat-ai {{
        background-color: #ffffff; color: #1f2937 !important; padding: 15px 20px;
        border-radius: 20px 20px 20px 5px; margin: 10px 0; text-align: left;
        border: 1px solid #f3f4f6; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);
        display: inline-block; font-size: 16px;
    }}

    /* KRİZ UYARI KUTUSU CSS */
    .crisis-alert {{
        background-color: #fee2e2; 
        color: #991b1b !important;
        padding: 20px;
        border-radius: 10px;
        border-left: 8px solid #ef4444;
        font-weight: bold;
        box-shadow: 0 10px 15px -3px rgba(239, 68, 68, 0.2);
        margin: 10px 0;
        font-size: 16px;
    }}
</style>
""", unsafe_allow_html=True)

def login_page():
    col1, col2, col3 = st.columns([1, 2, 1])
    with col2:
        st.markdown("""
        <div style='background-color: rgba(255, 255, 255, 0.95); padding: 40px; border-radius: 24px; text-align: center; margin-top: 60px;'>
            <h1 style='color:#2563eb; font-size: 3rem;'>🧠 Psikoloji AI</h1>
            <p style='color:#6b7280;'>Güvenli, Gizli ve Empatik Destek Alanınız.</p>
        </div>
        """, unsafe_allow_html=True)
        
        tab1, tab2 = st.tabs(["Giriş Yap", "Kayıt Ol"])

        with tab1:
            username = st.text_input("Kullanıcı Adı", key="login_user")
            password = st.text_input("Şifre", type="password", key="login_pass")
            if st.button("Giriş Yap", type="primary", use_container_width=True):
                try:
                    resp = requests.post(f"{API_BASE_URL}/auth/login", json={"username": username, "password": password})
                    if resp.status_code == 200:
                        data = resp.json()
                        st.session_state.user = data["user"]
                        st.session_state.access_token = data["access_token"]
                        st.session_state.refresh_token = data.get("refresh_token")
                        st.success(f"Hoş geldin {data['user'].get('display_name', '')}!")
                        time.sleep(0.5)
                        st.rerun()
                    else:
                        st.error("Hatalı kullanıcı adı veya şifre.")
                except Exception as e:
                    st.error(f"Sunucuya ulaşılamıyor: {e}")

        with tab2:
            new_user = st.text_input("Kullanıcı Adı (Giriş için)", key="reg_user")
            new_pass = st.text_input("Şifre", type="password", key="reg_pass")
            new_name = st.text_input("Görünen Adın", key="reg_name")
            new_age = st.number_input("Yaşın", min_value=10, max_value=99, step=1, key="reg_age")
            new_gender = st.selectbox("Cinsiyet", ["Belirtilmedi", "Kadın", "Erkek"], key="reg_gender")
            
            if st.button("Kayıt Ol", use_container_width=True):
                if new_user and new_pass and new_name:
                    try:
                        payload = {
                            "username": new_user,
                            "password": new_pass,
                            "display_name": new_name,
                            "age": new_age,
                            "gender": new_gender
                        }
                        resp = requests.post(f"{API_BASE_URL}/auth/register", json=payload)
                        if resp.status_code == 200:
                            st.success("Kayıt Başarılı! Şimdi giriş yapabilirsiniz.")
                        else:
                            st.error(f"Kayıt başarısız: {resp.json().get('detail', 'Bilinmeyen hata')}")
                    except Exception as e:
                        st.error(f"Sunucuya ulaşılamıyor: {e}")
                else:
                    st.warning("Lütfen tüm alanları doldur.")

def chat_page():
    user = st.session_state.user
    
    with st.sidebar:
        avatar = '👩' if user.get("gender") == 'Kadın' else '👨' if user.get("gender") == 'Erkek' else '👤'
        st.markdown(f"""
        <div style='text-align:center;padding:20px;background:#f3f4f6;border-radius:15px;margin-bottom:20px; border:1px solid #e5e7eb;'>
            <div style='font-size:50px;'>{avatar}</div>
            <h3 style='margin: 10px 0; color:#1f2937 !important;'>{user.get("display_name", "")}</h3>
            <p style='color:#6b7280 !important; font-size: 0.9rem;'>{user.get("gender", "")}, {user.get("age", "")} Yaşında</p>
        </div>
        """, unsafe_allow_html=True)
        
        with st.expander("⚙️ Profil Ayarları"):
            new_name = st.text_input("Adın", value=user.get("display_name", ""))
            new_age = st.number_input("Yaşın", value=user.get("age", 0))
            
            options = ["Belirtilmedi", "Kadın", "Erkek"]
            try:
                current_idx = options.index(user.get("gender", "Belirtilmedi"))
            except ValueError:
                current_idx = 0
            new_gender = st.selectbox("Cinsiyet", options, index=current_idx)
            
            new_profession = st.text_input("Meslek", value=user.get("profession", ""))
            new_city = st.text_input("Yaşadığın Şehir", value=user.get("city", ""))
            new_marital_status = st.text_input("Medeni Durum", value=user.get("marital_status", "Belirtilmedi"))
            new_child_count = st.number_input("Çocuk Sayısı", min_value=0, max_value=20, value=int(user.get("child_count", 0)), step=1)
            new_chronic_illness = st.text_input("Kronik Rahatsızlığın (Varsa)", value=user.get("chronic_illness", ""))
            new_trauma_summary = st.text_area("Önemli Travmalar / Geçmiş Detayları", value=user.get("trauma_summary", ""))
            
            if st.button("Güncelle"):
                try:
                    payload = {
                        "display_name": new_name,
                        "age": new_age,
                        "gender": new_gender,
                        "profession": new_profession,
                        "city": new_city,
                        "marital_status": new_marital_status,
                        "child_count": new_child_count,
                        "chronic_illness": new_chronic_illness,
                        "trauma_summary": new_trauma_summary,
                        "avatar": "default"
                    }
                    resp = requests.put(f"{API_BASE_URL}/users/{user['id']}/profile", json=payload, headers=get_headers())
                    if resp.status_code == 200:
                        st.session_state.user = resp.json()["user"]
                        st.success("Güncellendi!")
                        time.sleep(0.5)
                        st.rerun()
                    else:
                        st.error(f"Hata: {resp.json().get('detail')}")
                except Exception as e:
                    st.error(f"Bağlantı hatası: {e}")

        with st.expander("🎨 Görünüm & Atmosfer"):
            selected_theme_name = st.selectbox("Bir Atmosfer Seç:", list(THEMES.keys()))
            if st.button("Uygula"):
                st.session_state.bg_image = THEMES[selected_theme_name]
                st.rerun()

        st.divider()
        st.subheader("🗂️ Sohbet Geçmişi")
        if st.button("➕ Yeni Sohbet Başlat", use_container_width=True):
            st.session_state.current_session_id = None
            st.session_state.messages = []
            st.rerun()

        try:
            resp = requests.get(f"{API_BASE_URL}/chat/sessions/{user['id']}", headers=get_headers())
            if resp.status_code == 200:
                sessions = resp.json().get("sessions", [])
                for sess in sessions:
                    b_type = "primary" if st.session_state.current_session_id == sess["id"] else "secondary"
                    sess_title = (sess["title"][:22] + '..') if len(sess["title"]) > 22 else sess["title"]
                    
                    scol1, scol2 = st.columns([5, 1])
                    with scol1:
                        if st.button(f"📄 {sess_title}", key=f"sess_{sess['id']}", type=b_type, use_container_width=True):
                            st.session_state.current_session_id = sess["id"]
                            hist_resp = requests.get(f"{API_BASE_URL}/chat/history/{sess['id']}", headers=get_headers())
                            if hist_resp.status_code == 200:
                                st.session_state.messages = hist_resp.json().get("messages", [])
                            st.rerun()
                    with scol2:
                        if st.button("🗑️", key=f"del_{sess['id']}", use_container_width=True):
                            requests.delete(f"{API_BASE_URL}/chat/sessions/{sess['id']}", headers=get_headers())
                            if st.session_state.current_session_id == sess["id"]:
                                st.session_state.current_session_id = None
                                st.session_state.messages = []
                            st.rerun()
        except Exception as e:
            st.error("Oturumlar yüklenemedi.")

        st.divider()
        st.subheader("🎤 Sesli Mesaj")
        audio_val = st.audio_input("Ses kaydedin")
        if audio_val and st.button("Gönder", use_container_width=True, type="primary"):
            st.session_state.pending_audio = audio_val
            st.rerun()

        st.divider()
        if st.button("Çıkış Yap"):
            if st.session_state.refresh_token:
                try:
                    requests.post(f"{API_BASE_URL}/auth/logout", json={"refresh_token": st.session_state.refresh_token})
                except:
                    pass
            st.session_state.user = None
            st.session_state.access_token = None
            st.session_state.refresh_token = None
            st.session_state.current_session_id = None
            st.session_state.messages = []
            st.rerun()

    st.markdown(f"""
    <div style='text-align: center; margin-bottom: 30px;'>
        <h2 style='color: #1f2937; margin-bottom: 5px;'>Merhaba {user.get("display_name", "")}, seni dinliyorum.</h2>
        <p style='color: #6b7280; font-size: 0.95rem;'>Bugün zihninden neler geçiyor?</p>
    </div>
    """, unsafe_allow_html=True)
    
    for msg in st.session_state.messages:
        role = msg.get("role", "")
        content = msg.get("content", "")
        if role == "user":
            st.markdown(f"<div style='display:flex;justify-content:flex-end;'><div class='chat-user'>{content}</div></div>", unsafe_allow_html=True)
        else:
            st.markdown(f"<div style='display:flex;justify-content:flex-start;'><div style='margin-right:12px; font-size:28px; padding-top:10px;'>🧠</div><div class='chat-ai'>{content}</div></div>", unsafe_allow_html=True)

    if prompt := st.chat_input("Buraya yaz..."):
        st.session_state.messages.append({"role": "user", "content": prompt})
        st.rerun()

    # Sesli mesaj işlemesi
    if getattr(st.session_state, "pending_audio", None) is not None:
        audio_data = st.session_state.pending_audio
        st.session_state.pending_audio = None # Sıfırla
        with st.spinner("Sesiniz işleniyor..."):
            try:
                files = {"audio_file": ("audio.wav", audio_data, "audio/wav")}
                data = {
                    "user_name": user.get("display_name", ""),
                    "age": user.get("age", 0),
                    "gender": user.get("gender", "Belirtilmedi"),
                    "session_id": st.session_state.current_session_id or "",
                    "k": 3
                }
                response = requests.post(f"{API_BASE_URL}/mobile-chat", files=files, data=data, headers=get_headers())
                if response.status_code == 200:
                    res_data = response.json()
                    transcript = res_data.get("transcript", "Sesli mesaj")
                    reply = res_data.get("reply")
                    is_crisis = res_data.get("is_crisis", False)
                    new_session_id = res_data.get("session_id")
                    audio_base64 = res_data.get("audio_base64")
                    
                    if new_session_id:
                        st.session_state.current_session_id = new_session_id
                    
                    st.session_state.messages.append({"role": "user", "content": f"🎤 *Sesli Mesaj:* {transcript}"})
                    st.session_state.messages.append({"role": "model", "content": reply})
                    
                    if audio_base64:
                        st.audio(base64.b64decode(audio_base64), format='audio/mpeg', autoplay=True)
                        
                    st.rerun()
                else:
                    st.error(f"Ses işleme hatası: {response.status_code} - {response.text}")
            except Exception as e:
                st.error(f"Bağlantı Hatası: {e}")

    if st.session_state.messages and st.session_state.messages[-1]["role"] == "user":
        with st.spinner("Düşünüyor..."):
            try:
                prof = {
                    "name": user.get("display_name", ""), 
                    "age": user.get("age", 0), 
                    "gender": user.get("gender", "Belirtilmedi"),
                    "profession": user.get("profession", ""),
                    "city": user.get("city", ""),
                    "marital_status": user.get("marital_status", "Belirtilmedi"),
                    "child_count": user.get("child_count", 0),
                    "chronic_illness": user.get("chronic_illness", ""),
                    "trauma_summary": user.get("trauma_summary", "")
                }
                
                # Sadece önceki mesajları gönder (son mesajı query olarak gönderiyoruz)
                hist = [{"role": "user" if m["role"] == "user" else "model", "content": m["content"]} for m in st.session_state.messages[:-1]]
                
                payload = {
                    "query": st.session_state.messages[-1]["content"],
                    "session_id": st.session_state.current_session_id,
                    "history": hist,
                    "user_profile": prof,
                    "k": 3
                }
                
                response = requests.post(f"{API_BASE_URL}/chat", json=payload, headers=get_headers())
                if response.status_code == 200:
                    data = response.json()
                    reply = data["reply"]
                    is_crisis = data.get("is_crisis", False)
                    new_session_id = data.get("session_id")
                    
                    if new_session_id:
                        st.session_state.current_session_id = new_session_id

                    if is_crisis:
                        st.markdown(f"<div class='crisis-alert'>🚨 {reply}</div>", unsafe_allow_html=True)
                    else:
                        st.markdown(f"<div style='display:flex;justify-content:flex-start;'><div style='margin-right:12px; font-size:28px; padding-top:10px;'>🧠</div><div class='chat-ai'>{reply}</div></div>", unsafe_allow_html=True)
                    
                    st.session_state.messages.append({"role": "model", "content": reply})
                else:
                    st.error(f"Sunucu Hatası: {response.status_code} - {response.text}")
            except Exception as e:
                st.error(f"Bağlantı Hatası: {e}")

if st.session_state.user:
    chat_page()
else:
    login_page()