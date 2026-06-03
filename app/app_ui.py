import streamlit as st
import requests
import time
import os
import base64
from dotenv import load_dotenv
from PIL import Image
import io

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
load_dotenv(os.path.join(BASE_DIR, ".env"))

st.set_page_config(page_title="Psikoloji AI", page_icon="🧠", layout="wide")

API_BASE_URL = os.getenv("API_BASE_URL", "http://127.0.0.1:8000")
FIREBASE_API_KEY = "AIzaSyD3jYz7nWc0w7xd5cBRSrjiqHpUmWqDFtY"

# --- Oturum State Başlatma ---
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
if "dark_mode" not in st.session_state:
    st.session_state.dark_mode = False
if "selected_voice_id" not in st.session_state:
    st.session_state.selected_voice_id = "EXAVITQu4vr4xnSDxMaL"
if "tts_enabled" not in st.session_state:
    st.session_state.tts_enabled = False
if "audio_to_play" not in st.session_state:
    st.session_state.audio_to_play = None

# --- Firebase Rest API Yardımcıları ---
def firebase_email_login(email, password):
    url = f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={FIREBASE_API_KEY}"
    payload = {"email": email, "password": password, "returnSecureToken": True}
    try:
        resp = requests.post(url, json=payload)
        return resp
    except Exception:
        return None

def firebase_email_register(email, password, display_name):
    url = f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={FIREBASE_API_KEY}"
    payload = {"email": email, "password": password, "returnSecureToken": True}
    try:
        resp = requests.post(url, json=payload)
        if resp.status_code != 200:
            return resp
        data = resp.json()
        id_token = data["idToken"]
        profile_url = f"https://identitytoolkit.googleapis.com/v1/accounts:updateProfile?key={FIREBASE_API_KEY}"
        profile_payload = {"idToken": id_token, "displayName": display_name, "returnSecureToken": True}
        requests.post(profile_url, json=profile_payload)
        return resp
    except Exception:
        return None

def firebase_guest_login():
    url = f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={FIREBASE_API_KEY}"
    payload = {"returnSecureToken": True}
    try:
        resp = requests.post(url, json=payload)
        return resp
    except Exception:
        return None

def firebase_send_otp(phone_number):
    url = f"https://identitytoolkit.googleapis.com/v1/accounts:sendVerificationCode?key={FIREBASE_API_KEY}"
    payload = {"phoneNumber": phone_number, "recaptchaToken": ""}
    try:
        resp = requests.post(url, json=payload)
        return resp
    except Exception:
        return None

def firebase_verify_otp(session_info, code):
    url = f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPhoneNumber?key={FIREBASE_API_KEY}"
    payload = {"sessionInfo": session_info, "code": code}
    try:
        resp = requests.post(url, json=payload)
        return resp
    except Exception:
        return None

def get_headers():
    return {"Authorization": f"Bearer {st.session_state.access_token}"} if st.session_state.access_token else {}

# --- Dinamik Açık / Koyu Tema CSS Enjeksiyonu ---
THEMES = {
    "Soft Mavi (Varsayılan)": "linear-gradient(to right, #e0eafc, #cfdef3)",
    "Sıcak Bej": "linear-gradient(to right, #fdfbfb, #ebedee)",
    "Mistik Dağlar": "url('https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=1920&q=80')",
    "Sakin Orman": "url('https://images.unsplash.com/photo-1441974231531-c6227db76b6e?auto=format&fit=crop&w=1920&q=80')",
    "Huzurlu Okyanus": "url('https://images.unsplash.com/photo-1505118380757-91f5f5632de0?auto=format&fit=crop&w=1920&q=80')",
    "Yıldızlı Gece": "url('https://images.unsplash.com/photo-1419242902214-272b3f66ee7a?auto=format&fit=crop&w=1920&q=80')"
}

current_bg = st.session_state.bg_image
if st.session_state.dark_mode and current_bg == "linear-gradient(to right, #e0eafc, #cfdef3)":
    current_bg = "linear-gradient(135deg, #0f172a, #1e293b)"
elif not st.session_state.dark_mode and current_bg == "linear-gradient(135deg, #0f172a, #1e293b)":
    current_bg = "linear-gradient(to right, #e0eafc, #cfdef3)"

