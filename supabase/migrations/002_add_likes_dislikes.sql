-- Add likes_count and dislikes_count to complaints table
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS likes_count INTEGER DEFAULT 0;
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS dislikes_count INTEGER DEFAULT 0;
