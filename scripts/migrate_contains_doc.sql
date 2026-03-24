-- Migration: contains_doc source_types changed from ["project"] to ["task"]
--
-- This migration converts existing project→document relationships to
-- task→document relationships. For each project→document relationship,
-- it finds all tasks belonging to that project and creates task→document
-- relationships instead. Orphaned project→document relationships are then
-- removed.
--
-- Run against the main database:
--   docker compose exec -T postgres psql -U outlier -d outlier -f /dev/stdin < scripts/migrate_contains_doc.sql

BEGIN;

-- Step 1: For each project→document relationship, create task→document
-- relationships using tasks that belong to the same project.
INSERT INTO relationships (id, source_entity_id, target_entity_id, rel_type_key, created_at)
SELECT
  gen_random_uuid()::text,
  task_rel.target_entity_id,  -- the task
  doc_rel.target_entity_id,   -- the document
  'contains_doc',
  NOW()
FROM relationships doc_rel
JOIN entities source_entity ON source_entity.id = doc_rel.source_entity_id
JOIN relationships task_rel ON task_rel.source_entity_id = doc_rel.source_entity_id
  AND task_rel.rel_type_key = 'contains_task'
WHERE doc_rel.rel_type_key = 'contains_doc'
  AND source_entity.type = 'project'
ON CONFLICT DO NOTHING;

-- Step 2: Remove the now-invalid project→document relationships.
DELETE FROM relationships
WHERE rel_type_key = 'contains_doc'
  AND source_entity_id IN (
    SELECT id FROM entities WHERE type = 'project'
  );

COMMIT;
