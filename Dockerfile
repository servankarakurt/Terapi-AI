FROM python:3.11-slim

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Copy requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Create necessary directories
RUN mkdir -p data/vector_store data/chunks /data

# Copy codebase
COPY app/ ./app/
COPY data/ ./data/
COPY notebooks/ ./notebooks/
COPY scripts/ ./scripts/
COPY tools/ ./tools/

# Set environment variables
ENV PORT=7860
ENV DB_NAME=/data/psychbot.db

EXPOSE 7860

# Run FastAPI backend on port 7860
CMD ["sh", "-c", "uvicorn app.api:app --host 0.0.0.0 --port ${PORT}"]
