CREATE SCHEMA IF NOT EXISTS exposure;
CREATE TABLE IF NOT EXISTS exposure.nodes (
 id text PRIMARY KEY, name text NOT NULL, kind text NOT NULL,
 mark numeric NOT NULL DEFAULT 100 CHECK(mark>0)
);
CREATE TABLE IF NOT EXISTS exposure.links (
 source text REFERENCES exposure.nodes(id), target text REFERENCES exposure.nodes(id),
 weight numeric NOT NULL CHECK(weight>0 AND weight<=1),
 PRIMARY KEY(source,target), CHECK(source<>target)
);
CREATE INDEX IF NOT EXISTS exposure_target ON exposure.links(target);
CREATE TABLE IF NOT EXISTS exposure.metadata (
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton), profile text NOT NULL,
 seed integer NOT NULL, as_of text NOT NULL
);
