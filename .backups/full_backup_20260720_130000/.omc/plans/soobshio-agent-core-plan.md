# Soobshio Agent Core Plan

Goal: add a lightweight agent layer to the existing Soobshio Python stack
without introducing a second platform or replacing the current FastAPI /
LiteLLM / Ollama architecture.

Current fit:
- Existing model access already exists through LiteLLM and direct providers.
- Existing event sources already exist: Frigate, monitoring scripts, backend APIs.
- Existing persistence already exists through SQLAlchemy and the current DB.

Non-goals for the first iteration:
- No Bun / TypeScript runtime.
- No Slack-first agent UX.
- No Qdrant or vector DB in phase 1.
- No unrestricted shell/file automation.
- No autonomous code-editing agent inside the app runtime.

Design principles:
- Keep the first version Python-only.
- Reuse the current DB and service layout.
- Add a small orchestration layer instead of a new platform.
- Gate agent actions through explicit tool allowlists.
- Prefer event-driven escalation over a generic always-chatting assistant.

## Target outcome

Deliver a "Soobshio Agent Core" that can:
- accept a task or event;
- assemble project and runtime context;
- call the configured LLM through LiteLLM or another OpenAI-compatible endpoint;
- optionally invoke a small set of internal tools;
- persist memory, decisions, and execution logs;
- support both manual runs and always-on monitoring workflows.

## Phase 0: Discovery and interface design

Goal:
- define minimal contracts before code changes.

Deliverables:
- final data model for agent threads, jobs, messages, and facts;
- tool interface contract;
- agent runtime request/response schema;
- execution policy for what the agent may and may not do.

Questions to settle before implementation:
- which tasks are user-triggered vs event-triggered;
- which actions are fully automatic vs require approval;
- which model is the default for text vs vision escalation;
- whether memory is per user, per incident, or per system thread.

Output artifact:
- this plan plus a short API contract doc if needed.

## Phase 1: Minimal runtime

Goal:
- create a single Python agent runtime that works with the current model stack.

Planned files:
- `services/agent_runtime.py`
- `services/agent_schemas.py`

Scope:
- one entrypoint such as `run_agent_task(task_type, prompt, context)`;
- model calls through existing LiteLLM or compatible endpoint;
- normalized result shape:
  - `status`
  - `result`
  - `confidence`
  - `notes`
  - `tool_calls`
  - `errors`

Constraints:
- no direct shell execution;
- no uncontrolled network expansion beyond existing configured providers;
- strict timeout and retry policy.

Acceptance criteria:
- runtime can process a manual text task;
- runtime can process a vision task when an image is supplied;
- runtime returns structured output even on model failure.

## Phase 2: Memory in the existing database

Goal:
- persist agent state without adding new infrastructure.

Planned files:
- `backend/models.py`
- `backend/database.py`
- `services/agent_memory.py`

Proposed entities:
- `AgentThread`
- `AgentMessage`
- `AgentJob`
- `AgentFact`
- `AgentToolLog`

Suggested fields:
- thread id, source, scope, status;
- role, content, structured payload, token usage when available;
- job type, priority, started/finished timestamps;
- fact key, value, confidence, expiration;
- tool name, input summary, output summary, latency, success flag.

Constraints:
- use existing SQLAlchemy patterns;
- avoid schema sprawl in phase 1;
- facts should be compact and queryable.

Acceptance criteria:
- a manual run persists a thread and messages;
- a monitoring-triggered run persists a job and its outcome;
- history for a thread can be retrieved in order.

## Phase 3: Internal tools layer

Goal:
- expose a safe, small set of project-native tools to the runtime.

Planned files:
- `services/agent_tools.py`

Initial tool candidates:
- `camera_summary`
- `frigate_snapshot_analysis`
- `opendata_lookup`
- `report_lookup`
- `send_telegram_alert_preview`

Rules:
- tools are explicit Python functions;
- each tool has a typed input and output shape;
- tools log execution results;
- destructive actions are excluded from the first release.

Acceptance criteria:
- runtime can request and use at least two internal tools;
- tool failures are returned as structured errors;
- tool invocations are logged to DB.

