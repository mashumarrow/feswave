ALTER TABLE memories DROP CONSTRAINT memories_level_check;
ALTER TABLE memories ADD CONSTRAINT memories_level_check CHECK (level BETWEEN 1 AND 5);
