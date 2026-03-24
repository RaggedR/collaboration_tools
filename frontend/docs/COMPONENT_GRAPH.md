# Component: Knowledge Graph

## Overview

The knowledge graph visualises all entities and their relationships as an interactive force-directed graph. It's the "big picture" view — you can see how tasks, people, projects, sprints, and documents connect. Nodes are coloured by entity type, edges labelled by relationship type.

**Route:** `/graph`

---

## Screen Layout

```
┌──────────────────────────────────────────────────────────┐
│  App Shell                                                │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  ┌─ Filter Panel ────────────────────────────────────┐   │
│  │ Entity Types: [✓ task] [✓ person] [✓ project]     │   │
│  │               [✓ sprint] [✓ document] [□ workspace]│   │
│  │ Rel Types:    [✓ assigned_to] [✓ contains_task]   │   │
│  │               [✓ in_sprint] [✓ authored] ...      │   │
│  │ Focus: [Entity search...              ] [Clear]    │   │
│  └───────────────────────────────────────────────────┘   │
│                                                           │
│  ┌───────────────────────────────────────────────────┐   │
│  │                                                    │   │
│  │           ● person(Robin)                         │   │
│  │          /    \       \                            │   │
│  │   ● task ── ● task    ● sprint                   │   │
│  │      \       /                                    │   │
│  │    ● project ── ● document                       │   │
│  │                                                    │   │
│  │   (interactive: pan, zoom, drag nodes)            │   │
│  │                                                    │   │
│  └───────────────────────────────────────────────────┘   │
│                                                           │
│  ┌─ Node Info (on tap) ─────────────────────────────┐   │
│  │ Robin (person)          [Open Page →]             │   │
│  │ 5 tasks assigned, 2 sprints owned                 │   │
│  └───────────────────────────────────────────────────┘   │
│                                                           │
└──────────────────────────────────────────────────────────┘
```

---

## Implementation Approach: Native Flutter First

### Decision: `graphview` or `flutter_force_directed_graph`

**Primary approach:** Native Flutter graph rendering.

Pros:
- No WebView overhead (startup time, memory, platform issues)
- Full access to Flutter's gesture system (tap, drag, zoom)
- Consistent look and feel with the rest of the app
- Works on all platforms without WebView configuration

Cons:
- Less mature than d3.js for graph layout
- May need custom force simulation

**Fallback:** If native performance is poor for large graphs (>200 nodes), consider a WebView with d3-force. This is a deferred decision — start native, benchmark, escalate if needed.

### Package Evaluation

| Package | Pros | Cons |
|---------|------|------|
| `graphview` | Multiple layout algorithms (tree, Sugiyama, force-directed), Flutter-native | Force-directed layout less polished than d3 |
| `flutter_force_directed_graph` | Built specifically for force layout | Less mature |
| Custom with `CustomPainter` | Full control, can optimise for our exact needs | Most effort |

**Recommendation:** Start with `graphview` using `FruchtermanReingoldAlgorithm` (force-directed). Switch to custom `CustomPainter` if performance or layout quality is insufficient.

---

## Data Source

```
GET /api/graph
→ { nodes: [...], edges: [...] }

GET /api/graph?root_id=<entityId>&depth=2
→ Subgraph rooted at entity, 2 hops out

GET /api/graph?types=task,person,project
→ Only nodes of specified types (edges between them)
```

### Response Shape

```json
{
  "nodes": [
    { "id": "uuid", "type": "person", "name": "Robin", "color": "#ec4899", "icon": "person" }
  ],
  "edges": [
    { "id": "rel-uuid", "source": "uuid-1", "target": "uuid-2", "rel_type": "assigned_to", "label": "assigned to" }
  ]
}
```

The backend already enriches nodes with `color` and `icon` from the entity type config.

---

## Node Rendering

Each node is a circle (or rounded rect) with:

| Element | Source | Display |
|---------|--------|---------|
| Fill colour | `node.color` from API | Matches entity type colour from schema |
| Icon | `node.icon` from API | Material icon inside the circle |
| Label | `node.name` | Text below the node |
| Size | Based on connection count | More connections = slightly larger node |

