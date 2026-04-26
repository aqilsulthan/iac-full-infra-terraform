#!/bin/bash
# ============================================================
# Bootstrap Script — Terraform IaC Portfolio Project
#
# Installs Python Flask web application behind Nginx reverse
# proxy, configures CloudWatch Agent for log shipping, and
# performs RDS connectivity validation.
# ============================================================
set -euo pipefail

# ---- Configuration ----
APP_NAME="__APP_NAME__"
APP_DIR="/opt/app"
LOG_FILE="/var/log/app-bootstrap.log"
CW_AGENT_CONFIG="/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json"
DEFAULT_REGION="__AWS_REGION__"
DEFAULT_DB_HOST="__DB_HOST__"
DEFAULT_DB_NAME="__DB_NAME__"
DEFAULT_DB_SECRET_NAME="__DB_SECRET_NAME__"
DEFAULT_PROJECT_NAME="__PROJECT_NAME__"
DEFAULT_ENVIRONMENT="__ENVIRONMENT__"
APP_SOURCE_URL="https://raw.githubusercontent.com/aqilsulthan/iac-full-infra-terraform/main/scripts/app.py"

# ---- Logging Function ----
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
    logger -t "bootstrap" "[${level}] ${message}"
}

info()  { log "INFO" "$1"; }
warn()  { log "WARN" "$1"; }
error() { log "ERROR" "$1"; }

# ---- Helper Functions ----

get_instance_metadata() {
    local path="$1"
    local token
    token="$(curl -s -f -X PUT "http://169.254.169.254/latest/api/token" \
        -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null || true)"
    if [ -n "$token" ]; then
        curl -s -f -H "X-aws-ec2-metadata-token: ${token}" \
            "http://169.254.169.254/latest/meta-data/${path}" 2>/dev/null || echo "unknown"
    else
        curl -s -f "http://169.254.169.254/latest/meta-data/${path}" 2>/dev/null || echo "unknown"
    fi
}

get_aws_region() {
    local az
    az="$(get_instance_metadata placement/availability-zone)"
    if [ "$az" != "unknown" ]; then
        echo "${az%?}"
    else
        echo "${DEFAULT_REGION}"
    fi
}

# ---- Phase 1: System Dependencies ----
install_dependencies() {
    info "Phase 1: Installing system dependencies..."
    apt-get update -y
    apt-get install -y \
        python3 python3-pip python3-venv nginx default-mysql-client \
        curl jq awscli
    info "System dependencies installed successfully"
}

