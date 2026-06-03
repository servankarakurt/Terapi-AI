import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/config/app_config.dart';
import '../models/auth_models.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

class ProfileRegisterScreen extends StatefulWidget {
  const ProfileRegisterScreen({super.key});

  @override
  State<ProfileRegisterScreen> createState() => _ProfileRegisterScreenState();
}

class _ProfileRegisterScreenState extends State<ProfileRegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _professionController = TextEditingController();
  final _cityController = TextEditingController();
  final _api = ApiService();
  late final GoogleSignIn _googleSignIn;
  late final AnimationController _pulseController;

  String _gender = 'Belirtilmedi';
  bool _isLoading = false;
  bool _isLoginMode = false;
  bool _showForm = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _googleSignIn = AppConfig.googleServerClientId.isEmpty
        ? GoogleSignIn(scopes: const ['email', 'profile'])
        : GoogleSignIn(
            scopes: const ['email', 'profile'],
            serverClientId: AppConfig.googleServerClientId,
          );
    _tryRestoreSession();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _ageController.dispose();
    _professionController.dispose();
    _cityController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _tryRestoreSession() async {
    setState(() => _isLoading = true);
    try {
      await _api.initSessionFromStorage();
      final user = _api.currentUser;
      if (user == null || user.id == null) return;
      final refreshed = await _api.getUserProfile(user.id!);
      if (!mounted) return;
      _goToChat(refreshed);
    } catch (_) {
      await _api.logout();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToChat(AuthUser authUser) {
    Navigator.of(context).pushReplacementNamed(
      ChatScreen.routeName,
      arguments: ChatArgs(
        userId: authUser.id,
        userName: authUser.displayName,
        age: authUser.age,
        gender: authUser.gender,
        profession: authUser.profession,
        city: authUser.city,
        maritalStatus: authUser.maritalStatus,
        childCount: authUser.childCount,
        chronicIllness: authUser.chronicIllness,
        traumaSummary: authUser.traumaSummary,
      ),
    );
  }

  Future<void> _registerAndContinue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final username = _usernameController.text.trim();
    final displayName = _displayNameController.text.trim();
    final finalDisplayName = displayName.isEmpty ? username : displayName;

    try {
      final authResult = await _api.register(
        username: username,
        password: _passwordController.text,
        displayName: finalDisplayName,
        age: int.tryParse(_ageController.text.trim()) ?? 25,
        gender: _gender,
        profession: _professionController.text.trim(),
        city: _cityController.text.trim(),
      );
      if (!mounted) return;
      _goToChat(authResult.user);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kayıt başarısız: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginAndContinue() async {
    if (_usernameController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kullanıcı adı ve şifre zorunlu'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      final authResult = await _api.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      _goToChat(authResult.user);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Giriş başarısız: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _googleLoginAndContinue() async {
    setState(() => _isLoading = true);
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        setState(() => _isLoading = false);
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google idToken alınamadı. Google OAuth ayarlarını kontrol et.');
      }

      final authResult = await _api.loginWithGoogle(idToken: idToken);
      if (!mounted) return;
      _goToChat(authResult.user);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google girişi başarısız: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F1026), // Ultra deep night blue
              Color(0xFF1E1F3B), // Deep navy blue
              Color(0xFF323673), // Royal blue-indigo
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 550),
                switchInCurve: Curves.easeInOutCubic,
                switchOutCurve: Curves.easeInOutCubic,
                transitionBuilder: (child, animation) {
                  final slide = Tween<Offset>(
                    begin: const Offset(0.0, 0.15),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: slide,
                      child: child,
                    ),
                  );
                },
                child: _showForm ? _buildFormCard() : _buildWelcomeCard(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Column(
      key: const ValueKey('WelcomeCard'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final scale = 1.0 + (_pulseController.value * 0.08);
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF6C63FF).withValues(alpha: 0.35),
                      const Color(0xFF6C63FF).withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.5),
                          blurRadius: 28,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.psychology,
                      color: Colors.white,
                      size: 58,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 36),
        const Text(
          'Terapi-AI',
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Bilişsel Davranışçı Terapi (BDT) uzmanı empatik yapay zekanız ile zihinsel rahatlama yolculuğuna başlayın.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.75),
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 48),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 6,
              shadowColor: const Color(0xFF6C63FF).withValues(alpha: 0.4),
            ),
            onPressed: () {
              setState(() {
                _isLoginMode = true;
                _showForm = true;
              });
            },
            icon: const Icon(Icons.login),
            label: const Text(
              'Giriş Yap',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.white.withValues(alpha: 0.04),
            ),
            onPressed: () {
              setState(() {
                _isLoginMode = false;
                _showForm = true;
              });
            },
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text(
              'Kayıt Ol',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildFormCard() {
    return ClipRRect(
      key: const ValueKey('FormCard'),
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06), // Yarı saydam glassmorphism
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showForm = false;
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Geri Dön',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.psychology,
                        color: Color(0xFF90CAF9),
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isLoginMode ? 'Giriş Yap' : 'Kayıt Ol',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _isLoginMode
                      ? 'Hesabınıza bağlanarak kaldığınız yerden devam edin.'
                      : 'Kişisel detaylarınızı belirleyin, size özel terapi sunalım.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: const Color(0xFF6C63FF),
                    selectedForegroundColor: Colors.white,
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  segments: const [
                    ButtonSegment<bool>(
                      value: false,
                      icon: Icon(Icons.person_add_alt_1),
                      label: Text('Kayıt', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      icon: Icon(Icons.login),
                      label: Text('Giriş', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                  selected: {_isLoginMode},
                  onSelectionChanged: (selection) {
                    setState(() => _isLoginMode = selection.first);
                  },
                ),
                const SizedBox(height: 24),
                _buildInput(_usernameController, 'Kullanıcı Adı', Icons.person, isRequired: true),
                _buildInput(_passwordController, 'Şifre', Icons.lock, obscureText: true, isRequired: true),
                if (!_isLoginMode) ...[
                  _buildInput(_displayNameController, 'Görünen İsim (İsteğe Bağlı)', Icons.badge, isRequired: false),
                  _buildInput(_ageController, 'Yaş (İsteğe Bağlı)', Icons.calendar_today, keyboardType: TextInputType.number, isRequired: false),
                  _buildInput(_professionController, 'Meslek (İsteğe Bağlı)', Icons.work, isRequired: false),
                  _buildInput(_cityController, 'Şehir (İsteğe Bağlı)', Icons.location_city, isRequired: false),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: _gender,
                    dropdownColor: const Color(0xFF1E1F3B),
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.wc, color: Colors.white70),
                      labelText: 'Cinsiyet (İsteğe Bağlı)',
                      labelStyle: const TextStyle(color: Colors.white60),
                      floatingLabelStyle: const TextStyle(color: Color(0xFF90CAF9), fontWeight: FontWeight.w600),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.04),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF90CAF9), width: 2),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Belirtilmedi', child: Text('Belirtilmedi')),
                      DropdownMenuItem(value: 'Kadın', child: Text('Kadın')),
                      DropdownMenuItem(value: 'Erkek', child: Text('Erkek')),
                    ],
                    onChanged: (value) => setState(() => _gender = value ?? 'Belirtilmedi'),
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      shadowColor: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                    ),
                    onPressed: _isLoading
                        ? null
                        : () {
                            if (_isLoginMode) {
                              _loginAndContinue();
                            } else {
                              _registerAndContinue();
                            }
                          },
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            _isLoginMode ? 'Giriş Yap' : 'Kaydet ve Sohbete Geç',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                    ),
                    onPressed: _isLoading ? null : _googleLoginAndContinue,
                    icon: const Icon(Icons.g_mobiledata, size: 30, color: Colors.redAccent),
                    label: const Text(
                      'Google ile Devam Et',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        validator: (value) {
          if (isRequired && (value == null || value.trim().isEmpty)) {
            return '$label zorunlu';
          }
          return null;
        },
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white70),
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white60),
          floatingLabelStyle: const TextStyle(color: Color(0xFF90CAF9), fontWeight: FontWeight.w600),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.04),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF90CAF9), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.redAccent, width: 2),
          ),
        ),
      ),
    );
  }
}
