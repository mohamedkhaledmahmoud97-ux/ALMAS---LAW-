# ALMAS LAW — API Documentation (Draft v0.1)

**System:** Arabic Legal Multi-Agent Intelligence System
**Architecture version:** v2.1
**Doc status:** Draft — pre-implementation contract, for review before coding begins

---

## 1. Overview

This document defines the external-facing API contract for ALMAS LAW. It sits on top of the LangGraph-orchestrated multi-agent core and is the boundary that:

- Client applications (internal law-firm front end, admin console, future integrations) talk to
- Enforces the **Privacy Gateway** (no raw client PII ever reaches an LLM)
- Exposes results from the hybrid retrieval + Neo4j Legal Citation Graph
- Reports which model the **Adaptive Model Routing Engine** used, for auditability

Everything below is a **proposal** — flag anything that conflicts with decisions already locked in your architecture paper.

---

## 2. Base URL & Versioning

```
https://api.almaslaw.internal/v1
```

- Path-based versioning (`/v1`, `/v2`) — never break a live version; deprecate with a `Sunset` header and 6-month notice.
- All requests/responses: `application/json; charset=utf-8`.
- All timestamps: ISO 8601, UTC.

---

## 3. Authentication & Zero Trust Alignment

Consistent with NIST SP 800-207:

- **Auth method:** OAuth 2.0 Bearer JWT (short-lived access token + refresh token)
- **Every request** is authenticated and authorized independently — no implicit trust from network location (aligns with your Zero Trust zone model)
- **Header:**
  ```
  Authorization: Bearer <access_token>
  ```
- **Scopes** (example — refine against your 7-zone Sovereign Data Architecture):
  - `query:submit`
  - `query:read`
  - `documents:write`
  - `citations:read`
  - `clients:write` (highest sensitivity — routes through Privacy Gateway)
  - `admin:observability`

- **mTLS** between API gateway and internal agent services (service-to-service), per zero trust segmentation.

---

## 4. Core Resource: Legal Queries

This is the primary interaction — a user submits a legal question, the LangGraph orchestrator routes it through retrieval, citation-graph lookup, relevant agents, and model routing.

### 4.1 Submit a query

`POST /v1/queries`

**Request body:**
```json
{
  "client_code": "CLT-88213",
  "query_text": "ما هي شروط بطلان العقد وفقًا للقانون المدني المصري؟",
  "practice_area": "civil_law",
  "jurisdiction": "EG",
  "context_documents": ["doc_9f2a1c"],
  "response_mode": "sync"
}
```

| Field | Type | Notes |
|---|---|---|
| `client_code` | string | **Never** a national ID. Opaque internal code only — Privacy Gateway rejects requests containing raw PII patterns. |
| `query_text` | string | Arabic legal query, UTF-8. |
| `practice_area` | enum | Routes to relevant specialist agent(s). |
| `jurisdiction` | string | ISO country code; defaults to `EG`. |
| `context_documents` | array[string] | Optional prior-uploaded doc IDs to ground the query. |
| `response_mode` | `sync` \| `async` | `sync` for short queries; `async` recommended for anything triggering multi-agent deliberation. |

**Response — `202 Accepted` (async mode):**
```json
{
  "query_id": "qry_7f3e9a2b",
  "status": "processing",
  "status_url": "/v1/queries/qry_7f3e9a2b"
}
```

### 4.2 Get query status / result

`GET /v1/queries/{query_id}`

```json
{
  "query_id": "qry_7f3e9a2b",
  "status": "complete",
  "answer": {
    "text": "...",
    "confidence_basis": "evidence_grounded",
    "citations": [
      {"citation_id": "cit_4471", "source": "Egyptian Civil Code Art. 89", "graph_node": "neo4j://node/4471"}
    ],
    "agents_consulted": ["retrieval_agent", "civil_law_specialist", "citation_validator"],
    "model_routing": {
      "model_used": "deepseek-r1",
      "routing_reason": "arabic_legal_reasoning_priority"
    }
  },
  "created_at": "2026-07-04T09:12:00Z",
  "completed_at": "2026-07-04T09:12:41Z"
}
```

