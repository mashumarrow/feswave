-- One optional, server-verified iTunes track snapshot per profile.
ALTER TABLE users ADD COLUMN music_track JSONB;
ALTER TABLE users ADD CONSTRAINT users_music_track_object
CHECK (music_track IS NULL OR (jsonb_typeof(music_track) = 'object' AND music_track ? 'trackId'));
