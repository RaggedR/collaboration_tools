import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/api_client.dart';
import '../../api/models/entity.dart';
import '../../api/models/schema.dart';
import '../../state/providers.dart';
import '../../widgets/shared/markdown_viewer.dart';
import '../../widgets/shared/metadata_form.dart';

/// Dialog for creating a new document.
class DocumentCreateForm extends ConsumerStatefulWidget {
  const DocumentCreateForm({super.key});

  @override
  ConsumerState<DocumentCreateForm> createState() =>
      _DocumentCreateFormState();
}

class _DocumentCreateFormState extends ConsumerState<DocumentCreateForm> {
  final _metadataFormKey = GlobalKey<MetadataFormState>();
  bool _isLoading = false;
  String? _error;
  final _bodyController = TextEditingController();
  bool _showPreview = false;
  String? _uploadedUrl;
  String? _uploadedFilename;
  bool _isUploading = false;
  List<Entity> _tasks = [];
  String? _selectedTaskId;
  bool _tasksLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      final api = ref.read(apiClientProvider);
      final result = await api.listEntities(type: 'task', perPage: 100);
      if (mounted) {
        setState(() {
          _tasks = result.entities;
          _tasksLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _tasksLoaded = true);
    }
  }

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final schemaAsync = ref.watch(schemaProvider);
    final docType = schemaAsync.valueOrNull?.entityTypes
        .cast<EntityType?>()
        .firstWhere((t) => t?.key == 'document', orElse: () => null);

    return AlertDialog(
      title: const Text('New Document'),
      content: SizedBox(
        width: 500,
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

              // Name + metadata fields
              MetadataForm(
                key: _metadataFormKey,
                metadataSchema: docType?.metadataSchema ?? {},
                isLoading: _isLoading,
                showSubmitButton: false,
                onSubmit: (name, metadata) => _create(name, metadata),
              ),
              const SizedBox(height: 16),

              // Linked task selector
              if (_tasksLoaded && _tasks.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedTaskId,
                  decoration: const InputDecoration(
                      labelText: 'Linked Task (optional)'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('None'),
                    ),
                    ..._tasks.map((t) => DropdownMenuItem(
                          value: t.id,
                          child: Text(t.name,
                              overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (v) =>
                      setState(() => _selectedTaskId = v),
                ),
              const SizedBox(height: 16),

              // Body editor
              Row(
                children: [
                  Text('Body (Markdown)',
                      style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  TextButton.icon(
                    icon: Icon(
                        _showPreview ? Icons.edit : Icons.visibility),
                    label: Text(_showPreview ? 'Edit' : 'Preview'),
                    onPressed: () =>
                        setState(() => _showPreview = !_showPreview),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_showPreview)
                Container(
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(minHeight: 100),
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _bodyController.text.isEmpty
                      ? Text('Nothing to preview',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant))
                      : MarkdownViewer(data: _bodyController.text),
                )
              else
                TextField(
                  controller: _bodyController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Write markdown content...',
                    border: OutlineInputBorder(),
                  ),
                ),
              const SizedBox(height: 16),

              // File upload
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: _isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.upload_file, size: 18),
                    label:
                        Text(_isUploading ? 'Uploading...' : 'Attach File'),
                    onPressed: _isUploading ? null : _pickAndUpload,
                  ),
                  if (_uploadedFilename != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Chip(
                        avatar: const Icon(Icons.attach_file, size: 16),
                        label: Text(_uploadedFilename!,
                            overflow: TextOverflow.ellipsis),
                        onDeleted: () => setState(() {
                          _uploadedUrl = null;
                          _uploadedFilename = null;
                        }),
                      ),
                    ),
                  ],
                ],
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

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'gif', 'webp', 'svg'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() => _isUploading = true);

    try {
      final api = ref.read(apiClientProvider);
      final url = await api.uploadFile(file.bytes!, file.name);
      setState(() {
        _uploadedUrl = url;
        _uploadedFilename = file.name;
        _isUploading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _isUploading = false;
        _error = 'Upload failed: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _isUploading = false;
        _error = 'Upload failed: $e';
      });
    }
  }

  Future<void> _create(String name, Map<String, dynamic> metadata) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    if (_uploadedUrl != null) {
      metadata['url'] = _uploadedUrl;
    }

    try {
      final api = ref.read(apiClientProvider);
      final entity = await api.createEntity(
        type: 'document',
        name: name,
        body: _bodyController.text.isEmpty ? null : _bodyController.text,
        metadata: metadata,
      );

      // Link to task if selected (task references document)
      if (_selectedTaskId != null) {
        await api.createRelationship(
          relTypeKey: 'references',
          sourceEntityId: _selectedTaskId!,
          targetEntityId: entity.id,
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
