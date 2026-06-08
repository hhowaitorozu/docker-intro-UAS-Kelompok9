import os, json, socket, datetime, logging, sys
from flask import Flask, jsonify, request
import psycopg2

app = Flask(__name__)

# Structured JSON logging ke stdout
class JSONFormatter(logging.Formatter):
    def format(self, record):
        return json.dumps({
            "timestamp": datetime.datetime.now().isoformat(),
            "level": record.levelname,
            "hostname": socket.gethostname(),
            "service": "flask-app",
            "message": record.getMessage(),
            "module": record.module
        })

handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JSONFormatter())
app.logger.handlers = [handler]
app.logger.setLevel(logging.INFO)

DB = dict(host=os.environ.get("DB_HOST","postgres-db"),
          dbname=os.environ.get("DB_NAME","labdb"),
          user=os.environ.get("DB_USER","labuser"),
          password=os.environ.get("DB_PASS","labpass123"))

@app.route("/")
def index():
    app.logger.info(f"Index accessed from {request.remote_addr}")
    return jsonify({"service": "flask-app", "status": "running"})

@app.route("/api/logs/stats")
def log_stats():
    """Query statistik log dari PostgreSQL"""
    try:
        conn = psycopg2.connect(**DB); cur = conn.cursor()
        cur.execute("""
            SELECT log_level, COUNT(*) as count
            FROM logs.container_logs
            WHERE received_at > NOW() - INTERVAL '1 hour'
            GROUP BY log_level ORDER BY count DESC
        """)
        stats = [{"level": r[0], "count": r[1]} for r in cur.fetchall()]
        cur.execute("SELECT COUNT(*) FROM logs.container_logs")
        total = cur.fetchone()[0]
        cur.close(); conn.close()
        return jsonify({"total_logs": total, "last_hour": stats})
    except Exception as e:
        app.logger.error(f"Failed to query log stats: {e}")
        return jsonify({"error": str(e)}), 500

@app.route("/api/logs/search")
def log_search():
    """Cari log berdasarkan keyword dan level"""
    keyword = request.args.get("q", "")
    level = request.args.get("level", "")
    limit = min(int(request.args.get("limit", 50)), 200)
    try:
        conn = psycopg2.connect(**DB); cur = conn.cursor()
        query = "SELECT id, timestamp, container_name, log_level, message FROM logs.container_logs WHERE 1=1"
        params = []
        if keyword:
            query += " AND message ILIKE %s"
            params.append(f"%{keyword}%")
        if level:
            query += " AND log_level = %s"
            params.append(level.upper())
        query += " ORDER BY timestamp DESC LIMIT %s"
        params.append(limit)
        cur.execute(query, params)
        logs = [{"id": r[0], "time": str(r[1]), "container": r[2],
                 "level": r[3], "message": r[4]} for r in cur.fetchall()]
        cur.close(); conn.close()
        return jsonify(logs)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
