-- Supabase Hardening Patch: Schema validation, constraints, and stricter RLS

-- 1. Restrict lengths of text fields to prevent payload abuse/DOS
ALTER TABLE complaints
    ADD CONSTRAINT IF NOT EXISTS check_summary_length CHECK (char_length(summary) <= 300),
    ADD CONSTRAINT IF NOT EXISTS check_description_length CHECK (char_length(description) <= 5000),
    ADD CONSTRAINT IF NOT EXISTS check_address_length CHECK (char_length(address) <= 500),
    ADD CONSTRAINT IF NOT EXISTS check_category_length CHECK (char_length(category) <= 100);

ALTER TABLE comments
    ADD CONSTRAINT IF NOT EXISTS check_comment_text_length CHECK (char_length(text) <= 1000);

-- 2. Basic Rate Limiting function
CREATE OR REPLACE FUNCTION check_rate_limit()
RETURNS TRIGGER AS $$
DECLARE
    recent_count INTEGER;
BEGIN
    IF auth.role() = 'anon' THEN
        IF NEW.user_id IS NOT NULL THEN
            SELECT COUNT(*) INTO recent_count
            FROM complaints
            WHERE user_id = NEW.user_id 
              AND created_at > NOW() - INTERVAL '1 hour';
              
            IF recent_count >= 10 THEN
                RAISE EXCEPTION 'Rate limit exceeded: Please wait before submitting more reports.';
            END IF;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_limit_complaints ON complaints;
CREATE TRIGGER trg_limit_complaints
    BEFORE INSERT ON complaints
    FOR EACH ROW
    EXECUTE FUNCTION check_rate_limit();

-- 3. Stricter RLS Policies: Remove update rights on system tables for anon
DROP POLICY IF EXISTS "Allow anon update stats" ON stats;
DROP POLICY IF EXISTS "Allow anon insert stats" ON stats;
DROP POLICY IF EXISTS "Allow anon update infographic" ON infographic_data;
DROP POLICY IF EXISTS "Allow anon insert infographic" ON infographic_data;

-- Only authenticated users or service_role can write to stats/infographic now
CREATE POLICY "Allow auth insert stats" ON stats FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow auth update stats" ON stats FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Allow auth insert infographic" ON infographic_data FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow auth update infographic" ON infographic_data FOR UPDATE TO authenticated USING (true);

-- 4. Secure Complaint Status
ALTER TABLE complaints 
    ADD CONSTRAINT IF NOT EXISTS check_complaint_status 
    CHECK (status IN ('open', 'in_progress', 'resolved', 'closed', 'rejected', 'archived'));
