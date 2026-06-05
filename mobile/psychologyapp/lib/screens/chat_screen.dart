import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config/app_config.dart';
import '../main.dart';
import '../models/auth_models.dart';
import '../models/chat_models.dart';
import '../services/api_service.dart';
import 'profile_screen.dart';


class ChatArgs {
  ChatArgs({
    required this.userId,
    required this.userName,
    required this.age,
    required this.gender,
    required this.profession,
    required this.city,
    required this.maritalStatus,
    required this.childCount,
    required this.chronicIllness,
    required this.traumaSummary,
  });

  final int? userId;
  final String userName;
  final int age;
  final String gender;
  final String profession;
  final String city;
  final String maritalStatus;
  final int childCount;
  final String chronicIllness;
  final String traumaSummary;
}

class ChatMessage {
  ChatMessage({
    required this.text,
    required this.isUser,
    this.isVoice = false,
    required this.timestamp,
  });

  final String text;
  final bool isUser;
  final bool isVoice;
  final DateTime timestamp;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  static const routeName = '/chat';

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final _api = ApiService();
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  late final AnimationController _pulseController;
  late final AnimationController _waveController;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  Timer? _silenceTimer;

  bool _isRecording = false;
  bool _isVoiceProcessing = false;
  bool _isSpeaking = false;
  bool _isStoppingRecording = false;
  int? _sessionId;
  ChatArgs? _chatArgs;
  DateTime? _recordingStartedAt;
  DateTime? _lastVoiceDetectedAt;

  // New variables for dual-mode
  bool _isVoiceMode = true;
  final List<ChatMessage> _messages = [];
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  String _selectedVoiceId = AppConfig.elevenLabsFemaleVoiceId;
  List<ChatSession> _sessions = [];
  bool _isLoadingSessions = false;

