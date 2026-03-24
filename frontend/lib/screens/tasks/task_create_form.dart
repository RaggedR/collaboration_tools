import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/api_client.dart';
import '../../api/models/entity.dart';
import '../../api/models/schema.dart';
import '../../state/providers.dart';
import '../../widgets/shared/metadata_form.dart';

/// Dialog for creating a new task.
class TaskCreateForm extends ConsumerStatefulWidget {
  /// Pre-select a sprint when creating from sprint context.
  final String? initialSprintId;

  const TaskCreateForm({super.key, this.initialSprintId});

  @override
  ConsumerState<TaskCreateForm> createState() => _TaskCreateFormState();
}

class _TaskCreateFormState extends ConsumerState<TaskCreateForm> {
  final _metadataFormKey = GlobalKey<MetadataFormState>();
  bool _isLoading = false;
  String? _error;
  List<Entity> _sprints = [];
  String? _selectedSprintId;
  bool _sprintsLoaded = false;

  @override
  void initState() {
    super.initState();
    _selectedSprintId = widget.initialSprintId;
    _loadSprints();
  }

  Future<void> _loadSprints() async {
    try {
      final api = ref.read(apiClientProvider);
      final result = await api.listEntities(type: 'sprint', perPage: 100);
      if (mounted) {
        setState(() {
          _sprints = result.entities;
          _sprintsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _sprintsLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final schemaAsync = ref.watch(schemaProvider);
    final taskType = schemaAsync.valueOrNull?.entityTypes
        .cast<EntityType?>()
        .firstWhere((t) => t?.key == 'task', orElse: () => null);

    return AlertDialog(
      title: const Text('New Task'),
      content: SizedBox(
        width: 400,
        height: MediaQuery.of(context).size.height * 0.7,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Text(_error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 8),
              ],
              MetadataForm(
                key: _metadataFormKey,
                metadataSchema: taskType?.metadataSchema ?? {},
                uiSchema: taskType?.uiSchema,
                isLoading: _isLoading,
                showSubmitButton: false,
                onSubmit: (name, metadata) => _create(name, metadata),
              ),
              const SizedBox(height: 16),

              // Sprint selector
              if (_sprintsLoaded && _sprints.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedSprintId,
                  decoration:
                      const InputDecoration(labelText: 'Sprint (optional)'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('None'),
                    ),
                    ..._sprints.map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name),
                        )),
                  ],
                  onChanged: (v) =>
                      setState(() => _selectedSprintId = v),
                ),
              const SizedBox(height: 24),

              // Save button
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () => _metadataFormKey.currentState?.submit(),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _create(String name, Map<String, dynamic> metadata) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final entity = await api.createEntity(
          type: 'task', name: name, metadata: metadata);

      // Link to sprint if selected
      if (_selectedSprintId != null) {
        await api.createRelationship(
          relTypeKey: 'in_sprint',
          sourceEntityId: entity.id,
          targetEntityId: _selectedSprintId!,
        );
      }

      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.message;
      });
    }
  }
}
