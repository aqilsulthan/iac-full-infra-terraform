import os
import json
import socket
import shutil
import subprocess
from datetime import datetime
from flask import Flask, jsonify, render_template_string

app = Flask(__name__)

# ---- Environment Detection ----
def is_running_in_container():
    """Detect if we are running inside a Docker container."""
    if os.path.exists("/.dockerenv"):
        return True
    try:
        with open("/proc/1/cgroup") as f:
            return "docker" in f.read() or "kubepods" in f.read()
    except Exception:
        return False

IN_CONTAINER = is_running_in_container()

# ---- Container Info ----
def get_container_id():
    """Get container ID from hostname or cgroup."""
    hostname = socket.gethostname()
    # Docker container IDs are usually 12-char hex strings
    if len(hostname) == 12 and all(c in "0123456789abcdef" for c in hostname):
        return hostname
    return hostname

# ---- EC2 Metadata (with fallbacks) ----
def get_meta(path):
    curl = shutil.which("curl") or "/usr/bin/curl"
    try:
        token = subprocess.check_output(
            [
                curl, "-s", "-f", "-X", "PUT",
                "http://169.254.169.254/latest/api/token",
                "-H", "X-aws-ec2-metadata-token-ttl-seconds: 21600",
            ],
            text=True,
            timeout=2,
        ).strip()
        return subprocess.check_output(
            [
                curl, "-s", "-f",
                "-H", f"X-aws-ec2-metadata-token: {token}",
                f"http://169.254.169.254/latest/meta-data/{path}",
            ],
            text=True,
            timeout=2,
        ).strip() or "unknown"
    except Exception:
        pass

    try:
        import urllib.request
        req = urllib.request.Request(f"http://169.254.169.254/latest/meta-data/{path}", method="GET")
        with urllib.request.urlopen(req, timeout=2) as resp:
            return resp.read().decode("utf-8").strip()
    except Exception:
        return "unknown"

INSTANCE_ID   = get_meta("instance-id")
AZ            = get_meta("placement/availability-zone")
REGION        = os.environ.get("AWS_REGION") or (AZ[:-1] if AZ != "unknown" else "unknown")
INSTANCE_TYPE = get_meta("instance-type")
PRIVATE_IP    = get_meta("local-ipv4")

# ---- Bootstrap / Startup Logs ----
def get_bootstrap_logs(lines=20):
    """Read bootstrap logs (EC2) or container startup info."""
    log_path = "/var/log/app-bootstrap.log"
    if IN_CONTAINER:
        return get_container_startup_info()
    try:
        result = subprocess.run(
            ["tail", "-" + str(lines), log_path],
            capture_output=True, text=True, timeout=5
        )
        return result.stdout if result.returncode == 0 else "Log unavailable"
    except Exception:
        return "Log unavailable"

def get_container_startup_info():
    """Show container-relevant startup information."""
    info_lines = []
    info_lines.append(f"Container ID : {get_container_id()}")
    info_lines.append(f"Hostname     : {socket.gethostname()}")
    info_lines.append(f"Platform     : Docker / Container")
    info_lines.append(f"Python       : {os.sys.version.split()[0]}")
    info_lines.append(f"App started  : {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}")
    info_lines.append(f"Environment  : {os.environ.get('ENVIRONMENT', 'N/A')}")
    info_lines.append(f"Project      : {os.environ.get('PROJECT_NAME', 'N/A')}")
    info_lines.append("---")
    # Try to show env vars relevant to this app
    for key in sorted(os.environ.keys()):
        if key.startswith(("APP_", "DB_", "AWS_", "PROJECT_", "ENVIRONMENT")):
            val = os.environ[key]
            if "SECRET" in key or "PASSWORD" in key or "PASS" in key:
                val = "****"
            info_lines.append(f"{key}={val}")
    return "\n".join(info_lines)

