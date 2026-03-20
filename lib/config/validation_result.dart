class ValidationResult {
  final bool isValid;
  final List<String> errors;

  ValidationResult.valid()
      : isValid = true,
        errors = const [];

  ValidationResult.invalid(this.errors) : isValid = false;

  factory ValidationResult(List<String> errors) {
    if (errors.isEmpty) return ValidationResult.valid();
    return ValidationResult.invalid(errors);
  }
}
