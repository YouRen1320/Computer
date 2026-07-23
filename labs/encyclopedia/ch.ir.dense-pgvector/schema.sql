-- Reference contract for PostgreSQL 18.4 + pgvector 0.8.2.
-- This file is inspected by the fixture verifier; it has not been executed here.
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE embedding_space (
    space_id text PRIMARY KEY,
    model_id text NOT NULL,
    model_revision text NOT NULL,
    dimensions integer NOT NULL CHECK (dimensions = 3),
    normalization text NOT NULL CHECK (normalization IN ('none', 'l2')),
    UNIQUE (model_id, model_revision, dimensions, normalization)
);

CREATE TABLE retrieval_chunk_embedding (
    chunk_id text NOT NULL,
    space_id text NOT NULL REFERENCES embedding_space(space_id),
    source_version text NOT NULL,
    acl_projection_version text NOT NULL,
    embedding vector(3) NOT NULL,
    PRIMARY KEY (chunk_id, space_id)
);

CREATE INDEX retrieval_chunk_embedding_hnsw_cosine
ON retrieval_chunk_embedding USING hnsw (embedding vector_cosine_ops);

-- $1 is the one allowed embedding space. $2 is an ACL-filtered chunk-id array
-- supplied from the Java-owned authorization path. $3 is the query vector.
SELECT chunk_id, embedding <=> $3::vector AS cosine_distance
FROM retrieval_chunk_embedding
WHERE space_id = $1 AND chunk_id = ANY($2)
ORDER BY embedding <=> $3::vector ASC
LIMIT $4;

-- Real gate command; preserve its machine-readable output as separate evidence.
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT chunk_id
FROM retrieval_chunk_embedding
WHERE space_id = $1 AND chunk_id = ANY($2)
ORDER BY embedding <=> $3::vector ASC
LIMIT $4;
