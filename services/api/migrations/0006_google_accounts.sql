-- Authentication identities are private and never included in public profiles.
CREATE TABLE auth_identities (
    project_id TEXT NOT NULL,
    firebase_uid TEXT NOT NULL CHECK (char_length(firebase_uid) BETWEEN 1 AND 128),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (project_id, firebase_uid)
);
