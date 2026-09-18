## Soobshio Agent Core Implementation Plan

Date: 2026-04-02

Scope for this continuation:
- implement a minimal Python-only agent runtime on top of the current FastAPI and SQLAlchemy stack;
- persist threads, jobs, messages, facts, and tool logs in the existing database;
- expose a small admin-only API for manual runs and inspection;
- avoid new dependencies, background workers, and destructive tools.

Simplifications:
- phase 1 uses OpenAI-compatible chat completions against the already configured LiteLLM or compatible endpoint;
- tools are optional and start as a small allowlisted set with safe read-only behavior;
- event-driven worker and frontend review UI remain out of scope for this pass;
- verification will use targeted unit/API tests plus syntax checks instead of project-wide suites.

Implementation order:
1. Add SQLAlchemy models for agent persistence.
2. Add Pydantic schemas for runtime input/output.
3. Add memory helpers for CRUD on threads, messages, jobs, facts, and tool logs.
4. Add runtime orchestration with structured error handling and optional tool calls.
5. Add admin-protected FastAPI router for `/agent/run`, `/agent/jobs`, `/agent/threads/{thread_id}`, and `/agent/threads/{thread_id}/messages`.
6. Add focused tests for persistence and router behavior.

Acceptance target for this pass:
- a manual text task can be executed and persisted end-to-end;
- a manual vision task can be accepted and produce a structured result shape;
- recent jobs and thread history are retrievable via the backend API;
- failures still return persisted structured error records.
