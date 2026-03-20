import 'validation_result.dart';

export 'validation_result.dart';

class MetadataValidator {
  /// Validates metadata against a JSON Schema subset.
  /// Returns valid if schema is null (no validation applied).
  static ValidationResult validate(
    Map<String, dynamic>? schema,
    Map<String, dynamic> metadata,
  ) {
    if (schema == null) return ValidationResult.valid();

    final errors = <String>[];

    // Check required fields
    final required = schema['required'];
    if (required is List) {
      for (final field in required) {
        if (!metadata.containsKey(field)) {
          errors.add("Missing required field: '$field'");
        }
      }
    }

    // Validate each provided field against property definitions
    final properties = schema['properties'] as Map<String, dynamic>?;
    if (properties != null) {
      for (final entry in metadata.entries) {
        final fieldSchema = properties[entry.key];
        if (fieldSchema is! Map<String, dynamic>) continue;

        final fieldErrors = _validateField(entry.key, entry.value, fieldSchema);
        errors.addAll(fieldErrors);
      }
    }

    return ValidationResult(errors);
  }

  static List<String> _validateField(
    String fieldName,
    dynamic value,
    Map<String, dynamic> fieldSchema,
  ) {
    final errors = <String>[];
    final expectedType = fieldSchema['type'] as String?;

    // Type checking
    if (expectedType != null && !_matchesType(value, expectedType)) {
      errors.add("Field '$fieldName' must be of type '$expectedType'");
      return errors; // Skip further checks if type is wrong
    }

    // Enum validation
    final enumValues = fieldSchema['enum'];
    if (enumValues is List && !enumValues.contains(value)) {
      errors.add(
          "Field '$fieldName' must be one of: ${enumValues.join(', ')}");
    }

    // Format validation
    final format = fieldSchema['format'] as String?;
    if (format == 'date' && value is String) {
      if (!_isValidDate(value)) {
        errors.add("Field '$fieldName' must be a valid date (YYYY-MM-DD)");
      }
    }

    // Array item validation
    if (expectedType == 'array' && value is List) {
      final itemSchema = fieldSchema['items'] as Map<String, dynamic>?;
      if (itemSchema != null) {
        final itemType = itemSchema['type'] as String?;
        if (itemType != null) {
          for (var i = 0; i < value.length; i++) {
            if (!_matchesType(value[i], itemType)) {
              errors.add(
                  "Field '$fieldName[$i]' must be of type '$itemType'");
            }
          }
        }
      }
    }

    return errors;
  }

  static bool _matchesType(dynamic value, String type) {
    switch (type) {
      case 'string':
        return value is String;
      case 'number':
        return value is num;
      case 'integer':
        return value is int;
      case 'boolean':
        return value is bool;
      case 'array':
        return value is List;
      case 'object':
        return value is Map;
      default:
        return true;
    }
  }

  static bool _isValidDate(String value) {
    // Must match YYYY-MM-DD exactly — no time component
    final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!dateRegex.hasMatch(value)) return false;

    // Verify it parses to a real date
    try {
      final parts = value.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      final date = DateTime(year, month, day);
      return date.year == year && date.month == month && date.day == day;
    } catch (_) {
      return false;
    }
  }
}
