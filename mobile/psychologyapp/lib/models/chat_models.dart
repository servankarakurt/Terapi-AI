class ChatResult {
  ChatResult({
    required this.reply,
    required this.sessionId,
    required this.isCrisis,
  });

  final String reply;
  final int? sessionId;
  final bool isCrisis;
}

class MobileChatResult {
  MobileChatResult({
    required this.reply,
    required this.transcript,
    required this.audioBase64,
    required this.sessionId,
    required this.ttsError,
  });

  final String reply;
  final String transcript;
  final String? audioBase64;
  final int? sessionId;
  final String? ttsError;
}

class ChatSession {
  ChatSession({
    required this.id,
    required this.title,
    required this.isVoiceSession,
    required this.createdAt,
  });

  final int id;
  final String title;
  final bool isVoiceSession;
  final String createdAt;

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Yeni Sohbet',
      isVoiceSession: (json['is_voice_session'] == true || json['is_voice_session'] == 1 || json['is_voice_session'] == '1'),
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

