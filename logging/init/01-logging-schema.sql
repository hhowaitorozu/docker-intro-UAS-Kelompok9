-- ==============================================
-- Schema untuk Centralized Logging
-- ==============================================

CREATE SCHEMA IF NOT EXISTS logs;

-- Tabel utama: menyimpan semua log dari container
CREATE TABLE logs.container_logs (
    id BIGSERIAL PRIMARY KEY,
    received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    timestamp TIMESTAMP,
    container_name VARCHAR(100),
    container_id VARCHAR(64),
    source VARCHAR(10),           -- stdout / stderr
    log_level VARCHAR(10),
    message TEXT,
    raw_log TEXT,
    metadata JSONB DEFAULT '{}'
);

-- Tabel: summary per container per jam (untuk dashboard)
CREATE TABLE logs.hourly_summary (
    id SERIAL PRIMARY KEY,
    hour TIMESTAMP NOT NULL,
    container_name VARCHAR(100),
    total_logs INTEGER DEFAULT 0,
    error_count INTEGER DEFAULT 0,
    warn_count INTEGER DEFAULT 0,
    info_count INTEGER DEFAULT 0,
    UNIQUE(hour, container_name)
);

-- Index untuk performa query
CREATE INDEX idx_logs_timestamp ON logs.container_logs(timestamp);
CREATE INDEX idx_logs_container ON logs.container_logs(container_name);
CREATE INDEX idx_logs_level ON logs.container_logs(log_level);
CREATE INDEX idx_logs_received ON logs.container_logs(received_at);
CREATE INDEX idx_logs_metadata ON logs.container_logs USING GIN(metadata);
CREATE INDEX idx_summary_hour ON logs.hourly_summary(hour);

-- Fungsi: auto-cleanup log > 30 hari
CREATE OR REPLACE FUNCTION logs.cleanup_old_logs()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM logs.container_logs
    WHERE received_at < NOW() - INTERVAL '30 days';
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- View: log terbaru dengan format readable
CREATE VIEW logs.recent_logs AS
SELECT
    id,
    to_char(timestamp, 'YYYY-MM-DD HH24:MI:SS') AS time,
    container_name AS container,
    log_level AS level,
    LEFT(message, 200) AS message_preview
FROM logs.container_logs
ORDER BY timestamp DESC
LIMIT 100;

-- View: error summary per container
CREATE VIEW logs.error_summary AS
SELECT
    container_name,
    log_level,
    COUNT(*) AS count,
    MAX(timestamp) AS last_seen
FROM logs.container_logs
WHERE log_level IN ('ERROR', 'WARN', 'CRITICAL')
GROUP BY container_name, log_level
ORDER BY count DESC;

RAISE NOTICE 'Logging schema created successfully!';

