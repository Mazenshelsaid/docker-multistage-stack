CREATE TABLE IF NOT EXISTS visits (
    id serial PRIMARY KEY,
    visited_at timestamptz NOT NULL DEFAULT now()
);
