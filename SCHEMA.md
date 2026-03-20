# Accountability Tracker — Schema Design

## Entity Types

| Key | Label | Purpose | Example metadata (JSONB) |
|-----|-------|---------|--------------------------|
| `workspace` | Workspace | Top-level container, one per team/org | `{ description }` |
| `project` | Project | A body of work with tasks and docs | `{ status, deadline, description }` |
| `sprint` | Sprint | Personal time-boxed commitment for one user | `{ start_date, end_date, goal }` |
| `task` | Task | Unit of work | `{ status, priority, deadline, estimate, labels[] }` |
| `document` | Document | Written artifact (spec, note, report) | `{ doc_type, url, labels[] }` |
| `person` | Person | Team member (mirrored from auth) | `{ email, role }` |

### What's NOT an entity

- **Labels** — metadata on the entity they tag (stored in JSONB `labels[]`), not first-class entities
- **Boards** — a frontend view of tasks grouped by status, not a data entity
- **Collections** — merged into projects; if a distinct concept emerges later, revisit

## Relationship Types

| Key | Forward Label | Reverse Label | Source → Target | Symmetric |
|-----|--------------|---------------|-----------------|-----------|
| `contains_project` | contains | belongs to | workspace → project | no |
| `contains_task` | contains | belongs to | project → task | no |
| `contains_doc` | contains | belongs to | project → document | no |
| `owned_by` | owned by | has sprint | sprint → person | no |
| `in_sprint` | scheduled in | includes | task → sprint | no |
| `assigned_to` | assigned to | responsible for | task → person | no |
| `authored` | authored | authored by | person → document | no |
| `references` | references | referenced by | task → document | no |
| `depends_on` | depends on | blocks | task → task | no |
| `subtask_of` | subtask of | has subtask | task → task | no |
| `collaborates` | works with | works with | person → person | yes |

## Task Status (Kanban)

Status is a string field in task metadata, not an entity. The plugin defines the allowed statuses:

```json
"task_statuses": ["backlog", "todo", "in_progress", "review", "done", "archived"]
```

The Flutter kanban board renders one column per status. If per-project custom workflows are needed later, status can be promoted to an entity type with `in_column` relationships.

## Permission Rules

| Rule | Type | Effect |
|------|------|--------|
| `workspace` | admin_only_entity_type | Only admins create workspaces |
| `person` | admin_only_entity_type | Only admins create/edit people |
| `assigned_to` | edit_granting_rel_type | If you're assigned to a task, you can edit it |
| `authored` | edit_granting_rel_type | If you authored a doc, you can edit it |

## Knowledge Graph View

The property graph gives something Jira/Trello doesn't — a visual map of:

- People clustered around the projects they work on
- Tasks connected to their assignees and dependencies
- Documents linked to the tasks that reference them
- Dependency chains visible as paths through the graph

## Research: How Others Model This

### Outline (getoutline/outline) — Wiki/Knowledge Base

- Hierarchical: Teams → Collections → Documents (nested via `parentDocumentId`)
- Permissions via junction tables (`UserMembership`, `GroupMembership`) with cascade down document tree
- Document relationships limited to `backlink` and `similar` — no general-purpose graph
- Everything hardcoded per entity type
- **Takeaway:** Too rigid for our use case. Tree-only relationships, no configurable entity types.

### Kanboard (kanboard/kanboard) — Kanban Tool (PHP, 9.5k stars)

- Task/workflow-centric: Projects → Columns → Swimlanes → Tasks
- Generic link model for task-to-task relationships (`links` table with `opposite_id` for bidirectional types like "blocks"/"is-blocked-by") — closest to our property graph, but only for tasks
- Key-value metadata stores on projects, tasks, and users (`*_has_metadata` tables)
- Custom per-project roles with column-level move restrictions
- **Takeaway:** The generic link model is smart. Our design generalises it to *all* entity types, not just tasks.

### accountability-tracker (RaggedR) — Robin's Existing App

- Node.js + Express + Firestore, deployed on Cloud Run
- Simple model: Users and weekly Posts (goals + accomplishments) with embedded peer ratings (1-5 stars)
- Time-gated editing: goals editable on Sundays (current week), summaries on Sundays (previous week)
- Vanilla JS frontend, no framework
- **Takeaway:** Proves the domain works. The weekly sprint + peer accountability concept carries forward. The data model would be replaced entirely by the CMS engine.

### Where CMS-Abstract Sits

| Aspect | Outline | Kanboard | CMS-Abstract |
|--------|---------|----------|--------------|
| Entity types | Hardcoded | Hardcoded | Configurable via admin panel |
| Relationships | Tree only (parent/child) | Generic links (tasks only) | Typed edges between any entities |
| Permissions | Role + membership cascade | Role + per-column restrictions | Configurable rules per entity/rel type |
| Metadata | Hardcoded fields per type | Key-value stores | JSONB with optional schema |
| Extensibility | Plugins (code) | Plugins (code) | Plugins (data-only JSON) |

## Features to Carry Forward from accountability-tracker

- Weekly sprint cadence (personal, per-user)
- Peer ratings / accountability (could be a relationship type: `rated` with rating in JSONB metadata)
- Time-gated editing (configurable per entity type? e.g. tasks in a closed sprint become read-only)
- Data export (JSON/CSV via `/api/plugins/export` generalisation)

## Original Draft (for reference)

Robin and Nick's initial brainstorm:

- entities: users, projects, documents, collections, sprints, task, workspaces, boards, labels
- labels: arxived
- each project has documents and tasks
- each task has optionally documents + one or more users
- each document belongs to a project
- each project belongs to a workspace

Refined from 9 entity types down to 6 by recognising that labels are metadata, boards are views, and collections overlap with projects.
