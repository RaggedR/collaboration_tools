class RelType {
  final String key;
  final String forwardLabel;
  final String reverseLabel;
  final List<String> sourceTypes;
  final List<String> targetTypes;
  final bool symmetric;
  final Map<String, dynamic>? metadataSchema;

  RelType({
    required this.key,
    required this.forwardLabel,
    required this.reverseLabel,
    required this.sourceTypes,
    required this.targetTypes,
    this.symmetric = false,
    this.metadataSchema,
  });

  factory RelType.fromJson(Map<String, dynamic> json) => RelType(
        key: json['key'] as String,
        forwardLabel: json['forward_label'] as String,
        reverseLabel: json['reverse_label'] as String,
        sourceTypes: (json['source_types'] as List).cast<String>(),
        targetTypes: (json['target_types'] as List).cast<String>(),
        symmetric: (json['symmetric'] as bool?) ?? false,
        metadataSchema: json['metadata_schema'] as Map<String, dynamic>?,
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'forward_label': forwardLabel,
        'reverse_label': reverseLabel,
        'source_types': sourceTypes,
        'target_types': targetTypes,
        'symmetric': symmetric,
        if (metadataSchema != null) 'metadata_schema': metadataSchema,
      };
}
