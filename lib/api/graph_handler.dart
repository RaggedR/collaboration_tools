import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../config/schema_cache.dart';
import '../db/entity_queries.dart';
import '../db/relationship_queries.dart';

class GraphHandler {
  final EntityQueries entities;
  final RelationshipQueries relationships;
  final SchemaCache cache;

  GraphHandler({
    required this.entities,
    required this.relationships,
    required this.cache,
  });

  Future<Response> getGraph(Request request) async {
    final params = request.url.queryParameters;
    final rootId = params['root_id'];
    final depth = int.tryParse(params['depth'] ?? '') ?? 2;
    final types = params['types']?.split(',');

    if (rootId != null) {
      return _traverseFromRoot(rootId, depth, types);
    }

    return _fullGraph(types);
  }

  Future<Response> _fullGraph(List<String>? types) async {
    // Get all entities, optionally filtered by type
    final nodes = <Map<String, dynamic>>[];
    final nodeIds = <String>{};

    if (types != null) {
      for (final type in types) {
        final result = await entities.list(type: type, perPage: 10000);
        for (final entity in result.entities) {
          if (nodeIds.add(entity.id)) {
            nodes.add(_entityToNode(entity));
          }
        }
      }
    } else {
      final result = await entities.list(perPage: 10000);
      for (final entity in result.entities) {
        if (nodeIds.add(entity.id)) {
          nodes.add(_entityToNode(entity));
        }
      }
    }

    // Get all relationships between these nodes
    final edges = <Map<String, dynamic>>[];
    final allRels = await relationships.list();
    for (final rel in allRels) {
      if (nodeIds.contains(rel.sourceEntityId) &&
          nodeIds.contains(rel.targetEntityId)) {
        final relType = cache.getRelType(rel.relTypeKey);
        edges.add({
          'id': rel.id,
          'source': rel.sourceEntityId,
          'target': rel.targetEntityId,
          'rel_type': rel.relTypeKey,
          'label': relType?.forwardLabel ?? rel.relTypeKey,
        });
      }
    }

    return Response.ok(
      jsonEncode({'nodes': nodes, 'edges': edges}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _traverseFromRoot(
      String rootId, int maxDepth, List<String>? types) async {
    final visited = <String>{};
    final nodes = <Map<String, dynamic>>[];
    final edges = <Map<String, dynamic>>[];
    final queue = <_TraversalEntry>[_TraversalEntry(rootId, 0)];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (visited.contains(current.id) || current.depth > maxDepth) continue;
      visited.add(current.id);

      try {
        final detail = await entities.getWithRelationships(current.id);
        final entity = detail.entity;

        // Apply type filter
        if (types != null && !types.contains(entity.type)) continue;

        nodes.add(_entityToNode(entity));

        if (current.depth < maxDepth) {
          for (final rel in detail.relationships) {
            final relatedId = rel.relatedEntity.id;
            if (!visited.contains(relatedId)) {
              queue.add(_TraversalEntry(relatedId, current.depth + 1));
            }
          }
        }
      } catch (_) {
        // Entity not found, skip
      }
    }

    // Collect edges between visited nodes
    final allRels = await relationships.list();
    for (final rel in allRels) {
      if (visited.contains(rel.sourceEntityId) &&
          visited.contains(rel.targetEntityId)) {
        final relType = cache.getRelType(rel.relTypeKey);
        edges.add({
          'id': rel.id,
          'source': rel.sourceEntityId,
          'target': rel.targetEntityId,
          'rel_type': rel.relTypeKey,
          'label': relType?.forwardLabel ?? rel.relTypeKey,
        });
      }
    }

    return Response.ok(
      jsonEncode({'nodes': nodes, 'edges': edges}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Map<String, dynamic> _entityToNode(dynamic entity) {
    final entityType = cache.getEntityType(entity.type);
    return {
      'id': entity.id,
      'type': entity.type,
      'name': entity.name,
      'color': entityType?.color ?? '#6b7280',
      'icon': entityType?.icon,
    };
  }
}

class _TraversalEntry {
  final String id;
  final int depth;
  _TraversalEntry(this.id, this.depth);
}
