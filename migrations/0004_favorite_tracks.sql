CREATE TABLE user_tracks (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    track_id BIGINT NOT NULL CHECK (track_id > 0),
    track JSONB NOT NULL CHECK (jsonb_typeof(track) = 'object' AND track ? 'trackId' AND (track->>'trackId')::bigint = track_id),
    position SMALLINT NOT NULL CHECK (position BETWEEN 0 AND 19),
    PRIMARY KEY (user_id, track_id),
    UNIQUE (user_id, position)
);

ALTER TABLE users ADD COLUMN favorite_track_id BIGINT;

-- Preserve the previous single favorite as the first song and the icon song.
INSERT INTO user_tracks(user_id, track_id, track, position)
SELECT id, (music_track->>'trackId')::bigint, music_track, 0
FROM users WHERE music_track IS NOT NULL;
UPDATE users SET favorite_track_id = (music_track->>'trackId')::bigint WHERE music_track IS NOT NULL;

ALTER TABLE users ADD CONSTRAINT users_favorite_track_fk
FOREIGN KEY(id, favorite_track_id) REFERENCES user_tracks(user_id, track_id)
DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE users ADD CONSTRAINT users_favorite_track_snapshot
CHECK ((favorite_track_id IS NULL AND music_track IS NULL)
    OR (favorite_track_id IS NOT NULL AND music_track IS NOT NULL
        AND (music_track->>'trackId')::bigint = favorite_track_id));

CREATE VIEW user_profiles AS
SELECT u.*, COALESCE((
    SELECT jsonb_agg(t.track ORDER BY t.position)
    FROM user_tracks t WHERE t.user_id = u.id
), '[]'::jsonb) AS tracks
FROM users u;
