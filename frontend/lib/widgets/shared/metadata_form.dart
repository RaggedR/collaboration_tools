import 'package:flutter/material.dart';

/// A generic form widget built dynamically from a JSON Schema metadata_schema.
///
/// This is the one schema-driven widget in the frontend — it builds form
/// fields from the entity type's metadata_schema.
class MetadataForm extends StatefulWidget {
  /// The JSON Schema for this entity type's metadata.
  final Map<String, dynamic> metadataSchema;

  /// Current metadata values (for edit mode). Null for create mode.
  final Map<String, dynamic>? initialValues;

  /// Called when the form is submitted with valid data.
  final void Function(String name, Map<String, dynamic> metadata) onSubmit;

  /// Whether the form is in a loading state (e.g., submitting).
  final bool isLoading;

  /// Initial entity name (for edit mode).
  final String? initialName;

  /// Whether to show the built-in submit button. Set to false when
  /// providing your own button and calling [MetadataFormState.submit].
  final bool showSubmitButton;

  const MetadataForm({
    super.key,
    required this.metadataSchema,
    this.initialValues,
    required this.onSubmit,
    this.isLoading = false,
    this.initialName,
    this.showSubmitButton = true,
  });

  @override
  State<MetadataForm> createState() => MetadataFormState();
}

class MetadataFormState extends State<MetadataForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late Map<String, dynamic> _values;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _values = Map.from(widget.initialValues ?? {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rawProperties = widget.metadataSchema['properties'];
    final properties = rawProperties is Map
        ? Map<String, dynamic>.from(rawProperties)
        : <String, dynamic>{};
    final required = (widget.metadataSchema['required'] as List?)
            ?.cast<String>()
            .toSet() ??
        {};

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Name field (always present)
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (v) =>
                v == null || v.isEmpty ? 'Name is required' : null,
          ),
          const SizedBox(height: 16),

          // Dynamic metadata fields
          ...properties.entries.map((entry) {
            final fieldKey = entry.key;
            final fieldSchema = Map<String, dynamic>.from(entry.value as Map);
            final isRequired = required.contains(fieldKey);
            return _buildField(fieldKey, fieldSchema, isRequired);
          }),

          if (widget.showSubmitButton) ...[
            const SizedBox(height: 24),

            // Submit button
            ElevatedButton(
              onPressed: widget.isLoading ? null : submit,
              child: widget.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildField(
      String key, Map<String, dynamic> schema, bool isRequired) {
    final type = schema['type'] as String?;
    final enumValues = schema['enum'] as List?;
    final format = schema['format'] as String?;
    final label = _humanize(key);

    // String with enum → dropdown
    if (type == 'string' && enumValues != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DropdownButtonFormField<String>(
          value: _values[key] as String?,
          decoration: InputDecoration(labelText: label),
          items: enumValues
              .cast<String>()
              .map((v) => DropdownMenuItem(value: v, child: Text(_humanize(v))))
              .toList(),
          onChanged: (v) => setState(() => _values[key] = v),
          validator: isRequired
              ? (v) => v == null ? '$label is required' : null
              : null,
        ),
      );
    }

    // String with date format → date picker
    if (type == 'string' && format == 'date') {
      final currentValue = _values[key] as String?;
      return Padding(
        key: ValueKey('$key-$currentValue'),
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          initialValue: currentValue,
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.calendar_today),
          ),
          readOnly: true,
          onTap: () async {
            final existing = _values[key] as String?;
            final initial = existing != null
                ? DateTime.tryParse(existing) ?? DateTime.now()
                : DateTime.now();
            final date = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (date != null) {
              setState(() => _values[key] =
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}');
            }
          },
          validator: isRequired
              ? (v) => v == null || v.isEmpty ? '$label is required' : null
              : null,
        ),
      );
    }

    // Number
    if (type == 'number') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          initialValue: _values[key]?.toString(),
          decoration: InputDecoration(labelText: label),
          keyboardType: TextInputType.number,
          onChanged: (v) =>
              setState(() => _values[key] = num.tryParse(v)),
          validator: isRequired
              ? (v) => v == null || v.isEmpty ? '$label is required' : null
              : null,
        ),
      );
    }

    // Array of strings → chip input (simplified as text for now)
    if (type == 'array') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          initialValue: (_values[key] as List?)?.join(', '),
          decoration: InputDecoration(
            labelText: label,
            helperText: 'Comma-separated values',
          ),
          onChanged: (v) => setState(() => _values[key] =
              v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()),
        ),
      );
    }

    // Default: text field
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: _values[key] as String?,
        decoration: InputDecoration(labelText: label),
        onChanged: (v) => setState(() => _values[key] = v),
        validator: isRequired
            ? (v) => v == null || v.isEmpty ? '$label is required' : null
            : null,
      ),
    );
  }

  void submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSubmit(_nameController.text, Map.from(_values));
    }
  }

  String _humanize(String s) {
    return s
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
