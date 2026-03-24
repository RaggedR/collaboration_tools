import 'package:flutter/material.dart';
import '../../api/models/entity.dart';
import '../../widgets/shared/doc_type_badge.dart';
import '../../widgets/shared/entity_card.dart';

/// Document list section on My Page.
class MyDocumentsSection extends StatelessWidget {
  final List<Entity> documents;
  final void Function(Entity doc)? onDocumentTap;

  const MyDocumentsSection({
    super.key,
    required this.documents,
    this.onDocumentTap,
  });

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No documents'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Documents',
              style: Theme.of(context).textTheme.titleMedium),
        ),
        ...documents.map((doc) {
          final docType = doc.metadata['doc_type'] as String?;
          return EntityCard(
            entity: doc,
            onTap: () => onDocumentTap?.call(doc),
            trailing:
                docType != null ? DocTypeBadge(docType: docType) : null,
          );
        }),
      ],
    );
  }
}
