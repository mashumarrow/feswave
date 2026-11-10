-- Keep any prior Firebase identities in a separate namespace. Google sub and
-- Firebase UID are different identifiers and must never be matched implicitly.
ALTER TABLE auth_identities RENAME COLUMN project_id TO provider;
ALTER TABLE auth_identities RENAME COLUMN firebase_uid TO subject;
UPDATE auth_identities SET provider = 'firebase:' || provider;
ALTER TABLE auth_identities DROP CONSTRAINT auth_identities_user_id_key;
ALTER TABLE auth_identities ADD UNIQUE (user_id, provider);

ALTER TABLE sessions ADD COLUMN google_login_nonce TEXT;
ALTER TABLE sessions ADD COLUMN google_nonce_expires_at TIMESTAMPTZ;