> Note the term **`confidence_basis: "evidence_grounded"`** — matches your preferred terminology ("Evidence-Grounded Legal Intelligence," not "zero hallucination").

### 4.3 Streaming (optional, recommended for long agent chains)

`GET /v1/queries/{query_id}/stream` (Server-Sent Events)

Emits incremental events as agents complete their steps — useful for showing orchestration progress in the UI (retrieval → citation check → specialist agent → validator).

---

## 5. Documents

`POST /v1/documents` — ingest a document into the retrieval pipeline (BM25/TF-IDF/semantic indexing + AraBERT embeddings).

```json
{
  "client_code": "CLT-88213",
  "file_ref": "s3://almas-docs/uploads/9f2a1c.pdf",
  "document_type": "contract",
  "language": "ar"
}
```

Returns a `document_id` once ingestion + anonymization pass completes. **Ingestion always routes through the Privacy Gateway before indexing** — this is a hard invariant, worth stating explicitly in the spec so no future implementation accidentally bypasses it.

---

## 6. Citation Graph

`GET /v1/citations/{citation_id}` — fetch a single citation node.

`GET /v1/citations/{citation_id}/related` — traverse the Neo4j Legal Citation Graph for related precedents/statutes (depth param, e.g. `?depth=2`).

---

## 7. Clients (Privacy-Gateway-Protected)

`POST /v1/clients` — register a client, returns an opaque `client_code`. This endpoint is the **only** place real client identity information should ever be submitted, and it's isolated in its own Sovereign Data Architecture zone, never passed downstream to LLM-facing services in raw form.

---

## 8. Observability / Admin

`GET /v1/admin/health` — service + agent liveness (feeds Prometheus/Grafana).

`GET /v1/admin/traces/{query_id}` — OpenTelemetry/Jaeger trace for a given query, for debugging agent orchestration.

---

## 9. Error Handling

Standard shape for all errors:

```json
{
  "error": {
    "code": "PRIVACY_GATEWAY_REJECTION",
    "message": "Request contains a pattern matching a national ID number.",
    "request_id": "req_a1b2c3"
  }
}
```

| HTTP Status | Code | Meaning |
|---|---|---|
| 400 | `INVALID_REQUEST` | Malformed payload |
| 401 | `UNAUTHORIZED` | Missing/invalid token |
| 403 | `FORBIDDEN` | Valid token, insufficient scope |
| 422 | `PRIVACY_GATEWAY_REJECTION` | PII detected pre-LLM — hard block, not a warning |
| 429 | `RATE_LIMITED` | Backoff per `Retry-After` header |
| 503 | `AGENT_UNAVAILABLE` | Orchestration layer degraded; check `/admin/health` |

---

## 10. Rate Limiting & Resilience

- Rate limits scoped per `client_code` and per API key.
- Aligns with your DR targets: **RPO < 1 hour, RTO < 4 hours** — API layer should fail closed (reject) rather than silently degrade privacy guarantees during a partial outage.

---

## 11. Schema Conventions

- All request/response bodies validated server-side via **Pydantic v2** models (matches your agent-communication standard) — the API layer and inter-agent layer should share the same validation philosophy even though the API uses JSON over HTTP and agents use JSON Schema internally.
- Never use JISON, per your existing standard.

---

## 12. Open Questions for You

1. **Sync vs async default** — should short queries (single-statute lookups) get a synchronous fast-path, or should *everything* go through async + polling/streaming for consistency?
2. **Multi-tenant law firms** — does one ALMAS deployment serve multiple firms (need a `firm_id` scope above `client_code`), or is this single-tenant per firm?
3. **Public API vs internal-only** — is this ever exposed outside MTC/your pilot firm, which would change the auth/rate-limit story significantly?

---

*Next suggested step: convert Section 4 (Queries) into an OpenAPI 3.1 YAML spec first, since it's the highest-traffic, highest-complexity endpoint — then use it as the template for the rest.*
