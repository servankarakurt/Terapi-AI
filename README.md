---
title: Terapi AI Backend
emoji: 🧠
colorFrom: blue
colorTo: indigo
sdk: docker
app_port: 7860
pinned: false
---

# Terapi AI - BDT Psikoloji Asistanı Backend Sunucusu

Bu depo, Bilişsel Davranışçı Terapi (BDT) uzmanı empatik psikoloji chatbot asistanımızın FastAPI backend sunucusudur.

## Hugging Face Spaces Dağıtımı

Bu Space, Docker SDK kullanılarak `Dockerfile` aracılığıyla derlenir ve port `7860` üzerinden sunulur.

### Çevre Değişkenleri (Secrets)

Uygulamanın çalışması için aşağıdaki Secret'ların Space ayarlarına eklenmesi gerekmektedir:
- `DATABASE_URL` (Supabase PostgreSQL Bağlantı Adresi)
- `GEMINI_API_KEY`
- `GROQ_API_KEY`
- `ELEVENLABS_API_KEY`
- `ELEVENLABS_VOICE_ID`
- `JWT_SECRET_KEY`