  Future<void> _makeEmergencyCall() async {
    final Uri telUri = Uri.parse('tel:112');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ KRİZ DURUMU ALGILANDI! 112 Acil Çağrı Merkezi aranıyor...'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 4),
        ),
      );
    }
    
    await Future.delayed(const Duration(milliseconds: 1000));
    
    try {
      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Arama başlatılamadı. Lütfen manuel olarak 112\'yi arayın!'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Arama Hatası: $e. Lütfen 112\'yi doğrudan arayın!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }



  static const double _speechThresholdDb = -45;
  static const Duration _silenceTimeout = Duration(seconds: 5);
  static const Duration _minRecordingBeforeAutoStop = Duration(milliseconds: 3000);

  @override
  void initState() {
    super.initState();
    _loadVoicePreference();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isSpeaking = state == PlayerState.playing;
      });
    });
  }


  @override
  void dispose() {
    _silenceTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _pulseController.dispose();
    _waveController.dispose();
    _recorder.dispose();
    _player.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _toggleVoice(ChatArgs args) async {
    if (_isVoiceProcessing) return;

    if (_isSpeaking) {
      await _player.stop();
      if (!mounted) return;
      setState(() => _isSpeaking = false);
      await _startRecording();
      return;
    }

    if (!_isRecording) {
      await _startRecording();
      return;
    }

    await _stopAndSendRecording(args, isAutoStop: false);
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mikrofon izni gerekli.')),
      );
      return;
    }

    await _amplitudeSubscription?.cancel();
    _silenceTimer?.cancel();

    final tempDir = await getTemporaryDirectory();
    final path = '${tempDir.path}/temp_record.m4a';

    await _recorder.start(const RecordConfig(), path: path);
    if (!mounted) return;
    final now = DateTime.now();
    setState(() {
      _isRecording = true;
      _recordingStartedAt = now;
      _lastVoiceDetectedAt = now;
    });

    _amplitudeSubscription = _recorder.onAmplitudeChanged(const Duration(milliseconds: 250)).listen(
      (amp) {
        if (!_isRecording) return;
        if (amp.current > _speechThresholdDb) {
          _lastVoiceDetectedAt = DateTime.now();
        }
      },
    );

    _silenceTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (!_isRecording || _isStoppingRecording) return;
      final startedAt = _recordingStartedAt;
      final lastVoiceAt = _lastVoiceDetectedAt;
      if (startedAt == null || lastVoiceAt == null) return;

      final elapsed = DateTime.now().difference(startedAt);
      final silentFor = DateTime.now().difference(lastVoiceAt);
      if (elapsed >= _minRecordingBeforeAutoStop && silentFor >= _silenceTimeout) {
        _stopAndSendRecording(_chatArgs!, isAutoStop: true);
      }
    });
  }

  Future<void> _stopAndSendRecording(ChatArgs args, {required bool isAutoStop}) async {
    if (_isStoppingRecording) return;
    _isStoppingRecording = true;

    _silenceTimer?.cancel();
    _silenceTimer = null;
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    final filePath = await _recorder.stop();
    if (mounted) {
      setState(() {
        _isRecording = false;
      });
    }
    if (filePath == null) {
      _isStoppingRecording = false;
      return;
    }

    final audioFile = File(filePath);
    if (!audioFile.existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ses kaydı bulunamadı.')),
        );
      }
      _isStoppingRecording = false;
      return;
    }

    if (mounted) {
      setState(() => _isVoiceProcessing = true);
    }
    final hadNoSession = _sessionId == null;
    try {
      final response = await _api.sendVoiceMessage(

        audioFile: audioFile,
        userName: args.userName,
        age: args.age,
        gender: args.gender,
        profession: args.profession,
        city: args.city,
        maritalStatus: args.maritalStatus,
        childCount: args.childCount,
        chronicIllness: args.chronicIllness,
        traumaSummary: args.traumaSummary,
        sessionId: _sessionId,
        voiceId: _selectedVoiceId,
      );


      setState(() {
        _sessionId = response.sessionId ?? _sessionId;
        if (response.transcript.isNotEmpty) {
          _messages.add(ChatMessage(
            text: response.transcript,
            isUser: true,
            isVoice: true,
            timestamp: DateTime.now(),
          ));
        }
        if (response.reply.isNotEmpty) {
          _messages.add(ChatMessage(
            text: response.reply,
            isUser: false,
            isVoice: true,
            timestamp: DateTime.now(),
          ));
        }
      });
      _scrollToBottom();

      String? audioBase64 = response.audioBase64;
      if ((audioBase64 == null || audioBase64.isEmpty) && response.reply.isNotEmpty) {
        // Fallback: local ElevenLabs Text-to-Speech synthesis from Flutter!
        audioBase64 = await _api.generateTts(text: response.reply, voiceId: _selectedVoiceId);
      }


      if (audioBase64 != null && audioBase64.isNotEmpty) {
        final bytes = base64Decode(audioBase64);
        await _player.stop();
        await _player.play(BytesSource(bytes), volume: 1.0);
      } else if (response.ttsError != null && response.ttsError!.isNotEmpty && mounted) {
        String cleanError = response.ttsError!;
        if (cleanError.contains('ElevenLabs') || cleanError.contains('401') || cleanError.contains('unusual_activity')) {
          cleanError = 'Seslendirme servis limitine ulaşıldı veya VPN kullanılıyor olabilir. Lütfen yukarıdan "Yazılı Sohbet" moduna geçip devam edin.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(cleanError),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      if (isAutoStop && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sessizlik algılandı, kayıt otomatik gönderildi.')),
        );
      }
      if (hadNoSession && _sessionId != null) {
        _loadSessions();
      }
      if (response.isCrisis) {
        _makeEmergencyCall();
      }
    } catch (e) {

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sesli işlem hatası: $e')),
      );
    } finally {
      if (mounted) setState(() => _isVoiceProcessing = false);
      _isStoppingRecording = false;
    }
  }

  Future<void> _sendTextMessage(ChatArgs args) async {
    final query = _textController.text.trim();
    if (query.isEmpty) return;

    _textController.clear();

    setState(() {
      _messages.add(ChatMessage(
        text: query,
        isUser: true,
        isVoice: false,
        timestamp: DateTime.now(),
      ));
      _isVoiceProcessing = true;
    });
    _scrollToBottom();

    try {
      final response = await _api.sendChatMessage(
        query: query,
        sessionId: _sessionId,
        userName: args.userName,
        age: args.age,
        gender: args.gender,
        profession: args.profession,
        city: args.city,
        maritalStatus: args.maritalStatus,
        childCount: args.childCount,
        chronicIllness: args.chronicIllness,
        traumaSummary: args.traumaSummary,
      );

      final hadNoSession = _sessionId == null;
      setState(() {
        _sessionId = response.sessionId ?? _sessionId;
        _messages.add(ChatMessage(
          text: response.reply,
          isUser: false,
          isVoice: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
      if (hadNoSession && _sessionId != null) {
        _loadSessions();
      }
      if (response.isCrisis) {
        _makeEmergencyCall();
      }

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata oluştu: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isVoiceProcessing = false);
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  String get _statusText {
    if (_isRecording) return 'Dinliyorum...';
    if (_isVoiceProcessing) return 'Düşünüyorum...';
    if (_isSpeaking) return 'Konuşuyorum... Dokunursan keserim.';
    return 'Mikrofona dokun ve konuş';
  }

  Color get _orbColor {
    if (_isRecording) return const Color(0xFF00BCD4);
    if (_isVoiceProcessing) return const Color(0xFFFFB300);
    if (_isSpeaking) return const Color(0xFF7C4DFF);
    return const Color(0xFF5C6BC0);
  }

  IconData get _centerIcon {
    if (_isRecording) return Icons.graphic_eq;
    if (_isVoiceProcessing) return Icons.psychology_alt;
    if (_isSpeaking) return Icons.volume_up;
    return Icons.mic_none;
  }

  @override
  Widget build(BuildContext context) {
    _chatArgs ??= (ModalRoute.of(context)?.settings.arguments as ChatArgs?) ??
        ChatArgs(
          userId: null,
          userName: 'Kullanıcı',
          age: 0,
          gender: 'Belirtilmedi',
          profession: '',
          city: '',
          maritalStatus: 'Belirtilmedi',
          childCount: 0,
          chronicIllness: '',
          traumaSummary: '',
        );
    final safeArgs = _chatArgs!;

    return Scaffold(
      drawer: _buildDrawer(),
      onDrawerChanged: (isOpened) {
        if (isOpened) {
          _loadSessions();
        }
      },
      appBar: AppBar(
        title: Text('Merhaba, ${safeArgs.userName}'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              themeNotifier.value == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
            ),
            tooltip: 'Tema Değiştir',
            onPressed: _toggleTheme,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.record_voice_over),
            tooltip: 'Terapist Sesi',
            onSelected: _changeVoice,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: AppConfig.elevenLabsFemaleVoiceId,
                child: Row(
                  children: [
                    Icon(
                      Icons.female,
                      color: _selectedVoiceId == AppConfig.elevenLabsFemaleVoiceId
                          ? const Color(0xFF6C63FF)
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Kadın Terapist (Sarah)',
                      style: TextStyle(
                        color: _selectedVoiceId == AppConfig.elevenLabsFemaleVoiceId
                            ? const Color(0xFF6C63FF)
                            : null,
                        fontWeight: _selectedVoiceId == AppConfig.elevenLabsFemaleVoiceId
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: AppConfig.elevenLabsMaleVoiceId,
                child: Row(
                  children: [
                    Icon(
                      Icons.male,
                      color: _selectedVoiceId == AppConfig.elevenLabsMaleVoiceId
                          ? const Color(0xFF6C63FF)
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Erkek Terapist (Brian)',
                      style: TextStyle(
                        color: _selectedVoiceId == AppConfig.elevenLabsMaleVoiceId
                            ? const Color(0xFF6C63FF)
                            : null,
                        fontWeight: _selectedVoiceId == AppConfig.elevenLabsMaleVoiceId
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profilim',
            onPressed: safeArgs.userId == null
                ? null
                : () async {
                    AuthUser initialProfile;
                    try {
                      initialProfile = await _api.getUserProfile(safeArgs.userId!);
                    } catch (_) {
                      initialProfile = AuthUser(
                        id: safeArgs.userId,
                        displayName: safeArgs.userName,
                        age: safeArgs.age,
                        gender: safeArgs.gender,
                        profession: safeArgs.profession,
                        city: safeArgs.city,
                        maritalStatus: 'Belirtilmedi',
                        childCount: 0,
                        chronicIllness: '',
                        traumaSummary: '',
                        avatar: 'default',
                      );
                    }

                    if (!context.mounted) return;
                    final updated = await Navigator.of(context).push<AuthUser>(
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(
                          userId: safeArgs.userId!,
                          initialUser: initialProfile,
                        ),
                      ),
                    );
                    if (updated == null || !mounted) return;
                    setState(() {
                      _chatArgs = ChatArgs(
                        userId: updated.id,
                        userName: updated.displayName,
                        age: updated.age,
                        gender: updated.gender,
                        profession: updated.profession,
                        city: updated.city,
                        maritalStatus: updated.maritalStatus,
                        childCount: updated.childCount,
                        chronicIllness: updated.chronicIllness,
                        traumaSummary: updated.traumaSummary,
                      );
                    });
                  },
          ),
        ],
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment<bool>(
                  value: true,
                  icon: Icon(Icons.mic),
                  label: Text('Sesli Sohbet'),
                ),
                ButtonSegment<bool>(
                  value: false,
                  icon: Icon(Icons.keyboard),
                  label: Text('Yazılı Sohbet'),
                ),
              ],
              selected: {_isVoiceMode},
              onSelectionChanged: (selection) {
                setState(() {
                  _isVoiceMode = selection.first;
                });
                if (!_isVoiceMode) {
                  _scrollToBottom();
                }
              },
            ),
          ),
          Expanded(
            child: _isVoiceMode
                ? _buildVoiceInterface()
                : _buildTextInterface(safeArgs),
          ),
          if (_isVoiceMode)
            _buildVoiceActionArea(safeArgs)
          else
            _buildTextActionArea(safeArgs),
        ],
      ),
    );
  }

  Widget _buildVoiceInterface() {
    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseController, _waveController]),
        builder: (context, _) {
          final pulse = 1 + (_pulseController.value * 0.14);
          final auraScale = (_isRecording || _isSpeaking || _isVoiceProcessing) ? pulse : 1.0;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.scale(
                scale: auraScale,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _orbColor.withValues(alpha: 0.18),
                        _orbColor.withValues(alpha: 0.04),
                      ],
                    ),
                  ),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      width: (_isRecording || _isSpeaking) ? 140 : 125,
                      height: (_isRecording || _isSpeaking) ? 140 : 125,
                      decoration: BoxDecoration(
                        color: _orbColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _orbColor.withValues(alpha: 0.50),
                            blurRadius: 28,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(_centerIcon, color: Colors.white, size: 44),
                          if (_isRecording || _isSpeaking)
                            _FakeWaveformBars(progress: _waveController.value),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Text(
                _statusText,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVoiceActionArea(ChatArgs safeArgs) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isVoiceProcessing ? null : () => _toggleVoice(safeArgs),
            icon: _isVoiceProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_isRecording
                    ? Icons.stop_circle
                    : _isSpeaking
                        ? Icons.stop
                        : Icons.mic),
            label: Text(
              _isRecording
                  ? 'Kaydi Bitir ve Gonder'
                  : _isSpeaking
                      ? 'Botu Kes ve Konus'
                      : 'Konusmaya Basla',
            ),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        ),
      ),
    );
  }

  Widget _buildTextInterface(ChatArgs safeArgs) {
    if (_messages.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.psychology_alt,
                size: 80,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Merhaba, ${safeArgs.userName}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ben yapay zeka destekli psikoloğunuz. Bugün kendinizi nasıl hissediyorsunuz? Aşağıdan bana yazabilir veya dilediğiniz an üst kısımdan Sesli Sohbet\'e geçebilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return _buildMessageBubble(msg);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final theme = Theme.of(context);
    final isUser = msg.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primary
              : theme.colorScheme.secondaryContainer.withValues(alpha: 0.7),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.isVoice) ...[
              Padding(
                padding: const EdgeInsets.only(top: 2.0, right: 6.0),
                child: Icon(
                  Icons.mic,
                  size: 15,
                  color: isUser ? Colors.white70 : Colors.grey,
                ),
              ),
            ],
            Flexible(
              child: Text(
                msg.text,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 15.5,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextActionArea(ChatArgs safeArgs) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.mic_none, color: Colors.grey),
                      onPressed: () {
                        setState(() {
                          _isVoiceMode = true;
                        });
                      },
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: _textController,
                        textInputAction: TextInputAction.send,
                        onFieldSubmitted: (_) => _sendTextMessage(safeArgs),
                        style: const TextStyle(color: Colors.black87),
                        decoration: const InputDecoration(
                          hintText: 'Bir mesaj yazın...',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            FloatingActionButton(
              mini: true,
              elevation: 2,
              backgroundColor: Theme.of(context).colorScheme.primary,
              onPressed: () => _sendTextMessage(safeArgs),
              child: _isVoiceProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Future<void> _loadVoicePreference() async {
    final savedVoice = await const FlutterSecureStorage().read(key: 'selected_voice_id');
    if (savedVoice != null && savedVoice.isNotEmpty) {
      if (mounted) {
        setState(() {
          _selectedVoiceId = savedVoice;
        });
      }
    }
  }

  Future<void> _changeVoice(String voiceId) async {
    setState(() {
      _selectedVoiceId = voiceId;
    });
    await const FlutterSecureStorage().write(key: 'selected_voice_id', value: voiceId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(voiceId == AppConfig.elevenLabsFemaleVoiceId
              ? 'Terapist sesi Kadın (Sarah) olarak güncellendi.'
              : 'Terapist sesi Erkek (Brian) olarak güncellendi.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleTheme() async {
    final newTheme = themeNotifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    themeNotifier.value = newTheme;
    await const FlutterSecureStorage().write(
      key: 'theme_mode',
      value: newTheme == ThemeMode.light ? 'light' : 'dark',
    );
  }

  Future<void> _loadSessions() async {
    if (_chatArgs?.userId == null) return;
    setState(() => _isLoadingSessions = true);
    try {
      final sessions = await _api.getSessions(_chatArgs!.userId!);
      setState(() {
        _sessions = sessions;
      });
    } catch (e) {
      print('Error loading sessions: $e');
    } finally {
      setState(() => _isLoadingSessions = false);
    }
  }

  Future<void> _selectSession(int sessionId) async {
    setState(() {
      _sessionId = sessionId;
      _messages.clear();
      _isVoiceProcessing = true;
    });
    Navigator.of(context).pop();
    try {
      final history = await _api.getSessionHistory(sessionId);
      setState(() {
        for (final msg in history) {
          final isUser = msg['role'] == 'user';
          _messages.add(ChatMessage(
            text: msg['content']?.toString() ?? '',
            isUser: isUser,
            isVoice: msg['audio_url'] != null || (msg['content']?.toString().length ?? 0) > 100,
            timestamp: DateTime.tryParse(msg['created_at']?.toString() ?? '') ?? DateTime.now(),
          ));
        }
      });
      _scrollToBottom();
    } catch (e) {
      _showError('Geçmiş yüklenirken hata oluştu: $e');
    } finally {
      setState(() => _isVoiceProcessing = false);
    }
  }

  void _startNewSession() {
    setState(() {
      _sessionId = null;
      _messages.clear();
    });
    Navigator.of(context).pop();
  }

  Future<void> _deleteSession(int sessionId) async {
    try {
      await _api.deleteSession(sessionId);
      if (_sessionId == sessionId) {
        setState(() {
          _sessionId = null;
          _messages.clear();
        });
      }
      await _loadSessions();
    } catch (e) {
      _showError('Oturum silinirken hata: $e');
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: themeNotifier.value == ThemeMode.dark ? const Color(0xFF0F1026) : Colors.white,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: themeNotifier.value == ThemeMode.dark
                    ? [const Color(0xFF1E1F3B), const Color(0xFF323673)]
                    : [const Color(0xFF5C6BC0), const Color(0xFF7C89CC)],
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white24,
                  child: const Icon(Icons.psychology, color: Colors.white, size: 36),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _chatArgs?.userName ?? 'Kullanıcı',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Premium Terapist',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.add, color: themeNotifier.value == ThemeMode.dark ? Colors.white70 : Colors.black87),
            title: Text(
              'Yeni Sohbet Başlat',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: themeNotifier.value == ThemeMode.dark ? Colors.white : Colors.black87,
              ),
            ),
            onTap: _startNewSession,
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Geçmiş Sohbetler',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: _isLoadingSessions
                ? const Center(child: CircularProgressIndicator())
                : _sessions.isEmpty
                    ? Center(
                        child: Text(
                          'Geçmiş sohbet bulunamadı.',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: _sessions.length,
                        itemBuilder: (context, index) {
                          final session = _sessions[index];
                          final isCurrent = _sessionId == session.id;
                          return ListTile(
                            selected: isCurrent,
                            selectedTileColor: themeNotifier.value == ThemeMode.dark
                                ? const Color(0xFF6C63FF).withValues(alpha: 0.15)
                                : const Color(0xFF6C63FF).withValues(alpha: 0.08),
                            leading: Icon(
                              session.isVoiceSession ? Icons.mic : Icons.chat,
                              color: isCurrent ? const Color(0xFF6C63FF) : Colors.grey,
                            ),
                            title: Text(
                              session.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isCurrent
                                    ? const Color(0xFF6C63FF)
                                    : (themeNotifier.value == ThemeMode.dark ? Colors.white70 : Colors.black87),
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              color: Colors.redAccent.withValues(alpha: 0.7),
                              onPressed: () => _deleteSession(session.id),
                            ),
                            onTap: () => _selectSession(session.id),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _FakeWaveformBars extends StatelessWidget {

  const _FakeWaveformBars({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final value = math.sin((progress * 2 * math.pi) + (i * 0.55)).abs();
          final height = 10 + (value * 26);
          return Container(
            width: 6,
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(8),
            ),
          );
        }),
      ),
    );
  }
}
