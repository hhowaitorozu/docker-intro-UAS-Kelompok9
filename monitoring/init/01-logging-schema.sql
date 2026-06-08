CREATE SCHEMA IF NOT EXISTS logs;

CREATE TABLE IF NOT EXISTS logs.container_logs (
    id BIGSERIAL PRIMARY KEY,
    received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    timestamp TIMESTAMP,
    container_name VARCHAR(100),
    container_id VARCHAR(64),
    source VARCHAR(10),
    log_level VARCHAR(10),
    message TEXT,
    raw_log TEXT,
    metadata JSONB DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_logs_timestamp ON logs.container_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_logs_container ON logs.container_logs(container_name);
CREATE INDEX IF NOT EXISTS idx_logs_level ON logs.container_logs(log_level);
CREATE INDEX IF NOT EXISTS idx_logs_received ON logs.container_logs(received_at);

CREATE OR REPLACE VIEW logs.recent_logs AS
SELECT id, to_char(timestamp, 'YYYY-MM-DD HH24:MI:SS') AS time,
       container_name AS container, log_level AS level, LEFT(message, 200) AS message_preview
FROM logs.container_logs ORDER BY timestamp DESC LIMIT 100;

CREATE OR REPLACE VIEW logs.error_summary AS
SELECT container_name, log_level, COUNT(*) AS count, MAX(timestamp) AS last_seen
FROM logs.container_logs WHERE log_level IN ('ERROR', 'WARN', 'CRITICAL')
GROUP BY container_name, log_level ORDER BY count DESC;
