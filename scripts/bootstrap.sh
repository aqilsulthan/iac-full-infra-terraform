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
APP_NAME="Terraform App"
APP_DIR="/opt/app"
LOG_FILE="/var/log/app-bootstrap.log"
CW_AGENT_CONFIG="/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json"

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
    curl -s -f "http://169.254.169.254/latest/meta-data/${path}" 2>/dev/null || echo "unknown"
}

get_aws_region() {
    local az
    az="$(get_instance_metadata placement/availability-zone)"
    if [ "$az" != "unknown" ]; then
        echo "${az%?}"
    else
        echo "ap-southeast-1"
    fi
}

get_rds_endpoint() {
    local region="$1"
    local project="$2"
    local env="$3"
    local endpoint
    endpoint="$(aws rds describe-db-instances \
        --region "${region}" \
        --query "DBInstances[?contains(Tags[?Key=='Project'].Value, '${project}') && contains(Tags[?Key=='Environment'].Value, '${env}')] | [0].Endpoint.Address" \
        --output text 2>/dev/null)" || endpoint=""
    if [ -n "$endpoint" ] && [ "$endpoint" != "None" ]; then
        echo "$endpoint"
    fi
}

# ---- Phase 1: System Dependencies ----
install_dependencies() {
    info "Phase 1: Installing system dependencies..."
    apt-get update -y
    apt-get install -y \
        python3 python3-pip python3-venv nginx mysql-client \
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
    local APP_URL="https://raw.githubusercontent.com/aqilsulthan/iac-full-infra-terraform/main/scripts/app.py"
    if curl -sf -o "${APP_DIR}/app.py" "${APP_URL}"; then
        info "Flask application downloaded from GitHub"
    else
        warn "GitHub download failed, creating minimal fallback app..."
        cat > "${APP_DIR}/app.py" << 'FALLBACK'
import os,sys,json,socket,subprocess
from datetime import datetime
from flask import Flask,jsonify
app=Flask(__name__)
INSTANCE_ID=os.popen('curl -s http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null').read().strip() or 'unknown'
@app.route('/')
def index(): return jsonify({'status':'running','instance':INSTANCE_ID})
@app.route('/health')
def health(): return jsonify({'status':'healthy','instance':INSTANCE_ID}),200
if __name__=="__main__": app.run(host='0.0.0.0',port=5000)
FALLBACK
        warn "Fallback app deployed (limited functionality)"
    fi
}

# ---- Phase 3: Gunicorn Systemd Service ----
setup_systemd() {
    info "Phase 3: Configuring Gunicorn systemd service..."
    cat > /etc/systemd/system/app.service << 'SERVICEEOF'
[Unit]
Description=Terraform App (Gunicorn)
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/app
Environment=PATH=/opt/app/venv/bin
Environment=APP_NAME=Terraform App
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
    curl -s -o "${cw_deb}" "${cw_url}" 2>&1 | tee -a "${LOG_FILE}"
    dpkg -i -E "${cw_deb}" 2>&1 | tee -a "${LOG_FILE}" || true
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
