-- ALMAS LAW PostgreSQL Initialization Script
-- Creates required extensions and schemas for the platform

-- Enable pgvector extension for vector similarity search
CREATE EXTENSION IF NOT EXISTS vector;

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable JSON/JSONB functions
CREATE EXTENSION IF NOT EXISTS json;

-- Create schemas for logical separation
CREATE SCHEMA IF NOT EXISTS legal;
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS documents;
CREATE SCHEMA IF NOT EXISTS embeddings;

-- Create initial tables for legal documents
CREATE TABLE IF NOT EXISTS legal.documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(500) NOT NULL,
    content TEXT,
    document_type VARCHAR(100),
    jurisdiction VARCHAR(100),
    effective_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create table for document embeddings
CREATE TABLE IF NOT EXISTS embeddings.document_vectors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id UUID NOT NULL REFERENCES legal.documents(id) ON DELETE CASCADE,
    chunk_index INTEGER,
    embedding vector(1536),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index for vector similarity search
CREATE INDEX IF NOT EXISTS idx_embedding_vector ON embeddings.document_vectors USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- Create table for legal citations
CREATE TABLE IF NOT EXISTS legal.citations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_document_id UUID NOT NULL REFERENCES legal.documents(id) ON DELETE CASCADE,
    target_document_id UUID NOT NULL REFERENCES legal.documents(id) ON DELETE CASCADE,
    citation_type VARCHAR(50),
    confidence DECIMAL(3,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create audit log table
CREATE TABLE IF NOT EXISTS auth.audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id VARCHAR(255),
    action VARCHAR(100),
    resource VARCHAR(255),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    details JSONB
);

-- Set proper permissions
GRANT USAGE ON SCHEMA legal, auth, documents, embeddings TO postgres;
GRANT CREATE ON SCHEMA legal, auth, documents, embeddings TO postgres;

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS idx_documents_type ON legal.documents(document_type);
CREATE INDEX IF NOT EXISTS idx_documents_jurisdiction ON legal.documents(jurisdiction);
CREATE INDEX IF NOT EXISTS idx_citations_source ON legal.citations(source_document_id);
CREATE INDEX IF NOT EXISTS idx_citations_target ON legal.citations(target_document_id);
CREATE INDEX IF NOT EXISTS idx_audit_user ON auth.audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON auth.audit_logs(timestamp);

-- Comment on tables for documentation
COMMENT ON TABLE legal.documents IS 'Central repository for all legal documents processed by ALMAS LAW';
COMMENT ON TABLE legal.citations IS 'Relationships between legal documents (citations, references, supersedes)';
COMMENT ON TABLE embeddings.document_vectors IS 'Vector embeddings for semantic search over legal documents';
COMMENT ON TABLE auth.audit_logs IS 'Audit trail for system access and modifications';