def get_custom_css(dark_mode, bg_image):
    brightness = "0.3" if dark_mode else "0.95"
    text_color = "#f8fafc" if dark_mode else "#1e293b"
    muted_text = "#94a3b8" if dark_mode else "#64748b"
    input_bg = "rgba(15, 23, 42, 0.6)" if dark_mode else "#ffffff"
    input_text = "#f8fafc" if dark_mode else "#1e293b"
    input_border = "#334155" if dark_mode else "#cbd5e1"
    sidebar_bg = "rgba(15, 23, 42, 0.95)" if dark_mode else "rgba(255, 255, 255, 0.95)"
    sidebar_border = "#1e293b" if dark_mode else "#e5e7eb"
    ai_bubble_bg = "rgba(30, 41, 59, 0.85)" if dark_mode else "#ffffff"
    ai_bubble_text = "#f1f5f9" if dark_mode else "#1f2937"
    ai_bubble_border = "#334155" if dark_mode else "#f3f4f6"
    user_bubble_bg = "#4f46e5" if dark_mode else "#2563eb"
    user_bubble_text = "#ffffff"
    card_bg = "rgba(30, 41, 59, 0.7)" if dark_mode else "rgba(255, 255, 255, 0.9)"
    card_shadow = "0 8px 32px 0 rgba(0, 0, 0, 0.3)" if dark_mode else "0 8px 32px 0 rgba(31, 38, 135, 0.05)"

    return f"""
    <style>
        .stApp {{
            background: transparent !important;
        }}
        
        .stApp::before {{
            content: "";
            position: absolute;
            top: 0; left: 0; width: 100%; height: 100%;
            background: {bg_image};
            background-size: cover;
            background-position: center;
            background-attachment: fixed;
            filter: brightness({brightness}) contrast(1.05);
            z-index: -1;
            transition: filter 0.3s ease;
        }}

        .stMarkdown, .stText, h1, h2, h3, h4, h5, h6, p, li, span, label, div[data-testid="stExpander"] {{ 
            color: {text_color} !important; 
        }}
        
        .stTextInput input, .stTextArea textarea, .stNumberInput input {{ 
            background-color: {input_bg} !important; 
            color: {input_text} !important; 
            border: 1px solid {input_border} !important;
            border-radius: 8px;
        }}
        
        section[data-testid="stSidebar"] {{ 
            background-color: {sidebar_bg} !important; 
            border-right: 1px solid {sidebar_border}; 
        }}
        section[data-testid="stSidebar"] * {{ 
            color: {text_color} !important; 
        }}
        
        .chat-user {{
            background-color: {user_bubble_bg}; 
            color: {user_bubble_text} !important; 
            padding: 14px 20px;
            border-radius: 20px 20px 5px 20px; 
            margin: 10px 0; 
            text-align: right;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1); 
            display: inline-block; 
            font-size: 15px;
            max-width: 80%;
        }}
        .chat-ai {{
            background-color: {ai_bubble_bg}; 
            color: {ai_bubble_text} !important; 
            padding: 14px 20px;
            border-radius: 20px 20px 20px 5px; 
            margin: 10px 0; 
            text-align: left;
            border: 1px solid {ai_bubble_border}; 
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
            display: inline-block; 
            font-size: 15px;
            max-width: 80%;
        }}

        .login-card {{
            background: {card_bg};
            backdrop-filter: blur(12px);
            -webkit-backdrop-filter: blur(12px);
            border-radius: 24px;
            border: 1px solid rgba(255, 255, 255, 0.1);
            box-shadow: {card_shadow};
            padding: 30px;
            margin-top: 40px;
            text-align: center;
        }}

        .crisis-alert {{
            background-color: {"#7f1d1d" if dark_mode else "#fee2e2"}; 
            color: {"#fecaca" if dark_mode else "#991b1b"} !important;
            padding: 20px;
            border-radius: 12px;
            border-left: 8px solid #ef4444;
            font-weight: bold;
            box-shadow: 0 10px 15px -3px rgba(239, 68, 68, 0.2);
            margin: 15px 0;
            font-size: 15px;
        }}
        
        div[data-baseweb="select"] {{
            background-color: {input_bg} !important;
            border-radius: 8px;
        }}
        div[data-baseweb="select"] * {{
            color: {input_text} !important;
        }}
        
        .stButton>button {{
            border-radius: 8px;
        }}
    </style>
    """

