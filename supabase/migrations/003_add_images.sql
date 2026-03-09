-- Add images column to complaints table
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS images JSONB DEFAULT '[]';