### Entity Type Colours (from schema.config)

| Type | Colour | Icon |
|------|--------|------|
| workspace | `#6b7280` (grey) | `business` |
| project | `#3b82f6` (blue) | `folder` |
| sprint | `#8b5cf6` (purple) | `timer` |
| task | `#10b981` (green) | `check_circle` |
| document | `#f59e0b` (amber) | `description` |
| person | `#ec4899` (pink) | `person` |

---

## Edge Rendering

- Lines between nodes (straight or curved to avoid overlap)
- Label on the edge midpoint: relationship type forward label
- Edge colour: subtle grey (don't compete with node colours)
- Directionality: small arrowhead at the target end (except for symmetric relationships like `collaborates`)

---

## Interactions

### Pan & Zoom
- Pinch to zoom (mobile) / scroll wheel (desktop)
- Drag on empty space to pan
- Double-tap to zoom in, two-finger double-tap to zoom out

### Node Tap
- Tap a node → show info card at bottom of screen:
  - Entity name and type
  - Quick stats (e.g., "5 tasks assigned" for a person)
  - "Open" button → navigate to entity's screen:
    - Person → `/person/:id` (My Page)
    - Task → `/tasks` with task selected
    - Sprint → `/sprints` with sprint selected
    - Document → `/documents` with document selected

### Node Drag
- Drag a node to reposition it manually
- Node stays pinned after drag (doesn't snap back to force simulation)
- Release → stops at new position

### Edge Tap
- Tap an edge → highlight it, show relationship label more prominently
- Optional: show the two connected entities in the info card

---

## Filter Panel

Controls which entity types and relationship types appear in the graph.

### Entity Type Toggles
- One checkbox per entity type (from schema)
- Default: all visible except `workspace` (hidden flag in schema)
- When a type is toggled off: remove its nodes and connected edges

### Relationship Type Toggles
- One checkbox per relationship type (from schema)
- Default: all visible
- When a rel type is toggled off: remove edges of that type (keep nodes)

### Focus Search
- Text input to find a specific entity by name
- On select: re-fetch graph with `root_id=<entityId>&depth=2`
- "Clear" button: return to full graph

---

## Performance Considerations

| Graph Size | Strategy |
|------------|----------|
| < 50 nodes | Full graph, no issues |
| 50-200 nodes | Full graph, may need label hiding on zoom-out |
| 200+ nodes | Use `root_id` + `depth` to show subgraph; add "Load more" |

For the Collaboration Tools use case, expect 50-150 nodes in a typical team. Native Flutter should handle this fine.

### Optimisations
- Only render nodes visible in the current viewport
- Hide labels when zoomed out beyond a threshold
- Debounce filter changes (don't re-render on every toggle)
- Cache the graph data in Riverpod (`graphProvider`)

---

## State

```dart
class GraphParams {
  final String? rootId;
  final int depth;
  final List<String>? types;
  // == and hashCode
}

final graphProvider = FutureProvider.autoDispose.family<Graph, GraphParams>((ref, params) async {
  final api = ref.read(apiClientProvider);
  return api.getGraph(rootId: params.rootId, depth: params.depth, types: params.types);
});

// Local UI state (not in Riverpod — just StatefulWidget state)
// - selected node
// - filter toggles (entity types, rel types)
// - zoom level, pan offset
```

Filter toggles are local to the graph screen — they don't affect any other screen or persist across navigation.

---

## Empty State

- **No entities:** "No data to visualise. Create some entities to see the knowledge graph."
- **All filtered out:** "No entities match the current filters."

---

## Deferred Decision

The knowledge graph can be built last (Step 11 in the implementation plan). It's the least essential screen for MVP — the core value is in My Page, Tasks, and Sprints. If time is tight, ship without the graph and add it in a follow-up.

---

## Dependencies

- `graphview` package (or alternative)
- `graphProvider` (see [COMPONENT_STATE.md](./COMPONENT_STATE.md))
- `GET /api/graph` endpoint (already implemented in backend)
