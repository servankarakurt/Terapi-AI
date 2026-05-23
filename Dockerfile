FROM python:3.11-slim

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user with UID 1000 (Required by Hugging Face)
RUN useradd -m -u 1000 user
USER user
ENV PATH="/home/user/.local/bin:$PATH"

WORKDIR /app

# Copy requirements and install dependencies as 'user'
COPY --chown=user requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Copy the rest of the application files, making sure they are owned by 'user'
COPY --chown=user app/ ./app/
COPY --chown=user data/ ./data/
COPY --chown=user notebooks/ ./notebooks/
COPY --chown=user scripts/ ./scripts/
COPY --chown=user tools/ ./tools/

# Set environment variables
ENV PORT=7860
ENV DB_NAME=/app/psychbot.db

EXPOSE 7860

# Run FastAPI backend on port 7860
CMD ["sh", "-c", "python -m uvicorn app.api:app --host 0.0.0.0 --port ${PORT}"]
