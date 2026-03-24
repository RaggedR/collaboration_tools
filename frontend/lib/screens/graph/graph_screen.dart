import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/models/graph.dart';
import '../../state/graph_state.dart';
import '../../widgets/shared/filter_bar.dart';

/// Interactive knowledge graph with force-directed-ish layout.
///
/// Uses InteractiveViewer for pan/zoom and CustomPainter for rendering.
/// No external graph package — simple circle + line layout.
class GraphScreen extends ConsumerStatefulWidget {
  const GraphScreen({super.key});

  @override
  ConsumerState<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends ConsumerState<GraphScreen> {
  String? _typeFilter;
  GraphNode? _selectedNode;

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(graphProvider.notifier).load(const GraphParams()));
  }

  @override
  Widget build(BuildContext context) {
    final graphAsync = ref.watch(graphProvider);

    return Column(
      children: [
        // Filter bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Text('Graph', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 16),
              FilterBar(
                filters: [
                  FilterOption(
                    label: 'Entity type',
                    value: _typeFilter,
                    options: const [
                      FilterChoice(value: 'task', label: 'Tasks'),
                      FilterChoice(value: 'person', label: 'People'),
                      FilterChoice(value: 'sprint', label: 'Sprints'),
                      FilterChoice(value: 'document', label: 'Documents'),
                      FilterChoice(value: 'project', label: 'Projects'),
                    ],
                    onChanged: (v) {
                      setState(() => _typeFilter = v);
                      ref.read(graphProvider.notifier).load(GraphParams(
                            types: v != null ? [v] : null,
                          ));
                    },
                  ),
                ],
                onClear: () {
                  setState(() => _typeFilter = null);
                  ref
                      .read(graphProvider.notifier)
                      .load(const GraphParams());
                },
              ),
            ],
          ),
        ),

        // Graph canvas
        Expanded(
          child: graphAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (graph) => graph.nodes.isEmpty
                ? const Center(child: Text('No data'))
                : Stack(
                    children: [
                      InteractiveViewer(
                        constrained: false,
                        boundaryMargin: const EdgeInsets.all(200),
                        minScale: 0.3,
                        maxScale: 3.0,
                        child: SizedBox(
                          width: 1200,
                          height: 800,
                          child: GestureDetector(
                            onTapUp: (details) =>
                                _onTap(details.localPosition, graph),
                            child: CustomPaint(
                              painter: _GraphPainter(
                                graph: graph,
                                positions: _layoutNodes(graph),
                                selectedId: _selectedNode?.id,
                              ),
                              size: const Size(1200, 800),
                            ),
                          ),
                        ),
                      ),
                      // Info card for selected node
                      if (_selectedNode != null)
                        Positioned(
                          right: 16,
                          top: 16,
                          child: _NodeInfoCard(
                            node: _selectedNode!,
                            onClose: () =>
                                setState(() => _selectedNode = null),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  /// Simple radial layout — nodes arranged in a circle.
  Map<String, Offset> _layoutNodes(Graph graph) {
    final positions = <String, Offset>{};
    final n = graph.nodes.length;
    if (n == 0) return positions;

    const cx = 600.0;
    const cy = 400.0;
    final radius = math.min(cx, cy) * 0.7;

    for (var i = 0; i < n; i++) {
      final angle = (2 * math.pi * i / n) - math.pi / 2;
      positions[graph.nodes[i].id] = Offset(
        cx + radius * math.cos(angle),
        cy + radius * math.sin(angle),
      );
    }
    return positions;
  }

  void _onTap(Offset position, Graph graph) {
    final positions = _layoutNodes(graph);
    for (final node in graph.nodes) {
      final nodePos = positions[node.id]!;
      if ((position - nodePos).distance < 24) {
        setState(() => _selectedNode = node);
        return;
      }
    }
    setState(() => _selectedNode = null);
  }
}

/// CustomPainter for the graph — draws edges then nodes.
class _GraphPainter extends CustomPainter {
  final Graph graph;
  final Map<String, Offset> positions;
  final String? selectedId;

  _GraphPainter({
    required this.graph,
    required this.positions,
    this.selectedId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final edgePaint = Paint()
      ..color = const Color(0x40888888)
      ..strokeWidth = 1.5;

    // Draw edges
    for (final edge in graph.edges) {
      final from = positions[edge.source];
      final to = positions[edge.target];
      if (from != null && to != null) {
        canvas.drawLine(from, to, edgePaint);

        // Label at midpoint
        final mid = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
        final tp = TextPainter(
          text: TextSpan(
            text: edge.label,
            style: const TextStyle(fontSize: 9, color: Color(0xFF888888)),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 100);
        tp.paint(canvas, mid - Offset(tp.width / 2, tp.height / 2));
      }
    }

    // Draw nodes
    for (final node in graph.nodes) {
      final pos = positions[node.id];
      if (pos == null) continue;

      final isSelected = node.id == selectedId;
      final color = _parseColor(node.color);
      final nodePaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawCircle(pos, isSelected ? 22 : 18, nodePaint);

      if (isSelected) {
        canvas.drawCircle(
          pos,
          24,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }

      // Node label
      final tp = TextPainter(
        text: TextSpan(
          text: node.name.length > 12
              ? '${node.name.substring(0, 12)}...'
              : node.name,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Color(0xFF333333),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 100);
      tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy + 22));
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter old) =>
      old.graph != graph || old.selectedId != selectedId;

  static Color _parseColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return const Color(0xFF9CA3AF);
    return Color(0xFF000000 | value);
  }
}

/// Info card showing details of the selected graph node.
class _NodeInfoCard extends StatelessWidget {
  final GraphNode node;
  final VoidCallback onClose;

  const _NodeInfoCard({required this.node, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 200,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(node.name,
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                node.type,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
