class ApiError {
  final String code;
  final String message;
  final String? detail;

  const ApiError({required this.code, required this.message, this.detail});

  factory ApiError.fromResponse(Map<String, dynamic> data) {
    final rawCode = data['error']?.toString();
    final message = data['error_message']?.toString();
    return ApiError(
      code: rawCode == null || rawCode.isEmpty ? 'UNKNOWN_ERROR' : rawCode,
      message: message == null || message.isEmpty
          ? (rawCode ?? 'Unknown error')
          : message,
      detail: data['error_detail']?.toString(),
    );
  }

  bool get isTokenExpired =>
      code == 'AUTH_TOKEN_EXPIRED' || code == 'token_expired';

  @override
  String toString() => '$code: $message';
}