st.markdown(get_custom_css(st.session_state.dark_mode, current_bg), unsafe_allow_html=True)

# --- Giriş ve Kayıt Sayfası ---
def login_page():
    col1, col2, col3 = st.columns([1, 2, 1])
    with col2:
        st.markdown("""
        <div class="login-card">
            <h1 style='color:#2563eb; font-size: 3rem; margin-bottom: 0px;'>🧠 Terapi AI</h1>
            <p style='color:#6b7280; font-size: 1rem;'>Güvenli, Gizli ve Empatik Destek Alanınız.</p>
        </div>
        """, unsafe_allow_html=True)
        
        tab1, tab2, tab3, tab4 = st.tabs([
            "🔑 Klasik Giriş", 
            "📧 E-posta Girişi", 
            "📞 Telefon Girişi", 
            "👥 Misafir Girişi"
        ])

        with tab1:
            st.markdown("<div style='height: 10px;'></div>", unsafe_allow_html=True)
            klass_action = st.radio("İşlem Seçin:", ["Giriş Yap", "Kayıt Ol"], horizontal=True, key="klass_action")
            if klass_action == "Giriş Yap":
                username = st.text_input("Kullanıcı Adı", key="login_user")
                password = st.text_input("Şifre", type="password", key="login_pass")
                if st.button("Giriş Yap", type="primary", use_container_width=True, key="btn_classic_login"):
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
            else:
                new_user = st.text_input("Kullanıcı Adı", key="reg_user")
                new_pass = st.text_input("Şifre", type="password", key="reg_pass")
                new_name = st.text_input("Görünen Adın", key="reg_name")
                new_age = st.number_input("Yaşın", min_value=10, max_value=99, step=1, key="reg_age")
                new_gender = st.selectbox("Cinsiyet", ["Belirtilmedi", "Kadın", "Erkek"], key="reg_gender")
                if st.button("Klasik Hesap Oluştur", use_container_width=True, key="btn_classic_reg"):
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
                                st.success("Klasik kayıt başarılı! Giriş Yap seçeneğinden giriş yapabilirsiniz.")
                            else:
                                st.error(f"Kayıt başarısız: {resp.json().get('detail', 'Bilinmeyen hata')}")
                        except Exception as e:
                            st.error(f"Sunucuya ulaşılamıyor: {e}")
                    else:
                        st.warning("Lütfen tüm alanları doldur.")

        with tab2:
            st.markdown("<div style='height: 10px;'></div>", unsafe_allow_html=True)
            email_action = st.radio("İşlem Seçin:", ["Giriş Yap", "Hesap Oluştur"], horizontal=True, key="email_action")
            email = st.text_input("E-posta Adresi", key="fb_email")
            email_pass = st.text_input("Şifre", type="password", key="fb_email_pass")
            if email_action == "Giriş Yap":
                if st.button("Firebase E-posta ile Giriş Yap", type="primary", use_container_width=True, key="btn_fb_email_login"):
                    if email and email_pass:
                        with st.spinner("Giriş yapılıyor..."):
                            resp = firebase_email_login(email, email_pass)
                            if resp and resp.status_code == 200:
                                fb_data = resp.json()
                                payload = {
                                    "uid": fb_data["localId"],
                                    "email": fb_data.get("email"),
                                    "display_name": fb_data.get("displayName") or fb_data.get("email", "").split("@")[0],
                                    "is_guest": False
                                }
                                try:
                                    back_resp = requests.post(f"{API_BASE_URL}/auth/firebase", json=payload)
                                    if back_resp.status_code == 200:
                                        data = back_resp.json()
                                        st.session_state.user = data["user"]
                                        st.session_state.access_token = data["access_token"]
                                        st.session_state.refresh_token = data.get("refresh_token")
                                        st.success(f"Hoş geldin {data['user'].get('display_name', '')}!")
                                        time.sleep(0.5)
                                        st.rerun()
                                    else:
                                        st.error("Backend bağlantı hatası.")
                                except Exception as e:
                                    st.error(f"Backend sunucusuna bağlanılamadı: {e}")
                            else:
                                err_msg = resp.json().get("error", {}).get("message", "Giriş başarısız.") if resp else "Firebase bağlantı hatası."
                                st.error(f"Giriş başarısız: {err_msg}")
                    else:
                        st.warning("Lütfen e-posta ve şifrenizi girin.")
            else:
                email_name = st.text_input("Görünen Adın", key="fb_email_name")
                if st.button("Firebase E-posta ile Kayıt Ol", use_container_width=True, key="btn_fb_email_reg"):
                    if email and email_pass and email_name:
                        with st.spinner("Kayıt oluşturuluyor..."):
                            resp = firebase_email_register(email, email_pass, email_name)
                            if resp and resp.status_code == 200:
                                fb_data = resp.json()
                                payload = {
                                    "uid": fb_data["localId"],
                                    "email": fb_data.get("email"),
                                    "display_name": email_name,
                                    "is_guest": False
                                }
                                try:
                                    back_resp = requests.post(f"{API_BASE_URL}/auth/firebase", json=payload)
                                    if back_resp.status_code == 200:
                                        data = back_resp.json()
                                        st.session_state.user = data["user"]
                                        st.session_state.access_token = data["access_token"]
                                        st.session_state.refresh_token = data.get("refresh_token")
                                        st.success(f"Hesap oluşturuldu ve giriş yapıldı!")
                                        time.sleep(0.5)
                                        st.rerun()
                                    else:
                                        st.error("Backend bağlantı hatası.")
                                except Exception as e:
                                    st.error(f"Backend sunucusuna bağlanılamadı: {e}")
                            else:
                                err_msg = resp.json().get("error", {}).get("message", "Kayıt başarısız.") if resp else "Firebase bağlantı hatası."
                                st.error(f"Kayıt başarısız: {err_msg}")
                    else:
                        st.warning("Lütfen tüm alanları doldurun.")

        with tab3:
            st.markdown("<div style='height: 10px;'></div>", unsafe_allow_html=True)
            st.info("💡 Telefon doğrulaması tarayıcı reCAPTCHA koruması nedeniyle Firebase üzerinde tanımlanmış olan Test Numaraları ile doğrudan çalışır. Gerçek SMS doğrulamaları için mobil uygulamamızı kullanabilirsiniz.")
            phone_number = st.text_input("Telefon Numarası (Örn: +905554443322)", key="fb_phone")
            
            if "otp_sent" not in st.session_state:
                st.session_state.otp_sent = False
            if "otp_session" not in st.session_state:
                st.session_state.otp_session = None

            if not st.session_state.otp_sent:
                if st.button("Doğrulama Kodu Gönder", type="primary", use_container_width=True, key="btn_send_otp"):
                    if phone_number:
                        with st.spinner("Kod gönderiliyor..."):
                            resp = firebase_send_otp(phone_number)
                            if resp and resp.status_code == 200:
                                data = resp.json()
                                st.session_state.otp_session = data.get("sessionInfo")
                                st.session_state.otp_sent = True
                                st.success("Kod gönderildi! (Test numarasının doğrulama kodunu girin).")
                                st.rerun()
                            else:
                                err_msg = resp.json().get("error", {}).get("message", "reCAPTCHA engeline takılmış olabilir veya geçersiz numara.") if resp else "Bağlantı hatası."
                                st.error(f"Kod gönderme hatası: {err_msg}")
                    else:
                        st.warning("Lütfen telefon numarasını girin.")
            else:
                otp_code = st.text_input("SMS Doğrulama Kodu (Örn: 123456)", key="fb_otp")
                
                col_otp1, col_otp2 = st.columns(2)
                with col_otp1:
                    if st.button("Kodu Doğrula ve Giriş", type="primary", use_container_width=True, key="btn_verify_otp"):
                        if otp_code and st.session_state.otp_session:
                            with st.spinner("Doğrulanıyor..."):
                                resp = firebase_verify_otp(st.session_state.otp_session, otp_code)
                                if resp and resp.status_code == 200:
                                    fb_data = resp.json()
                                    payload = {
                                        "uid": fb_data["localId"],
                                        "phone": fb_data.get("phoneNumber"),
                                        "display_name": f"Telefon ({fb_data.get('phoneNumber')})",
                                        "is_guest": False
                                    }
                                    try:
                                        back_resp = requests.post(f"{API_BASE_URL}/auth/firebase", json=payload)
                                        if back_resp.status_code == 200:
                                            data = back_resp.json()
                                            st.session_state.user = data["user"]
                                            st.session_state.access_token = data["access_token"]
                                            st.session_state.refresh_token = data.get("refresh_token")
                                            st.success("Telefon ile giriş başarılı!")
                                            time.sleep(0.5)
                                            st.session_state.otp_sent = False
                                            st.session_state.otp_session = None
                                            st.rerun()
                                        else:
                                            st.error("Backend bağlantı hatası.")
                                    except Exception as e:
                                        st.error(f"Backend sunucusuna bağlanılamadı: {e}")
                                else:
                                    err_msg = resp.json().get("error", {}).get("message", "Geçersiz kod.") if resp else "Bağlantı hatası."
                                    st.error(f"Doğrulama hatası: {err_msg}")
                        else:
                            st.warning("Lütfen doğrulama kodunu girin.")
                with col_otp2:
                    if st.button("İptal Et", use_container_width=True, key="btn_cancel_otp"):
                        st.session_state.otp_sent = False
                        st.session_state.otp_session = None
                        st.rerun()

        with tab4:
            st.markdown("<div style='height: 10px;'></div>", unsafe_allow_html=True)
            st.write("Şifresiz ve anonim olarak tek tıkla misafir girişi yapabilirsiniz. Bu oturum geçicidir.")
            if st.button("Misafir Girişi Yap", type="primary", use_container_width=True, key="btn_fb_guest"):
                with st.spinner("Misafir oturumu açılıyor..."):
                    resp = firebase_guest_login()
                    if resp and resp.status_code == 200:
                        fb_data = resp.json()
                        payload = {
                            "uid": fb_data["localId"],
                            "display_name": "Misafir Kullanıcı",
                            "is_guest": True
                        }
                        try:
                            back_resp = requests.post(f"{API_BASE_URL}/auth/firebase", json=payload)
                            if back_resp.status_code == 200:
                                data = back_resp.json()
                                st.session_state.user = data["user"]
                                st.session_state.access_token = data["access_token"]
                                st.session_state.refresh_token = data.get("refresh_token")
                                st.success("Misafir girişi başarılı!")
                                time.sleep(0.5)
                                st.rerun()
                            else:
                                st.error("Backend bağlantı hatası.")
                        except Exception as e:
                            st.error(f"Backend sunucusuna bağlanılamadı: {e}")
                    else:
                        st.error("Firebase misafir girişi başarısız.")

