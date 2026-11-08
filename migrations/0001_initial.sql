CREATE TABLE events (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    subtitle TEXT NOT NULL,
    date_label TEXT NOT NULL,
    venue TEXT NOT NULL,
    artist TEXT NOT NULL,
    song TEXT NOT NULL,
    time_label TEXT NOT NULL,
    color TEXT NOT NULL CHECK (color IN ('pink', 'blue', 'purple', 'orange')),
    sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE users (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL DEFAULT '' CHECK (char_length(name) <= 20),
    artist TEXT NOT NULL DEFAULT '' CHECK (char_length(artist) <= 60),
    song TEXT NOT NULL DEFAULT '' CHECK (char_length(song) <= 60),
    color TEXT NOT NULL DEFAULT 'pink' CHECK (color IN ('pink', 'blue', 'purple', 'orange')),
    visible BOOLEAN NOT NULL DEFAULT FALSE,
    event_id TEXT REFERENCES events(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE sessions (
    token_hash TEXT PRIMARY KEY CHECK (char_length(token_hash) = 64),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '365 days'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX sessions_user_idx ON sessions(user_id);
CREATE INDEX sessions_expiry_idx ON sessions(expires_at);

CREATE TABLE event_participants (
    event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY(event_id, user_id)
);

CREATE TABLE memories (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    person_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    occurred_at TIMESTAMPTZ NOT NULL,
    level SMALLINT NOT NULL CHECK (level BETWEEN 1 AND 3),
    favorite BOOLEAN NOT NULL DEFAULT FALSE,
    CHECK (user_id <> person_id),
    UNIQUE(user_id, person_id, event_id, occurred_at)
);
CREATE INDEX memories_owner_time_idx ON memories(user_id, occurred_at DESC);
CREATE INDEX memories_person_idx ON memories(person_id);
