-- Supabase Migration: Initial Schema for Soobshio
-- Создание таблиц для жалоб, пользователей, статистики и инфографики

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==================== USERS ====================
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    telegram_id BIGINT UNIQUE,
    username VARCHAR(100) UNIQUE,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    photo_url VARCHAR(500),
    balance INTEGER DEFAULT 0,
    notify_new INTEGER DEFAULT 0,
    digest_subscription_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_telegram_id ON users(telegram_id);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);

-- ==================== COMPLAINTS ====================
CREATE TABLE IF NOT EXISTS complaints (
    id BIGSERIAL PRIMARY KEY,
    external_id VARCHAR(50) UNIQUE,
    user_id BIGINT REFERENCES users(id),
    category VARCHAR(100) DEFAULT 'Прочее',
    summary VARCHAR(300),
    description TEXT,
    address VARCHAR(500),
    lat DOUBLE PRECISION,
    lng DOUBLE PRECISION,
    status VARCHAR(50) DEFAULT 'open',
    source VARCHAR(100) DEFAULT 'unknown',
    source_name VARCHAR(200),
    post_link VARCHAR(500),
    provider VARCHAR(200),
    telegram_message_id VARCHAR(100),
    telegram_channel VARCHAR(200),
    supporters INTEGER DEFAULT 0,
    supporters_notified INTEGER DEFAULT 0,
    uk_name VARCHAR(300),
    uk_email VARCHAR(200),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_complaints_category ON complaints(category);
CREATE INDEX IF NOT EXISTS idx_complaints_status ON complaints(status);
CREATE INDEX IF NOT EXISTS idx_complaints_created_at ON complaints(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_complaints_user_id ON complaints(user_id);
CREATE INDEX IF NOT EXISTS idx_complaints_lat_lng ON complaints(lat, lng);
CREATE INDEX IF NOT EXISTS idx_complaints_external_id ON complaints(external_id);

-- ==================== LIKES ====================
CREATE TABLE IF NOT EXISTS likes (
    id BIGSERIAL PRIMARY KEY,
    complaint_id BIGINT NOT NULL REFERENCES complaints(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(complaint_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_likes_complaint_id ON likes(complaint_id);
CREATE INDEX IF NOT EXISTS idx_likes_user_id ON likes(user_id);

-- ==================== COMMENTS ====================
CREATE TABLE IF NOT EXISTS comments (
    id BIGSERIAL PRIMARY KEY,
    complaint_id BIGINT NOT NULL REFERENCES complaints(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    text TEXT NOT NULL,
    parent_id BIGINT REFERENCES comments(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_comments_complaint_id ON comments(complaint_id);
CREATE INDEX IF NOT EXISTS idx_comments_user_id ON comments(user_id);
CREATE INDEX IF NOT EXISTS idx_comments_parent_id ON comments(parent_id);

-- ==================== STATS ====================
CREATE TABLE IF NOT EXISTS stats (
    id BIGSERIAL PRIMARY KEY,
    key VARCHAR(100) UNIQUE NOT NULL,
    data JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_stats_key ON stats(key);

-- ==================== INFOGRAPHIC DATA ====================
CREATE TABLE IF NOT EXISTS infographic_data (
    id BIGSERIAL PRIMARY KEY,
    data_type VARCHAR(100) UNIQUE NOT NULL,
    data JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_infographic_data_type ON infographic_data(data_type);

-- ==================== ROW LEVEL SECURITY ====================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE complaints ENABLE ROW LEVEL SECURITY;
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE infographic_data ENABLE ROW LEVEL SECURITY;

-- Policies for anonymous read access (public data)
CREATE POLICY "Allow public read complaints" ON complaints
    FOR SELECT USING (true);

CREATE POLICY "Allow public read stats" ON stats
    FOR SELECT USING (true);

CREATE POLICY "Allow public read infographic" ON infographic_data
    FOR SELECT USING (true);

CREATE POLICY "Allow public read comments" ON comments
    FOR SELECT USING (true);

CREATE POLICY "Allow public read likes count" ON likes
    FOR SELECT USING (true);

-- Policies for service role (full access via service key)
CREATE POLICY "Service role full access users" ON users
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access complaints" ON complaints
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access likes" ON likes
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access comments" ON comments
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access stats" ON stats
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access infographic" ON infographic_data
    FOR ALL USING (auth.role() = 'service_role');

-- Policies for anon role (insert allowed for complaints)
CREATE POLICY "Allow anon insert complaints" ON complaints
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow anon update complaints" ON complaints
    FOR UPDATE USING (true);

CREATE POLICY "Allow anon insert stats" ON stats
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow anon update stats" ON stats
    FOR UPDATE USING (true);

CREATE POLICY "Allow anon insert infographic" ON infographic_data
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow anon update infographic" ON infographic_data
    FOR UPDATE USING (true);

CREATE POLICY "Allow anon insert users" ON users
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow anon update users" ON users
    FOR UPDATE USING (true);

-- ==================== FUNCTIONS ====================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers to auto-update updated_at
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_complaints_updated_at
    BEFORE UPDATE ON complaints
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_comments_updated_at
    BEFORE UPDATE ON comments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_stats_updated_at
    BEFORE UPDATE ON stats
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_infographic_updated_at
    BEFORE UPDATE ON infographic_data
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ==================== ENABLE REALTIME ====================
-- Enable realtime for complaints table
ALTER PUBLICATION supabase_realtime ADD TABLE complaints;

-- Initial stats record
INSERT INTO stats (key, data) 
VALUES ('realtime_stats', '{"total_complaints": 0, "by_category": {}}')
ON CONFLICT (key) DO NOTHING;

-- Grant permissions to anon role for REST API access
GRANT USAGE ON SCHEMA public TO anon;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon;
