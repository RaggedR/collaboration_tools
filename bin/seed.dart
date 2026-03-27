import 'dart:convert';
import 'dart:io';

import 'package:dbcrypt/dbcrypt.dart';
import 'package:postgres/postgres.dart';

import 'package:outlier/config/schema_loader.dart';
import 'package:outlier/db/database.dart';

/// Seed script — populates the database with realistic test data.
///
/// Idempotent: clears existing data and re-creates everything.
/// Run: dart run bin/seed.dart
void main() async {
  final databaseUrl = Platform.environment['DATABASE_URL'] ??
      'postgresql://localhost:5432/outlier';

  // 1. Connect & migrate
  final db = await Database.connect(databaseUrl);
  stderr.writeln('Connected to database');
  await db.migrate();

  // Auth migration (users table)
  await db.execute('''
    CREATE TABLE IF NOT EXISTS users (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      email TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      person_entity_id UUID UNIQUE REFERENCES entities(id),
      is_admin BOOLEAN NOT NULL DEFAULT FALSE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  ''');

  // 2. Sync schema.config
  final configFile = File('schema.config');
  if (!configFile.existsSync()) {
    stderr.writeln('ERROR: schema.config not found — run from project root');
    exit(1);
  }
  final config =
      jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
  final validation = SchemaLoader.validate(config);
  if (!validation.isValid) {
    stderr.writeln('ERROR: Invalid schema.config: ${validation.errors}');
    exit(1);
  }
  await SchemaLoader.syncToDatabase(config, db);
  stderr.writeln('Schema synced');

  // 3. Clear existing data (FK order)
  await db.execute('DELETE FROM relationships');
  await db.execute('DELETE FROM users');
  await db.execute('DELETE FROM entities');
  stderr.writeln('Cleared existing data');

  // Helper: insert entity, return its UUID
  Future<String> insertEntity(
    String type,
    String name, {
    String? body,
    Map<String, dynamic> metadata = const {},
    String? createdBy,
  }) async {
    final result = await db.query(
      Sql.named('''
        INSERT INTO entities (type, name, body, metadata, created_by)
        VALUES (@type, @name, @body, @metadata, @createdBy)
        RETURNING id
      '''),
      parameters: {
        'type': type,
        'name': name,
        'body': body,
        'metadata': jsonEncode(metadata),
        'createdBy': createdBy,
      },
    );
    return result.first.toColumnMap()['id'] as String;
  }

  // Helper: insert relationship
  Future<String> insertRel(
    String relType,
    String sourceId,
    String targetId, {
    Map<String, dynamic> metadata = const {},
    String? createdBy,
  }) async {
    final result = await db.query(
      Sql.named('''
        INSERT INTO relationships (rel_type_key, source_entity_id, target_entity_id, metadata, created_by)
        VALUES (@relType, @sourceId, @targetId, @metadata, @createdBy)
        RETURNING id
      '''),
      parameters: {
        'relType': relType,
        'sourceId': sourceId,
        'targetId': targetId,
        'metadata': jsonEncode(metadata),
        'createdBy': createdBy,
      },
    );
    return result.first.toColumnMap()['id'] as String;
  }

  // ─── PEOPLE ───────────────────────────────────────────────

  final robin = await insertEntity('person', 'Robin',
      metadata: {'email': 'robin@example.com', 'role': 'admin'});
  final nick = await insertEntity('person', 'Nick',
      metadata: {'email': 'nick@example.com', 'role': 'developer'});
  final sarah = await insertEntity('person', 'Sarah',
      metadata: {'email': 'sarah@example.com', 'role': 'designer'});
  final karim = await insertEntity('person', 'Karim',
      metadata: {'email': 'karim@example.com', 'role': 'developer'});
  stderr.writeln('Created 4 people');

  // ─── ADMIN USER ───────────────────────────────────────────

  final passwordHash = DBCrypt().hashpw('password', DBCrypt().gensalt());
  await db.execute(
    Sql.named('''
      INSERT INTO users (email, password_hash, person_entity_id, is_admin)
      VALUES (@email, @hash, @personId, TRUE)
    '''),
    parameters: {
      'email': 'robin@example.com',
      'hash': passwordHash,
      'personId': robin,
    },
  );
  stderr.writeln('Created admin user (robin@example.com / password)');

  // ─── WORKSPACES ───────────────────────────────────────────

  final wsImagineering = await insertEntity('workspace', 'Imagineering',
      metadata: {'description': 'AI building community in Melbourne'},
      createdBy: robin);
  final wsArxiv = await insertEntity('workspace', 'Arxiv Papers',
      metadata: {'description': 'Research paper tracking and annotation'},
      createdBy: robin);
  stderr.writeln('Created 2 workspaces');

  // ─── PROJECTS ─────────────────────────────────────────────

  final projDashboard = await insertEntity('project', 'Dashboard',
      body: 'Main application dashboard with kanban views, sprint tracking, and sidebar navigation.',
      metadata: {'status': 'active', 'description': 'Main CMS dashboard application'},
      createdBy: robin);
  final projGateway = await insertEntity('project', 'Gateway',
      body: 'API gateway layer for routing and rate limiting external requests.',
      metadata: {'status': 'active', 'description': 'API gateway service'},
      createdBy: robin);
  final projBookFinder = await insertEntity('project', 'Book Finder',
      body: 'Recommendation engine that matches users to books using collaborative filtering.',
      metadata: {'status': 'paused', 'description': 'Book recommendation system'},
      createdBy: robin);
  final projEmbeddings = await insertEntity('project', 'Embeddings Research',
      body: 'Comparative study of embedding models for semantic search and retrieval.',
      metadata: {'status': 'completed', 'description': 'Embedding model research'},
      createdBy: robin);
  final projTransformers = await insertEntity('project', 'Transformer Architectures',
      body: 'Survey of transformer variants: efficient attention, mixture of experts, state space models.',
      metadata: {'status': 'active', 'description': 'Transformer architecture survey'},
      createdBy: robin);
  final projRL = await insertEntity('project', 'Reinforcement Learning',
      body: 'Collection of RL papers focusing on RLHF, reward modeling, and alignment.',
      metadata: {'status': 'active', 'description': 'RL and alignment research'},
      createdBy: robin);
  stderr.writeln('Created 6 projects');

  // Link workspaces → projects
  await insertRel('contains_project', wsImagineering, projDashboard);
  await insertRel('contains_project', wsImagineering, projGateway);
  await insertRel('contains_project', wsImagineering, projBookFinder);
  await insertRel('contains_project', wsImagineering, projEmbeddings);
  await insertRel('contains_project', wsArxiv, projTransformers);
  await insertRel('contains_project', wsArxiv, projRL);

  // ─── SPRINTS (under Dashboard) ────────────────────────────

  final sprint1 = await insertEntity('sprint', 'Sprint 1: Foundation',
      metadata: {
        'status': 'completed',
        'start_date': '2026-02-17',
        'end_date': '2026-02-28',
        'goal': 'Stand up database, API, and auth — get first entity CRUD working end-to-end.',
        'retro': 'Delivered all 5 stories. Auth took longer than expected due to JWT library quirks.',
      },
      createdBy: robin);
  final sprint2 = await insertEntity('sprint', 'Sprint 2: Frontend',
      metadata: {
        'status': 'active',
        'start_date': '2026-03-02',
        'end_date': '2026-03-20',
        'goal': 'Build the Flutter frontend: kanban board, sidebar, document viewer, sprint panel.',
      },
      createdBy: robin);
  final sprint3 = await insertEntity('sprint', 'Sprint 3: Polish',
      metadata: {
        'status': 'planning',
        'start_date': '2026-03-23',
        'end_date': '2026-04-04',
        'goal': 'Dark mode, keyboard shortcuts, export, and performance optimisation.',
      },
      createdBy: robin);
  stderr.writeln('Created 3 sprints');

  // Link project → sprints
  await insertRel('contains_sprint', projDashboard, sprint1);
  await insertRel('contains_sprint', projDashboard, sprint2);
  await insertRel('contains_sprint', projDashboard, sprint3);

  // Sprint ownership + participation
  await insertRel('owned_by', sprint1, robin);
  await insertRel('owned_by', sprint2, robin);
  await insertRel('owned_by', sprint3, robin);
  await insertRel('participates_in', robin, sprint1,
      metadata: {'goal': 'Deliver DB + API foundation'});
  await insertRel('participates_in', nick, sprint1,
      metadata: {'goal': 'Build auth system'});
  await insertRel('participates_in', sarah, sprint1,
      metadata: {'goal': 'Complete wireframes for all screens'});
  await insertRel('participates_in', robin, sprint2,
      metadata: {'goal': 'Sidebar navigation and state management'});
  await insertRel('participates_in', nick, sprint2,
      metadata: {'goal': 'Kanban board with drag-and-drop'});
  await insertRel('participates_in', sarah, sprint2,
      metadata: {'goal': 'Style all views and responsive layout'});
  await insertRel('participates_in', karim, sprint2,
      metadata: {'goal': 'Sprint detail panel and entity search'});

  // ─── TASKS ────────────────────────────────────────────────

  // Sprint 1 tasks (all done)
  final t1 = await insertEntity('task', 'Set up database schema',
      body: 'Create PostgreSQL tables for entities, relationships, entity_types, and rel_types. Include migrations.',
      metadata: {'status': 'done', 'priority': 'high', 'estimate': 5, 'labels': ['backend', 'infrastructure']},
      createdBy: robin);
  final t2 = await insertEntity('task', 'Create entity CRUD API',
      body: 'Implement REST endpoints: GET/POST/PUT/DELETE for entities with pagination and metadata filtering.',
      metadata: {'status': 'done', 'priority': 'high', 'estimate': 8, 'labels': ['backend', 'api']},
      createdBy: robin);
  final t3 = await insertEntity('task', 'Implement auth system',
      body: 'JWT-based auth with registration, login, and middleware. Auto-create person entity on register.',
      metadata: {'status': 'done', 'priority': 'high', 'estimate': 5, 'labels': ['backend', 'security']},
      createdBy: nick);
  final t4 = await insertEntity('task', 'Design wireframes',
      body: 'Create wireframes for kanban board, sprint list, document viewer, and sidebar navigation.',
      metadata: {'status': 'done', 'priority': 'medium', 'estimate': 3, 'labels': ['design']},
      createdBy: sarah);
  final t5 = await insertEntity('task', 'Write schema.config',
      body: 'Define entity types, relationship types, permission rules, and UI schema in declarative config.',
      metadata: {'status': 'done', 'priority': 'high', 'estimate': 5, 'labels': ['backend', 'config']},
      createdBy: robin);

  // Sprint 2 tasks (mixed)
  final t6 = await insertEntity('task', 'Build kanban board',
      body: 'Drag-and-drop kanban with columns driven by task status enum. Support project scoping.',
      metadata: {'status': 'in_progress', 'priority': 'high', 'estimate': 8, 'labels': ['frontend', 'feature']},
      createdBy: nick);
  final t7 = await insertEntity('task', 'Implement sidebar navigation',
      body: 'Three-column layout: icon rail, collapsible sidebar with project tree and people list, content area.',
      metadata: {'status': 'in_progress', 'priority': 'high', 'estimate': 5, 'labels': ['frontend', 'navigation']},
      createdBy: robin);
  final t8 = await insertEntity('task', 'Add drag-and-drop',
      body: 'Integrate flutter drag-and-drop for kanban cards. Update task status on column change.',
      metadata: {'status': 'todo', 'priority': 'medium', 'estimate': 5, 'labels': ['frontend']},
      createdBy: nick);
  final t9 = await insertEntity('task', 'Style document viewer',
      body: 'Apply consistent styling to document detail panel: type badges, status indicators, markdown body.',
      metadata: {'status': 'review', 'priority': 'medium', 'estimate': 3, 'labels': ['frontend', 'design']},
      createdBy: sarah);
  final t10 = await insertEntity('task', 'Sprint detail panel',
      body: 'Side panel showing sprint goal, dates, participants, tasks, and retrospective.',
      metadata: {'status': 'in_progress', 'priority': 'medium', 'estimate': 5, 'labels': ['frontend', 'feature']},
      createdBy: karim);
  final t11 = await insertEntity('task', 'Responsive layout',
      body: 'Support mobile (bottom nav + drawer) and desktop (sidebar + rail) layouts.',
      metadata: {'status': 'todo', 'priority': 'low', 'estimate': 3, 'labels': ['frontend', 'responsive']},
      createdBy: sarah);
  final t12 = await insertEntity('task', 'Entity search',
      body: 'Add search bar to toolbar that filters entities by name across all types.',
      metadata: {'status': 'backlog', 'priority': 'low', 'estimate': 3, 'labels': ['frontend', 'feature']},
      createdBy: karim);

  // Sprint 3 tasks (planning)
  final t13 = await insertEntity('task', 'Dark mode',
      body: 'Implement theme switching between light and dark color schemes.',
      metadata: {'status': 'backlog', 'priority': 'medium', 'labels': ['frontend', 'theme']},
      createdBy: sarah);
  final t14 = await insertEntity('task', 'Keyboard shortcuts',
      body: 'Add keyboard shortcuts for common actions: new task (N), search (/), navigate (J/K).',
      metadata: {'status': 'backlog', 'priority': 'low', 'labels': ['frontend', 'accessibility']},
      createdBy: nick);
  final t15 = await insertEntity('task', 'Export to PDF',
      body: 'Generate PDF reports from sprint retrospectives and document collections.',
      metadata: {'status': 'todo', 'priority': 'low', 'labels': ['feature', 'export']},
      createdBy: karim);
  final t16 = await insertEntity('task', 'Performance audit',
      body: 'Profile API response times and frontend render performance. Target <200ms API, <16ms frames.',
      metadata: {'status': 'backlog', 'priority': 'medium', 'labels': ['infrastructure', 'performance']},
      createdBy: robin);

  // Non-sprint tasks
  final t17 = await insertEntity('task', 'Research embedding models',
      body: 'Compare OpenAI ada-002, Cohere embed-v3, and BGE-large for semantic search quality and latency.',
      metadata: {'status': 'done', 'priority': 'high', 'labels': ['research', 'ml']},
      createdBy: robin);
  final t18 = await insertEntity('task', 'Evaluate vector databases',
      body: 'Benchmark Pinecone, Weaviate, and pgvector for 1M+ document collections.',
      metadata: {'status': 'in_progress', 'priority': 'medium', 'labels': ['research', 'infrastructure']},
      createdBy: nick);
  final t19 = await insertEntity('task', 'Set up API gateway',
      body: 'Configure rate limiting, request routing, and API key management.',
      metadata: {'status': 'todo', 'priority': 'high', 'labels': ['backend', 'infrastructure']},
      createdBy: karim);
  final t20 = await insertEntity('task', 'Review transformer survey paper',
      body: 'Read and annotate "A Survey of Transformers" — focus on efficient attention mechanisms.',
      metadata: {'status': 'in_progress', 'priority': 'medium', 'labels': ['research', 'reading']},
      createdBy: robin);
  final t21 = await insertEntity('task', 'Annotate RL benchmarks',
      body: 'Document key results from RLHF papers: InstructGPT, Constitutional AI, DPO.',
      metadata: {'status': 'todo', 'priority': 'medium', 'labels': ['research', 'reading']},
      createdBy: nick);
  final t22 = await insertEntity('task', 'Book recommendation algorithm',
      body: 'Implement collaborative filtering using user-book interaction matrix and cosine similarity.',
      metadata: {'status': 'in_progress', 'priority': 'high', 'labels': ['feature', 'ml']},
      createdBy: karim);
  stderr.writeln('Created 22 tasks');

  // Link tasks → projects
  for (final tid in [t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11, t12, t13, t14, t15, t16]) {
    await insertRel('contains_task', projDashboard, tid);
  }
  await insertRel('contains_task', projEmbeddings, t17);
  await insertRel('contains_task', projEmbeddings, t18);
  await insertRel('contains_task', projGateway, t19);
  await insertRel('contains_task', projTransformers, t20);
  await insertRel('contains_task', projRL, t21);
  await insertRel('contains_task', projBookFinder, t22);

  // Link tasks → sprints
  for (final tid in [t1, t2, t3, t4, t5]) {
    await insertRel('in_sprint', tid, sprint1);
  }
  for (final tid in [t6, t7, t8, t9, t10, t11, t12]) {
    await insertRel('in_sprint', tid, sprint2);
  }
  for (final tid in [t13, t14, t15, t16]) {
    await insertRel('in_sprint', tid, sprint3);
  }

  // Link tasks → assignees
  await insertRel('assigned_to', t1, robin);
  await insertRel('assigned_to', t2, robin);
  await insertRel('assigned_to', t3, nick);
  await insertRel('assigned_to', t4, sarah);
  await insertRel('assigned_to', t5, robin);
  await insertRel('assigned_to', t6, nick);
  await insertRel('assigned_to', t7, robin);
  await insertRel('assigned_to', t8, nick);
  await insertRel('assigned_to', t9, sarah);
  await insertRel('assigned_to', t10, karim);
  await insertRel('assigned_to', t11, sarah);
  await insertRel('assigned_to', t12, karim);
  await insertRel('assigned_to', t13, sarah);
  await insertRel('assigned_to', t14, nick);
  await insertRel('assigned_to', t15, karim);
  await insertRel('assigned_to', t16, robin);
  await insertRel('assigned_to', t17, robin);
  await insertRel('assigned_to', t18, nick);
  await insertRel('assigned_to', t19, karim);
  await insertRel('assigned_to', t20, robin);
  await insertRel('assigned_to', t21, nick);
  await insertRel('assigned_to', t22, karim);

  // ─── DOCUMENTS ────────────────────────────────────────────

  final d1 = await insertEntity('document', 'Architecture Spec',
      body: '# Architecture\n\nPostgreSQL-backed entity system with typed relationships.\n\n## Tables\n- `entities` — polymorphic, type-keyed rows\n- `relationships` — typed edges between entities\n- `entity_types` / `rel_types` — schema definitions\n\n## Key Decisions\n- Single `entities` table (not one table per type) for flexibility\n- JSONB `metadata` for type-specific fields\n- `schema.config` drives both backend validation and frontend UI generation',
      metadata: {'status': 'active', 'doc_type': 'spec', 'labels': ['architecture', 'backend']},
      createdBy: robin);
  final d2 = await insertEntity('document', 'API Design Doc',
      body: '# REST API Design\n\n## Endpoints\n- `GET /api/entities?type=task&metadata={...}` — list with filters\n- `POST /api/entities` — create\n- `PUT /api/entities/:id` — update\n- `DELETE /api/entities/:id` — delete\n- `GET /api/entities/:id` — get with relationships\n\n## Auth\nJWT bearer tokens. First registered user auto-promotes to admin.',
      metadata: {'status': 'active', 'doc_type': 'spec', 'labels': ['api', 'backend']},
      createdBy: robin);
  final d3 = await insertEntity('document', 'Auth Flow Diagram',
      body: '# Authentication Flow\n\n1. User registers → password hashed with bcrypt → JWT issued\n2. JWT contains: sub (user ID), is_admin, iat, exp\n3. Middleware extracts user from token on every request\n4. Person entity auto-created and linked to user on registration\n5. Permission rules checked against user relationships to entities',
      metadata: {'status': 'active', 'doc_type': 'reference', 'labels': ['auth', 'security']},
      createdBy: nick);
  final d4 = await insertEntity('document', 'Wireframe Notes',
      body: '# Wireframe Notes\n\n## Layout\n- Desktop: 72px icon rail + 200px sidebar + content\n- Mobile: bottom nav + slide-out drawer\n\n## Key Screens\n1. **Kanban** — columns from task status enum\n2. **Sprints** — grouped by current/upcoming/completed\n3. **Documents** — table with type badges and search\n4. **Detail panels** — slide-in from right on desktop',
      metadata: {'status': 'active', 'doc_type': 'note', 'labels': ['design', 'ux']},
      createdBy: sarah);
  final d5 = await insertEntity('document', 'Sprint 1 Retrospective',
      body: '# Sprint 1 Retrospective\n\n## What went well\n- Schema-driven approach paid off — adding new entity types is trivial\n- Auth system works cleanly with person entity linking\n\n## What to improve\n- JWT library had undocumented breaking changes — add version pinning\n- Need better error messages for schema validation failures\n\n## Action items\n- [ ] Pin all dependency versions\n- [ ] Add schema validation error codes',
      metadata: {'status': 'active', 'doc_type': 'report', 'labels': ['retro', 'sprint-1']},
      createdBy: robin);
  final d6 = await insertEntity('document', 'Kanban Board Spec',
      body: '# Kanban Board Specification\n\n## Columns\nDerived from `task.metadata_schema.properties.status.enum`:\nbacklog → todo → in_progress → review → done\n\n## Features\n- Drag cards between columns → PATCH status\n- Project scoping via sidebar selection\n- Priority badges on cards\n- Assignee avatars',
      metadata: {'status': 'active', 'doc_type': 'spec', 'labels': ['frontend', 'kanban']},
      createdBy: nick);
  final d7 = await insertEntity('document', 'UI Component Library',
      body: '# UI Component Library\n\n## Shared Widgets\n- `MetadataField` — renders any field from ui_schema\n- `RelationshipList` — grouped relationship display\n- `StatusBadge` — colored pill from ui:colors\n- `EntityCard` — generic card driven by card schema\n\n## Design Tokens\n- Primary: #2563eb\n- Muted text: #64748b\n- Card bg: surface color from theme',
      metadata: {'status': 'active', 'doc_type': 'reference', 'labels': ['frontend', 'design-system']},
      createdBy: sarah);
  final d8 = await insertEntity('document', 'Embedding Models Comparison',
      body: '# Embedding Model Comparison\n\n| Model | Dim | Latency | MRR@10 |\n|-------|-----|---------|--------|\n| ada-002 | 1536 | 45ms | 0.82 |\n| embed-v3 | 1024 | 38ms | 0.85 |\n| BGE-large | 1024 | 22ms | 0.83 |\n\n## Recommendation\nCohere embed-v3 offers the best quality/latency tradeoff for our use case.',
      metadata: {'status': 'active', 'doc_type': 'report', 'labels': ['research', 'embeddings']},
      createdBy: robin);
  final d9 = await insertEntity('document', 'Vector DB Benchmarks',
      body: '# Vector Database Benchmarks\n\n## Setup\n1M synthetic documents, 1024-dim embeddings\n\n## Results\n- **Pinecone**: 12ms p99, managed, \$70/mo\n- **Weaviate**: 18ms p99, self-hosted, free\n- **pgvector**: 35ms p99, no new infra, free\n\n## Decision\npgvector for MVP (already have Postgres), migrate to Weaviate if scale demands it.',
      metadata: {'status': 'active', 'doc_type': 'report', 'labels': ['research', 'infrastructure']},
      createdBy: nick);
  final d10 = await insertEntity('document', 'Attention Is All You Need — Notes',
      body: '# Attention Is All You Need\n\nVaswani et al., 2017\n\n## Key Ideas\n- Self-attention replaces recurrence entirely\n- Multi-head attention allows attending to different representation subspaces\n- Positional encoding adds sequence order information\n- Encoder-decoder architecture with residual connections + layer norm\n\n## Open Questions\n- How do efficient attention variants (Linformer, Performer) trade quality for speed?',
      metadata: {'status': 'active', 'doc_type': 'note', 'labels': ['research', 'transformers']},
      createdBy: robin);
  final d11 = await insertEntity('document', 'RL Environment Setup Guide',
      body: '# RL Environment Setup\n\n## Prerequisites\n- Python 3.10+\n- CUDA 12.1 (for GPU training)\n\n## Environments\n1. `gymnasium` — standard RL benchmarks\n2. `trl` — HuggingFace RLHF training\n3. Custom reward model from InstructGPT paper\n\n## Running\n```bash\npip install -r requirements-rl.txt\npython train.py --env CartPole-v1\n```',
      metadata: {'status': 'active', 'doc_type': 'reference', 'labels': ['research', 'rl', 'setup']},
      createdBy: nick);
  final d12 = await insertEntity('document', 'Book Matching Algorithm Spec',
      body: '# Book Matching Algorithm\n\n## Approach\nCollaborative filtering with implicit feedback.\n\n## Pipeline\n1. Build user-book interaction matrix from Hardcover API\n2. Compute item-item similarity (cosine on TF-IDF of interaction vectors)\n3. For target user, score candidate books by weighted sum of similarities to their read books\n4. Re-rank using genre diversity bonus\n\n## Metrics\n- Precision@10, NDCG@10 on held-out test set',
      metadata: {'status': 'active', 'doc_type': 'spec', 'labels': ['ml', 'recommendations']},
      createdBy: karim);
  stderr.writeln('Created 12 documents');

  // Link tasks → documents (contains_doc)
  await insertRel('contains_doc', t1, d1);  // DB schema → Architecture Spec
  await insertRel('contains_doc', t2, d2);  // CRUD API → API Design Doc
  await insertRel('contains_doc', t3, d3);  // Auth → Auth Flow
  await insertRel('contains_doc', t4, d4);  // Wireframes → Wireframe Notes
  await insertRel('contains_doc', t6, d6);  // Kanban → Kanban Board Spec
  await insertRel('contains_doc', t9, d7);  // Style doc viewer → UI Component Library
  await insertRel('contains_doc', t17, d8); // Embedding research → Embedding Comparison
  await insertRel('contains_doc', t18, d9); // Vector DBs → Vector DB Benchmarks
  await insertRel('contains_doc', t20, d10); // Transformer survey → Attention notes
  await insertRel('contains_doc', t21, d11); // RL benchmarks → RL setup guide
  await insertRel('contains_doc', t22, d12); // Book algo → Book Matching Spec

  // Cross-references (references rel)
  await insertRel('references', t6, d1);   // Kanban references Architecture Spec
  await insertRel('references', t7, d4);   // Sidebar references Wireframe Notes
  await insertRel('references', t10, d6);  // Sprint panel references Kanban Spec
  await insertRel('references', t9, d4);   // Style doc viewer references Wireframes
  await insertRel('references', t18, d8);  // Vector DBs references Embedding comparison

  // Link people → documents (authored)
  await insertRel('authored', robin, d1);
  await insertRel('authored', robin, d2);
  await insertRel('authored', nick, d3);
  await insertRel('authored', sarah, d4);
  await insertRel('authored', robin, d5);
  await insertRel('authored', nick, d6);
  await insertRel('authored', sarah, d7);
  await insertRel('authored', robin, d8);
  await insertRel('authored', nick, d9);
  await insertRel('authored', robin, d10);
  await insertRel('authored', nick, d11);
  await insertRel('authored', karim, d12);

  // Sprint 1 retro linked to sprint context
  await insertRel('references', t5, d5);  // schema.config task references retro

  // ─── DEPENDENCY RELATIONSHIPS ─────────────────────────────

  await insertRel('depends_on', t6, t4);   // Kanban depends on wireframes
  await insertRel('depends_on', t8, t6);   // Drag-drop depends on kanban
  await insertRel('depends_on', t9, t4);   // Style doc viewer depends on wireframes
  await insertRel('depends_on', t7, t4);   // Sidebar depends on wireframes
  await insertRel('depends_on', t18, t17); // Vector DBs depends on embedding research

  // Collaborates (symmetric)
  await insertRel('collaborates', robin, nick);
  await insertRel('collaborates', sarah, karim);

  // ─── SUMMARY ──────────────────────────────────────────────

  final entityCount = await db.query('SELECT COUNT(*) as c FROM entities');
  final relCount = await db.query('SELECT COUNT(*) as c FROM relationships');
  final userCount = await db.query('SELECT COUNT(*) as c FROM users');

  final ec = entityCount.first.toColumnMap()['c'];
  final rc = relCount.first.toColumnMap()['c'];
  final uc = userCount.first.toColumnMap()['c'];

  stderr.writeln('');
  stderr.writeln('=== Seed complete ===');
  stderr.writeln('  Entities:      $ec');
  stderr.writeln('  Relationships: $rc');
  stderr.writeln('  Users:         $uc');
  stderr.writeln('');
  stderr.writeln('Login: robin@example.com / password');

  await db.close();
}
