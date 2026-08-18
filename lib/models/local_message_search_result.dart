import 'message_model.dart';

class LocalMessageSearchResult {
  final String roomId;
  final ChatMessage message;

  const LocalMessageSearchResult({required this.roomId, required this.message});
}
