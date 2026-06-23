-- A self-referential foreign key: each user may report to another user.
-- Nullable, so top-level managers simply have no manager.
ALTER TABLE users ADD COLUMN manager_id INTEGER REFERENCES users(id);
