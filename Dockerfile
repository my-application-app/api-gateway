# Multi-stage build optimized for Docker best practices
FROM python:3.11-slim as builder

# Set build-time environment variables and install dependencies in single layer
ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1

# Install build dependencies, copy requirements, and install Python packages
WORKDIR /app
COPY requirements.txt . 
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc && \
    pip install --user --no-cache-dir -r requirements.txt && \
    find /root/.local -name "*.pyc" -delete && \
    find /root/.local -name "__pycache__" -type d -exec rm -rf {} + || true && \
    apt-get purge -y gcc && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Production stage
FROM python:3.11-slim as production

# Set runtime environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/home/appuser/.local/bin:$PATH"

# Create user and setup directories
RUN groupadd -r appuser && \
    useradd -r -g appuser appuser && \
    mkdir -p /app /home/appuser && \
    chown -R appuser:appuser /app /home/appuser

# Copy dependencies from builder stage
COPY --from=builder --chown=appuser:appuser /root/.local /home/appuser/.local

# Copy application code
COPY --chown=appuser:appuser main.py /app/

# Switch to non-root user, set working directory, and expose port
USER appuser
WORKDIR /app
EXPOSE 8000

# Use exec form for better signal handling
CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