# ---- Phase 2: Python Application ----
setup_app() {
    info "Phase 2: Setting up Python Flask application..."
    mkdir -p "${APP_DIR}"
    cd "${APP_DIR}"

    python3 -m venv venv
    source venv/bin/activate
    pip install --no-cache-dir flask gunicorn pymysql 2>&1 | tee -a "${LOG_FILE}"

    info "Downloading Flask application from GitHub..."
    if curl -sfL -o "${APP_DIR}/app.py" "${APP_SOURCE_URL}" 2>&1 | tee -a "${LOG_FILE}"; then
        info "Flask application downloaded from ${APP_SOURCE_URL}"
    else
        warn "GitHub download failed, creating fallback Flask application..."
        cat > "${APP_DIR}/app.py" << 'PYAPP'
import os
import json
import socket
import subprocess
from datetime import datetime
from flask import Flask, jsonify

app = Flask(__name__)

def meta(path):
    try:
        token = subprocess.check_output(
            [
                "/usr/bin/curl", "-s", "-f", "-X", "PUT",
                "http://169.254.169.254/latest/api/token",
                "-H", "X-aws-ec2-metadata-token-ttl-seconds: 21600",
            ],
            timeout=2,
            text=True,
        ).strip()
        return subprocess.check_output(
            [
                "/usr/bin/curl", "-s", "-f",
                "-H", f"X-aws-ec2-metadata-token: {token}",
                f"http://169.254.169.254/latest/meta-data/{path}",
            ],
            timeout=2,
            text=True,
        ).strip() or "unknown"
    except Exception:
        pass
    try:
        return subprocess.check_output(
            ["/usr/bin/curl", "-s", "-f", f"http://169.254.169.254/latest/meta-data/{path}"],
            timeout=2,
            text=True,
        ).strip() or "unknown"
    except Exception:
        return "unknown"

INSTANCE_ID = meta("instance-id")
AZ = meta("placement/availability-zone")
REGION = os.environ.get("AWS_REGION") or (AZ[:-1] if AZ != "unknown" else "unknown")
DB_HOST = os.environ.get("DB_HOST", "")
DB_NAME = os.environ.get("DB_NAME", "appdb")
APP_NAME = os.environ.get("APP_NAME", "Terraform App")

def db_status():
    if not DB_HOST:
        return {"connected": False, "host": "", "error": "DB_HOST is empty"}
    try:
        secret_name = os.environ.get("DB_SECRET_NAME", "dev-db-credentials")
        raw_secret = subprocess.check_output(
            [
                "/usr/bin/aws", "secretsmanager", "get-secret-value",
                "--secret-id", secret_name,
                "--query", "SecretString",
                "--output", "text",
                "--region", REGION,
            ],
            timeout=10,
            text=True,
        )
        creds = json.loads(raw_secret)
        import pymysql
        conn = pymysql.connect(
            host=DB_HOST,
            user=creds["username"],
            password=creds["password"],
            database=DB_NAME,
            connect_timeout=5,
        )
        conn.close()
        return {"connected": True, "host": DB_HOST, "error": ""}
    except Exception as exc:
        return {"connected": False, "host": DB_HOST, "error": str(exc)}

@app.route('/')
def index():
    db = db_status()
    return (
        f"<h1>{APP_NAME}</h1>"
        f"<p>Status: running</p>"
        f"<p>Instance: {INSTANCE_ID}</p>"
        f"<p>AZ: {AZ}</p>"
        f"<p>DB: {'connected' if db['connected'] else 'not connected'}</p>"
        f"<p>DB Host: {db['host']}</p>"
    )

@app.route('/health')
def health():
    return jsonify({
        "status": "healthy",
        "instance": INSTANCE_ID,
        "az": AZ,
        "region": REGION,
        "timestamp": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
    }), 200

@app.route('/api/info')
def info():
    return jsonify({
        "app": APP_NAME,
        "instance": INSTANCE_ID,
        "hostname": socket.gethostname(),
        "az": AZ,
        "region": REGION,
        "db": db_status(),
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
PYAPP
        info "Fallback Flask application created"
    fi

    # Fix ownership so www-data can run the app
    chown -R www-data:www-data "${APP_DIR}"
}

# ---- Phase 3: Gunicorn Systemd Service ----
setup_systemd() {
    info "Phase 3: Configuring Gunicorn systemd service..."
    local region
    region="$(get_aws_region)"
    local db_host
    db_host="${DEFAULT_DB_HOST}"

    cat > /etc/systemd/system/app.service << SERVICEEOF
[Unit]
Description=Terraform App (Gunicorn)
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/app
Environment=PATH=/opt/app/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=APP_NAME="${APP_NAME}"
Environment=AWS_REGION="${region}"
Environment=DB_HOST="${db_host}"
Environment=DB_NAME="${DEFAULT_DB_NAME}"
Environment=DB_SECRET_NAME="${DEFAULT_DB_SECRET_NAME}"
Environment=PROJECT_NAME="${DEFAULT_PROJECT_NAME}"
Environment=ENVIRONMENT="${DEFAULT_ENVIRONMENT}"
ExecStart=/opt/app/venv/bin/gunicorn --workers 2 --bind 127.0.0.1:5000 app:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICEEOF
    systemctl daemon-reload
    systemctl enable app
    systemctl start app
    info "Gunicorn service started successfully"
}

# ---- Phase 4: Nginx Reverse Proxy ----
configure_nginx() {
    info "Phase 4: Configuring Nginx reverse proxy..."
    rm -f /etc/nginx/sites-enabled/default
    cat > /etc/nginx/sites-available/app << 'NGINXEOF'
server {
    listen 80 default_server;
    server_name _;
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    location /nginx-health {
        access_log off;
        add_header Content-Type text/plain;
        return 200 "nginx-healthy\n";
    }
}
NGINXEOF
    ln -sf /etc/nginx/sites-available/app /etc/nginx/sites-enabled/
    nginx -t && systemctl restart nginx
    info "Nginx configured as reverse proxy"
}

# ---- Phase 5: CloudWatch Agent ----
setup_cloudwatch() {
    info "Phase 5: Installing CloudWatch Agent..."
    local cw_url="https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb"
    local cw_deb="/tmp/amazon-cloudwatch-agent.deb"
    if curl -sf -o "${cw_deb}" "${cw_url}" 2>&1 | tee -a "${LOG_FILE}"; then
        dpkg -i -E "${cw_deb}" 2>&1 | tee -a "${LOG_FILE}" || warn "CloudWatch Agent package install failed (non-fatal)"
    else
        warn "CloudWatch Agent download failed (non-fatal)"
    fi
    mkdir -p "$(dirname "${CW_AGENT_CONFIG}")"
    cat > "${CW_AGENT_CONFIG}" << 'CWEOF'
{
    "agent": { "metrics_collection_interval": 60, "run_as_user": "root" },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    { "file_path": "/var/log/app-bootstrap.log", "log_group_name": "app-bootstrap", "log_stream_name": "{instance_id}", "timestamp_format": "%Y-%m-%dT%H:%M:%SZ", "retention_in_days": 7 },
                    { "file_path": "/var/log/nginx/access.log", "log_group_name": "nginx-access", "log_stream_name": "{instance_id}", "timestamp_format": "%d/%b/%Y:%H:%M:%S %z", "retention_in_days": 7 },
                    { "file_path": "/var/log/nginx/error.log", "log_group_name": "nginx-error", "log_stream_name": "{instance_id}", "timestamp_format": "%d/%b/%Y:%H:%M:%S %z", "retention_in_days": 7 }
                ]
            }
        }
    },
    "metrics": {
        "namespace": "TerraformApp",
        "metrics_collected": {
            "cpu": { "measurement": ["cpu_usage_idle", "cpu_usage_user", "cpu_usage_system"], "metrics_collection_interval": 60 },
            "mem": { "measurement": ["mem_used_percent"], "metrics_collection_interval": 60 },
            "disk": { "measurement": ["used_percent"], "resources": ["*"], "metrics_collection_interval": 60 }
        }
    }
}
CWEOF
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
        -a fetch-config -m ec2 -c file:"${CW_AGENT_CONFIG}" -s \
        2>&1 | tee -a "${LOG_FILE}" || warn "CloudWatch Agent config failed (non-fatal)"
    info "CloudWatch Agent configured"
}

# ---- Phase 6: Log Rotation ----
setup_logrotate() {
    info "Phase 6: Configuring log rotation..."
    cat > /etc/logrotate.d/app-bootstrap << 'LOGREOF'
/var/log/app-bootstrap.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
LOGREOF
    info "Log rotation configured"
}

# ---- Main Execution ----
main() {
    info "========================================"
    info " Bootstrap Script Started"
    info " App: ${APP_NAME}"
    info " Region: $(get_aws_region)"
    info " Instance: $(get_instance_metadata instance-id)"
    info "========================================"
    install_dependencies
    setup_app
    setup_systemd
    configure_nginx
    setup_cloudwatch
    setup_logrotate
    info "========================================"
    info " Bootstrap Script Completed Successfully"
    info " App URL: http://$(get_instance_metadata local-ipv4)/"
    info " Health:  http://$(get_instance_metadata local-ipv4)/health"
    info "========================================"
}

# Run main
main
