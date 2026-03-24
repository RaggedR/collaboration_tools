import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/api_client.dart';
import '../../api/models/schema.dart';
import '../../state/providers.dart';
import '../../widgets/shared/metadata_form.dart';

/// Dialog for creating a new sprint.
class SprintCreateForm extends ConsumerStatefulWidget {
  const SprintCreateForm({super.key});

  @override
  ConsumerState<SprintCreateForm> createState() => _SprintCreateFormState();
}

class _SprintCreateFormState extends ConsumerState<SprintCreateForm> {
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final schemaAsync = ref.watch(schemaProvider);
    final sprintType = schemaAsync.valueOrNull?.entityTypes
        .cast<EntityType?>()
        .firstWhere((t) => t?.key == 'sprint', orElse: () => null);

    return AlertDialog(
      title: const Text('New Sprint'),
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
                metadataSchema: sprintType?.metadataSchema ?? {},
                uiSchema: sprintType?.uiSchema,
                isLoading: _isLoading,
                onSubmit: (name, metadata) => _create(name, metadata),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _create(String name, Map<String, dynamic> metadata) async {
    // Validate date ordering.
    final start = metadata['start_date'] as String?;
    final end = metadata['end_date'] as String?;
    if (start != null && end != null) {
      final startDate = DateTime.tryParse(start);
      final endDate = DateTime.tryParse(end);
      if (startDate != null && endDate != null && endDate.isBefore(startDate)) {
        setState(() => _error = 'End date must be after start date');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      await api.createEntity(type: 'sprint', name: name, metadata: metadata);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.message;
      });
    }
  }
}