# --- Sohbet Sayfası ---
def chat_page():
    user = st.session_state.user
    
    with st.sidebar:
        # Tema Butonu
        st.session_state.dark_mode = st.toggle("🌙 Gece Modu (Dark Mode)", value=st.session_state.dark_mode)
        st.divider()

        # Profil Fotoğrafı ve Bilgi
        avatar_img = user.get("avatar", "default")
        if avatar_img and avatar_img.startswith("data:image"):
            st.markdown(f"""
            <div style='text-align:center;padding:15px;background:rgba(128,128,128,0.05);border-radius:15px;margin-bottom:20px; border:1px solid rgba(128,128,128,0.1);'>
                <img src="{avatar_img}" style="width: 80px; height: 80px; border-radius: 50%; object-fit: cover; border: 3px solid #2563eb; box-shadow: 0 4px 10px rgba(0,0,0,0.15);"/>
                <h3 style='margin: 10px 0;'>{user.get("display_name", "")}</h3>
                <p style='font-size: 0.9rem;'>{user.get("gender", "")}, {user.get("age", "")} Yaşında</p>
            </div>
            """, unsafe_allow_html=True)
        else:
            avatar_emoji = '👩' if user.get("gender") == 'Kadın' else '👨' if user.get("gender") == 'Erkek' else '👤'
            st.markdown(f"""
            <div style='text-align:center;padding:15px;background:rgba(128,128,128,0.05);border-radius:15px;margin-bottom:20px; border:1px solid rgba(128,128,128,0.1);'>
                <div style='font-size:45px;'>{avatar_emoji}</div>
                <h3 style='margin: 10px 0;'>{user.get("display_name", "")}</h3>
                <p style='font-size: 0.9rem;'>{user.get("gender", "")}, {user.get("age", "")} Yaşında</p>
            </div>
            """, unsafe_allow_html=True)
        
        # Profil Ayarları
        with st.expander("⚙️ Profil Ayarları"):
            uploaded_file = st.file_uploader("Profil Resmi Seç (JPEG/PNG):", type=["png", "jpg", "jpeg"])
            avatar_data = user.get("avatar", "default")
            if uploaded_file is not None:
                try:
                    img = Image.open(uploaded_file)
                    img.thumbnail((200, 200))
                    buffer = io.BytesIO()
                    img.convert("RGB").save(buffer, format="JPEG", quality=80)
                    compressed_bytes = buffer.getvalue()
                    base64_str = base64.b64encode(compressed_bytes).decode("utf-8")
                    avatar_data = f"data:image/jpeg;base64,{base64_str}"
                    st.success("Profil resmi sıkıştırıldı! Güncelle dediğinizde kaydedilecek.")
                except Exception as e:
                    st.error(f"Görsel işleme hatası: {e}")

            col_p1, col_p2 = st.columns(2)
            with col_p1:
                new_name = st.text_input("Görünen Ad", value=user.get("display_name", ""))
                new_age = st.number_input("Yaş", min_value=10, max_value=99, value=int(user.get("age", 25)))
                
                options = ["Belirtilmedi", "Kadın", "Erkek"]
                try:
                    current_idx = options.index(user.get("gender", "Belirtilmedi"))
                except ValueError:
                    current_idx = 0
                new_gender = st.selectbox("Cinsiyet", options, index=current_idx)
                new_city = st.text_input("Şehir", value=user.get("city", ""))
                
            with col_p2:
                new_profession = st.text_input("Meslek", value=user.get("profession", ""))
                new_marital_status = st.text_input("Medeni Durum", value=user.get("marital_status", "Belirtilmedi"))
                new_child_count = st.number_input("Çocuk Sayısı", min_value=0, max_value=20, value=int(user.get("child_count", 0)), step=1)
                new_chronic_illness = st.text_input("Kronik Rahatsızlık", value=user.get("chronic_illness", ""))
                
            new_trauma_summary = st.text_area("Önemli Travmalar / Geçmiş Detayları", value=user.get("trauma_summary", ""))
            
            if st.button("Profilimi Güncelle", use_container_width=True):
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
                        "avatar": avatar_data
                    }
                    resp = requests.put(f"{API_BASE_URL}/users/{user['id']}/profile", json=payload, headers=get_headers())
                    if resp.status_code == 200:
                        st.session_state.user = resp.json()["user"]
                        st.success("Profil güncellendi!")
                        time.sleep(0.5)
                        st.rerun()
                    else:
                        st.error(f"Hata: {resp.json().get('detail')}")
                except Exception as e:
                    st.error(f"Bağlantı hatası: {e}")

        # Terapist Ses Ayarı
        with st.expander("🎤 Ses & Terapist Seçimi"):
            voices = {
                "Kadın Terapist (Sarah/Filiz)": "EXAVITQu4vr4xnSDxMaL",
                "Erkek Terapist (Brian)": "nPczCjzI2devNBz1zQrb"
            }
            voice_names = list(voices.keys())
            current_voice_id = st.session_state.selected_voice_id
            try:
                selected_voice_idx = [voices[k] for k in voice_names].index(current_voice_id)
            except ValueError:
                selected_voice_idx = 0
                
            selected_voice_name = st.selectbox("Terapist Sesi:", voice_names, index=selected_voice_idx, key="voice_select_sb")
            st.session_state.selected_voice_id = voices[selected_voice_name]
            
            st.session_state.tts_enabled = st.checkbox("Yanıtları Sesli Oku (TTS)", value=st.session_state.tts_enabled, key="cb_tts_enabled")

        # Atmosfer Seçimi
        with st.expander("🎨 Görünüm & Atmosfer"):
            selected_theme_name = st.selectbox("Bir Atmosfer Seç:", list(THEMES.keys()))
            if st.button("Atmosferi Uygula"):
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
        except Exception:
            st.error("Oturumlar yüklenemedi.")

        st.divider()
        st.subheader("🎤 Sesli Mesaj")
        audio_val = st.audio_input("Ses kaydedin")
        if audio_val and st.button("Gönder", use_container_width=True, type="primary", key="btn_send_audio"):
            st.session_state.pending_audio = audio_val
            st.rerun()

        st.divider()
        if st.button("Çıkış Yap", use_container_width=True, key="btn_logout"):
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

    # --- Sohbet Paneli ---
    st.markdown(f"""
    <div style='text-align: center; margin-bottom: 30px;'>
        <h2 style='margin-bottom: 5px;'>Merhaba {user.get("display_name", "")}, seni dinliyorum.</h2>
        <p style='font-size: 0.95rem; opacity: 0.85;'>Bugün zihninden neler geçiyor?</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Sohbet Geçmişi Gösterimi
    for msg in st.session_state.messages:
        role = msg.get("role", "")
        content = msg.get("content", "")
        if role == "user":
            st.markdown(f"<div style='display:flex;justify-content:flex-end;'><div class='chat-user'>{content}</div></div>", unsafe_allow_html=True)
        else:
            st.markdown(f"<div style='display:flex;justify-content:flex-start;'><div style='margin-right:12px; font-size:28px; padding-top:10px;'>🧠</div><div class='chat-ai'>{content}</div></div>", unsafe_allow_html=True)

    # Girdi Alanı
    if prompt := st.chat_input("Buraya yaz..."):
        st.session_state.messages.append({"role": "user", "content": prompt})
        st.rerun()

    # Sesli Mesaj İşlemesi
    if getattr(st.session_state, "pending_audio", None) is not None:
        audio_data = st.session_state.pending_audio
        st.session_state.pending_audio = None
        with st.spinner("Sesiniz işleniyor..."):
            try:
                files = {"audio_file": ("audio.wav", audio_data, "audio/wav")}
                data = {
                    "user_name": user.get("display_name", ""),
                    "age": user.get("age", 0),
                    "gender": user.get("gender", "Belirtilmedi"),
                    "session_id": st.session_state.current_session_id or "",
                    "voice_id": st.session_state.selected_voice_id,
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
                        st.session_state.audio_to_play = base64.b64decode(audio_base64)
                        
                    st.rerun()
                else:
                    st.error(f"Ses işleme hatası: {response.status_code} - {response.text}")
            except Exception as e:
                st.error(f"Bağlantı Hatası: {e}")

    # Yazılı Mesaj İşlemesi (AI Cevap Üretme)
    if st.session_state.messages and st.session_state.messages[-1]["role"] == "user":
        # Sadece son mesaj modelden değilse çalış
        if len(st.session_state.messages) == 1 or st.session_state.messages[-2]["role"] != "user":
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

                        st.session_state.messages.append({"role": "model", "content": reply})

                        # Yazılı Mesaj Sonrası Otomatik TTS
                        if st.session_state.tts_enabled:
                            el_key = os.getenv("ELEVENLABS_API_KEY", "")
                            if el_key:
                                try:
                                    voice_url = f"https://api.elevenlabs.io/v1/text-to-speech/{st.session_state.selected_voice_id}"
                                    headers = {
                                        "xi-api-key": el_key,
                                        "Content-Type": "application/json",
                                        "Accept": "audio/mpeg"
                                    }
                                    tts_payload = {
                                        "text": reply,
                                        "model_id": "eleven_multilingual_v2",
                                        "voice_settings": {"stability": 0.45, "similarity_boost": 0.75}
                                    }
                                    tts_resp = requests.post(voice_url, json=tts_payload, headers=headers)
                                    if tts_resp.status_code == 200:
                                        st.session_state.audio_to_play = tts_resp.content
                                    elif tts_resp.status_code in [400, 402]:
                                        # Fallback to Sarah
                                        fallback_url = "https://api.elevenlabs.io/v1/text-to-speech/EXAVITQu4vr4xnSDxMaL"
                                        tts_resp = requests.post(fallback_url, json=tts_payload, headers=headers)
                                        if tts_resp.status_code == 200:
                                            st.session_state.audio_to_play = tts_resp.content
                                except Exception:
                                    pass

                        st.rerun()
                    else:
                        st.error(f"Sunucu Hatası: {response.status_code} - {response.text}")
                except Exception as e:
                    st.error(f"Bağlantı Hatası: {e}")

    # Otomatik Ses Çalma (TTS veya Ses Kaydı Yanıtı)
    if st.session_state.audio_to_play is not None:
        play_data = st.session_state.audio_to_play
        st.session_state.audio_to_play = None
        st.audio(play_data, format='audio/mpeg', autoplay=True)

# --- Sayfa Seçici Yönlendirme ---
if st.session_state.user:
    chat_page()
else:
    login_page()