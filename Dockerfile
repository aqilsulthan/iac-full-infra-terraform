# ============================================================
# Dockerfile — Terraform IaC Flask Application
#
# Multi-stage build:
#   - Stage 1: Install dependencies
#   - Stage 2: Production runtime with Gunicorn
# ============================================================

# ---------- Stage 1: Builder ----------
FROM python:3.10-slim AS builder

LABEL maintainer="iac-full-infra"
LABEL description="Flask application for Terraform IaC portfolio project"

# Prevent Python from writing .pyc files and enable stdout/stderr logging
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /opt/app

# Install system dependencies needed for building Python packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gcc \
        default-libmysqlclient-dev \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy and install Python dependencies first (leverage Docker cache)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ---------- Stage 2: Runtime ----------
FROM python:3.10-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_NAME="iac-full-infra" \
    PYTHONPATH="/opt/app"

WORKDIR /opt/app

# Install only runtime system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        default-mysql-client \
    && rm -rf /var/lib/apt/lists/*

# Copy installed packages from builder stage
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy application code
COPY scripts/app.py .

# Create a non-root user for security
RUN groupadd -r appuser && useradd -r -g appuser -m -d /home/appuser -s /sbin/nologin appuser && \
    chown -R appuser:appuser /opt/app

USER appuser

# Health check — verify the app is responding
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -sf http://localhost:5000/health || exit 1

# Expose the application port
EXPOSE 5000

# Run Gunicorn as the entrypoint
# Workers = 2 * CPU cores + 1 (default: 2 for small instances)
CMD ["gunicorn", "--workers", "2", "--bind", "0.0.0.0:5000", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