def get_db_status():
    """Try reading DB credentials from Secrets Manager and connecting to RDS."""
    status = {"connected": False, "host": "", "error": "", "db_name": ""}
    try:
        aws = shutil.which("aws") or "/usr/bin/aws"

        # Try to get the secret
        secret_name = os.environ.get("DB_SECRET_NAME", "dev-db-credentials")
        result = subprocess.run(
            [aws, "secretsmanager", "get-secret-value",
             "--secret-id", secret_name,
             "--query", "SecretString",
             "--output", "text",
             "--region", REGION],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode != 0:
            status["error"] = f"Cannot access Secrets Manager: {result.stderr.strip()}"
            return status
        
        creds = json.loads(result.stdout.strip())
        username = creds.get("username", "")
        password = creds.get("password", "")
        db_host = os.environ.get("DB_HOST", "")

        if not db_host:
            # Fallback discovery via AWS CLI if Terraform did not inject DB_HOST.
            project = os.environ.get("PROJECT_NAME", "iac-full-infra")
            env = os.environ.get("ENVIRONMENT", "dev")

            rds_result = subprocess.run(
                [aws, "rds", "describe-db-instances",
                 "--region", REGION,
                 "--query", (
                     'DBInstances[?contains(Tags[?Key==`Project`].Value,`{}`) '
                     '&& contains(Tags[?Key==`Environment`].Value,`{}`)]'
                     ' | [0].Endpoint.Address'
                 ).format(project, env),
                 "--output", "text"],
                capture_output=True, text=True, timeout=10
            )

            if rds_result.returncode != 0 or not rds_result.stdout.strip() or rds_result.stdout.strip() == "None":
                status["error"] = "RDS endpoint not found"
                return status

            db_host = rds_result.stdout.strip()

        status["host"] = db_host
        status["db_name"] = os.environ.get("DB_NAME") or creds.get("db_name", "appdb")
        
        # Try MySQL connection
        try:
            import pymysql
            conn = pymysql.connect(
                host=db_host,
                user=username,
                password=password,
                database=status["db_name"],
                connect_timeout=5
            )
            conn.close()
            status["connected"] = True
            status["error"] = ""
        except Exception as e:
            status["error"] = f"MySQL connection failed: {str(e)}"
    except Exception as e:
        status["error"] = f"Unexpected error: {str(e)}"
    
    return status

DB_STATUS = get_db_status()

# ---- Routes ----

@app.route("/")
def index():
    try:
        cpu = subprocess.run(["top", "-bn1"], capture_output=True, text=True, timeout=5)
        cpu_line = [l for l in cpu.stdout.split("\n") if "Cpu(s)" in l]
        cpu_usage = cpu_line[0].split()[1] if cpu_line else "N/A"
        
        mem = subprocess.run(["free", "-m"], capture_output=True, text=True, timeout=5)
        mem_used = ""
        for line in mem.stdout.split("\n"):
            if line.startswith("Mem:"):
                parts = line.split()
                mem_used = f"{parts[2]}MB / {parts[1]}MB"
        
        disk = subprocess.run(["df", "-h", "/"], capture_output=True, text=True, timeout=5)
        disk_line = disk.stdout.split("\n")[1] if len(disk.stdout.split("\n")) > 1 else ""
        disk_parts = disk_line.split()
        disk_usage = disk_parts[4] if len(disk_parts) >= 5 else "N/A"
        disk_total = disk_parts[1] if len(disk_parts) >= 2 else "N/A"
        
        uptime_result = subprocess.run(["uptime", "-p"], capture_output=True, text=True, timeout=5)
        uptime_str = uptime_result.stdout.strip().replace("up ", "") if uptime_result.returncode == 0 else "N/A"
        
        load_result = subprocess.run(["uptime"], capture_output=True, text=True, timeout=5)
        load_str = load_result.stdout.split("load average:")[1].strip() if "load average:" in load_result.stdout else "N/A"
    except Exception:
        cpu_usage = mem_used = disk_usage = disk_total = uptime_str = load_str = "N/A"

    return render_template_string("""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ app_name }} — System Dashboard</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', sans-serif;
            background: #f0f2f5; color: #1a1a2e; line-height: 1.6;
        }
        .container { max-width: 960px; margin: 0 auto; padding: 30px 20px; }
        .header {
            background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
            color: white; padding: 30px; border-radius: 12px; margin-bottom: 24px;
        }
        .header h1 { font-size: 1.8em; margin-bottom: 8px; }
        .header p { opacity: 0.85; font-size: 0.95em; }
        .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
        @media (max-width: 640px) { .grid { grid-template-columns: 1fr; } }
        .card {
            background: white; border-radius: 10px; padding: 20px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.08);
        }
        .card.full { grid-column: 1 / -1; }
        .card h2 {
            font-size: 1em; text-transform: uppercase; letter-spacing: 0.05em;
            color: #6b7280; margin-bottom: 16px; padding-bottom: 8px;
            border-bottom: 1px solid #e5e7eb;
        }
        .info-row {
            display: flex; justify-content: space-between; padding: 6px 0;
            border-bottom: 1px solid #f9fafb;
        }
        .info-label { color: #6b7280; font-size: 0.9em; }
        .info-value { font-weight: 500; font-size: 0.9em; }
        .status-badge {
            display: inline-block; padding: 2px 10px; border-radius: 10px;
            font-size: 0.8em; font-weight: 600;
        }
        .healthy { background: #d1fae5; color: #065f46; }
        .unhealthy { background: #fee2e2; color: #991b1b; }
        .warning { background: #fef3c7; color: #92400e; }
        .nav {
            display: flex; gap: 8px; margin-bottom: 24px;
        }
        .nav a {
            padding: 8px 16px; background: white; border-radius: 8px;
            text-decoration: none; color: #374151; font-size: 0.9em;
            box-shadow: 0 1px 3px rgba(0,0,0,0.08); transition: all 0.2s;
        }
        .nav a:hover { background: #2563eb; color: white; }
        .nav a.active { background: #2563eb; color: white; }
        .logs {
            background: #1e293b; color: #e2e8f0; padding: 16px;
            border-radius: 8px; font-family: 'Courier New', monospace;
            font-size: 0.8em; overflow-x: auto; white-space: pre-wrap;
            max-height: 200px; overflow-y: auto;
        }
        footer {
            text-align: center; color: #9ca3af; font-size: 0.8em;
            margin-top: 40px; padding-top: 20px; border-top: 1px solid #e5e7eb;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 {{ app_name }}</h1>
            <p>Deployed via Terraform &bull; AWS {{ region }} &bull; {{ instance_type }}</p>
        </div>

        <div class="nav">
            <a href="/" class="active">Dashboard</a>
            <a href="/health">Health Check</a>
            <a href="/api/info">API Info</a>
        </div>

        <div class="grid">
            <div class="card">
                <h2>Instance Info</h2>
                <div class="info-row">
                    <span class="info-label">Instance ID</span>
                    <span class="info-value">{{ instance_id }}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Instance Type</span>
                    <span class="info-value">{{ instance_type }}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Availability Zone</span>
                    <span class="info-value">{{ az }}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Private IP</span>
                    <span class="info-value">{{ private_ip }}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Hostname</span>
                    <span class="info-value">{{ hostname }}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Uptime</span>
                    <span class="info-value">{{ uptime_str }}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Load Average</span>
                    <span class="info-value">{{ load_str }}</span>
                </div>
            </div>

            <div class="card">
                <h2>Resource Usage</h2>
                <div class="info-row">
                    <span class="info-label">CPU Usage</span>
                    <span class="info-value">{{ cpu_usage }}%</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Memory</span>
                    <span class="info-value">{{ mem_used }}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Disk (/)</span>
                    <span class="info-value">{{ disk_usage }} of {{ disk_total }}</span>
                </div>
            </div>

            <div class="card">
                <h2>Database Status</h2>
                <div class="info-row">
                    <span class="info-label">Connection</span>
                    <span class="info-value">
                        <span class="status-badge {{ 'healthy' if db_connected else 'unhealthy' }}">
                            {{ 'Connected' if db_connected else 'Disconnected' }}
                        </span>
                    </span>
                </div>
                {% if db_host %}
                <div class="info-row">
                    <span class="info-label">Host</span>
                    <span class="info-value">{{ db_host }}</span>
                </div>
                {% endif %}
                {% if db_error %}
                <div class="info-row">
                    <span class="info-label">Error</span>
                    <span class="info-value" style="color: #dc2626; font-size: 0.8em;">{{ db_error }}</span>
                </div>
                {% endif %}
            </div>

            <div class="card full">
                <h2>Bootstrap Logs</h2>
                <div class="logs">{{ logs }}</div>
            </div>
        </div>

        <footer>
            <p>Terraform IaC Portfolio Project &bull; {{ timestamp }}</p>
        </footer>
    </div>
</body>
</html>
    """,
    app_name=os.environ.get("APP_NAME", "Terraform App"),
    instance_id=INSTANCE_ID,
    instance_type=INSTANCE_TYPE,
    private_ip=PRIVATE_IP,
    az=AZ,
    region=REGION,
    hostname=socket.gethostname(),
    uptime_str=uptime_str,
    load_str=load_str,
    cpu_usage=cpu_usage,
    mem_used=mem_used,
    disk_usage=disk_usage,
    disk_total=disk_total,
    db_connected=DB_STATUS["connected"],
    db_host=DB_STATUS["host"],
    db_error=DB_STATUS["error"],
    logs=get_bootstrap_logs(),
    timestamp=datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")
)


@app.route("/health")
def health():
    return jsonify({
        "status": "healthy",
        "instance_id": INSTANCE_ID,
        "az": AZ,
        "region": REGION,
        "app": os.environ.get("APP_NAME", "Terraform App"),
        "timestamp": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    }), 200


@app.route("/api/info")
def api_info():
    return jsonify({
        "instance_id": INSTANCE_ID,
        "instance_type": INSTANCE_TYPE,
        "private_ip": PRIVATE_IP,
        "az": AZ,
        "region": REGION,
        "hostname": socket.gethostname(),
        "db_connected": DB_STATUS["connected"],
        "db_host": DB_STATUS["host"],
        "timestamp": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    })


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