## Phase 4: Backend API surface

Goal:
- make the runtime reachable from admin flows and future UI work.

Planned files:
- `services/Backend/routers/agent.py`
- `services/Backend/app.py`

Initial endpoints:
- `POST /agent/run`
- `GET /agent/jobs`
- `GET /agent/threads/{thread_id}`
- `GET /agent/threads/{thread_id}/messages`

Behavior:
- manual ad hoc runs through API;
- list recent jobs and statuses;
- inspect memory for debugging and review.

Constraints:
- admin or internal access only in the first version;
- rate limiting and basic authz must be enforced;
- no public anonymous agent endpoint.

Acceptance criteria:
- API can trigger a manual task;
- API can list and inspect persisted runs;
- invalid input fails with clear validation errors.

## Phase 5: Event-driven worker

Goal:
- connect the agent runtime to monitoring and escalation flows.

Planned files:
- `services/agent_worker.py`
- integration points near `services/frigate_bridge.py`
- possible bootstrap updates in `start_all_monitoring.py`

Initial scenarios:
- Frigate alert escalation;
- daily digest summarization;
- watchdog anomaly triage;
- opendata anomaly explanation.

Execution model:
- event comes in;
- worker builds context;
- worker runs agent task;
- worker stores result;
- worker emits notification or review item.

Constraints:
- start with one or two event types only;
- keep queueing simple at first;
- avoid mixing all monitoring logic into one file.

Acceptance criteria:
- one event source can trigger a full agent cycle;
- duplicate events are deduplicated or coalesced;
- notifications are only sent after policy checks.

## Phase 6: Admin review UI

Goal:
- provide visibility and operator control before expanding autonomy.

Expected later touchpoints:
- admin dashboard backend routes
- frontend admin screen(s)

First UI features:
- recent agent jobs list;
- job detail with prompt, context summary, tool calls, result;
- approve/reject for selected actions;
- retry failed job.

Non-goal:
- full conversational assistant UI in phase 1.

## Safety and policy layer

Must-have restrictions:
- tool allowlist only;
- no arbitrary shell commands;
- no arbitrary filesystem writes;
- explicit action classes: `analyze`, `summarize`, `classify`, `notify`;
- configurable timeout, retry count, and max tool calls;
- audit logs for prompts, outputs, and tool usage.

Approval model:
- automatic actions allowed only for low-risk notifications;
- anything externally visible or state-changing should be reviewable first.

## Verification strategy

Before implementation is considered complete, verify:
- lint passes;
- type checking passes where configured;
- DB schema changes migrate cleanly;
- manual agent task works end-to-end;
- at least one monitoring-triggered workflow works end-to-end;
- structured logs show prompt, tool usage, result, and errors.

Suggested tests:
- unit tests for runtime response normalization;
- unit tests for memory persistence;
- unit tests for tool dispatch and tool failure handling;
- integration test for `POST /agent/run`;
- integration test for a Frigate-triggered escalation flow.

## Risks

Primary risks:
- overbuilding a generic agent before validating a concrete workflow;
- mixing monitoring logic and agent logic too tightly;
- unclear permission boundaries for tool actions;
- low-quality memory storage that becomes noisy instead of useful;
- latency or cost spikes if all events are routed to the LLM.

Mitigations:
- start with one runtime, one worker, and one event flow;
- keep tool set very small;
- persist compact facts rather than full raw context where possible;
- use model gating so only escalations hit the LLM.

## Recommended implementation order

1. Finalize schemas and runtime contract.
2. Implement `agent_runtime.py`.
3. Add DB models and persistence helpers.
4. Add `agent_tools.py` with 2-3 safe tools.
5. Expose `POST /agent/run` and read APIs.
6. Integrate one event-driven worker path.
7. Add admin review UI after backend behavior is stable.

## Definition of done for MVP

MVP is done when:
- an internal API call can trigger an agent run;
- the run persists thread, messages, and job result;
- the agent can optionally call safe internal tools;
- one real Soobshio event flow uses the runtime successfully;
- operators can inspect the result and retry or review it.
