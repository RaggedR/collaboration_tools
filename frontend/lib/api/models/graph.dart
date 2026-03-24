/// Graph response from GET /api/graph.
class Graph {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;

  Graph({required this.nodes, required this.edges});

  factory Graph.fromJson(Map<String, dynamic> json) {
    return Graph(
      nodes: (json['nodes'] as List)
          .map((n) => GraphNode.fromJson(n as Map<String, dynamic>))
          .toList(),
      edges: (json['edges'] as List)
          .map((e) => GraphEdge.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class GraphNode {
  final String id;
  final String type;
  final String name;
  final String color;
  final String? icon;

  GraphNode({
    required this.id,
    required this.type,
    required this.name,
    required this.color,
    this.icon,
  });

  factory GraphNode.fromJson(Map<String, dynamic> json) {
    return GraphNode(
      id: json['id'] as String,
      type: json['type'] as String,
      name: json['name'] as String,
      color: json['color'] as String,
      icon: json['icon'] as String?,
    );
  }
}

class GraphEdge {
  final String id;
  final String source;
  final String target;
  final String relType;
  final String label;

  GraphEdge({
    required this.id,
    required this.source,
    required this.target,
    required this.relType,
    required this.label,
  });

  factory GraphEdge.fromJson(Map<String, dynamic> json) {
    return GraphEdge(
      id: json['id'] as String,
      source: json['source'] as String,
      target: json['target'] as String,
      relType: json['rel_type'] as String,
      label: json['label'] as String,
    );
  }
}
