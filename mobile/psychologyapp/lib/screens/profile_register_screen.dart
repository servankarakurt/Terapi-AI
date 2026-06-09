import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart' as fba;

import '../core/config/app_config.dart';
import '../models/auth_models.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

enum AuthMethod { email, phone }


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
  final _auth = fba.FirebaseAuth.instance;

  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  String? _verificationId;
  bool _otpSent = false;
  AuthMethod _authMethod = AuthMethod.email;

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
    _phoneController.dispose();
    _otpController.dispose();
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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _firebaseRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final email = _usernameController.text.trim();
    final password = _passwordController.text;
    final displayName = _displayNameController.text.trim();
    final finalDisplayName = displayName.isEmpty ? email.split('@')[0] : displayName;

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final fUser = credential.user;
      if (fUser == null) throw Exception('Firebase kullanıcı kaydı başarısız oldu.');

      final authResult = await _api.loginWithFirebase(
        uid: fUser.uid,
        displayName: finalDisplayName,
        email: email,
        isGuest: false,
      );

      final ageVal = int.tryParse(_ageController.text.trim()) ?? 0;
      if (ageVal > 0 || _gender != 'Belirtilmedi' || _professionController.text.isNotEmpty || _cityController.text.isNotEmpty) {
        final updatedProfile = authResult.user.copyWith(
          displayName: finalDisplayName,
          age: ageVal,
          gender: _gender,
          profession: _professionController.text.trim(),
          city: _cityController.text.trim(),
        );
        await _api.updateUserProfile(
          userId: authResult.user.id!,
          profile: updatedProfile,
        );
        if (!mounted) return;
        _goToChat(updatedProfile);
      } else {
        if (!mounted) return;
        _goToChat(authResult.user);
      }
    } on fba.FirebaseAuthException catch (e) {
      String msg = 'Kayıt başarısız';
      if (e.code == 'weak-password') {
        msg = 'Şifre en az 6 karakter olmalıdır.';
      } else if (e.code == 'email-already-in-use') {
        msg = 'Bu e-posta adresi zaten kullanımda.';
      } else if (e.code == 'invalid-email') {
        msg = 'Geçersiz e-posta adresi.';
      } else {
        msg = e.message ?? msg;
      }
      _showError(msg);
    } catch (e) {
      _showError('Kayıt hatası: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _firebaseEmailLogin() async {
    if (_usernameController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      _showError('E-posta ve şifre zorunlu');
      return;
    }
    setState(() => _isLoading = true);

    final email = _usernameController.text.trim();
    final password = _passwordController.text;

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final fUser = credential.user;
      if (fUser == null) throw Exception('Firebase girişi başarısız.');

      final authResult = await _api.loginWithFirebase(
        uid: fUser.uid,
        displayName: fUser.displayName,
        email: email,
        isGuest: false,
      );

      if (!mounted) return;
      _goToChat(authResult.user);
    } on fba.FirebaseAuthException catch (e) {
      String msg = 'Giriş başarısız';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        msg = 'Hatalı e-posta veya şifre.';
      } else {
        msg = e.message ?? msg;
      }
      _showError(msg);
    } catch (e) {
      _showError('Giriş hatası: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _firebaseGoogleLogin() async {
    setState(() => _isLoading = true);
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        setState(() => _isLoading = false);
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      final accessToken = auth.accessToken;
      if (idToken == null) {
        throw Exception('Google idToken alınamadı.');
      }

      final fba.AuthCredential credential = fba.GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );
      final firebaseUserCredential = await _auth.signInWithCredential(credential);
      final fUser = firebaseUserCredential.user;
      if (fUser == null) throw Exception('Google Firebase oturumu açılamadı.');

      final authResult = await _api.loginWithFirebase(
        uid: fUser.uid,
        displayName: fUser.displayName ?? account.displayName,
        email: fUser.email ?? account.email,
        isGuest: false,
      );

      if (!mounted) return;
      _goToChat(authResult.user);
    } catch (e) {
      _showError('Google girişi başarısız: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _firebaseGuestLogin() async {
    setState(() => _isLoading = true);
    try {
      final credential = await _auth.signInAnonymously();
      final fUser = credential.user;
      if (fUser == null) throw Exception('Misafir oturumu açılamadı.');

      final authResult = await _api.loginWithFirebase(
        uid: fUser.uid,
        displayName: 'Misafir Kullanıcı',
        isGuest: true,
      );

      if (!mounted) return;
      _goToChat(authResult.user);
    } catch (e) {
      _showError('Misafir girişi başarısız: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyPhoneNumber() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showError('Telefon numarası boş olamaz.');
      return;
    }
    setState(() => _isLoading = true);

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (fba.PhoneAuthCredential credential) async {
          final userCredential = await _auth.signInWithCredential(credential);
          final fUser = userCredential.user;
          if (fUser != null) {
            final authResult = await _api.loginWithFirebase(
              uid: fUser.uid,
              phone: phone,
              isGuest: false,
            );
            if (mounted) {
              setState(() => _isLoading = false);
              _goToChat(authResult.user);
            }
          }
        },
        verificationFailed: (fba.FirebaseAuthException e) {
          setState(() => _isLoading = false);
          _showError('Telefon doğrulaması başarısız: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _isLoading = false;
            _verificationId = verificationId;
            _otpSent = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Doğrulama kodu SMS ile gönderildi.'),
              backgroundColor: Colors.green,
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Hata oluştu: $e');
    }
  }

  Future<void> _signInWithPhoneNumber() async {
    final smsCode = _otpController.text.trim();
    if (smsCode.isEmpty || _verificationId == null) {
      _showError('Lütfen doğrulama kodunu girin.');
      return;
    }
    setState(() => _isLoading = true);

    try {
      final credential = fba.PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final fUser = userCredential.user;
      if (fUser == null) throw Exception('Oturum açma başarısız oldu.');

      final authResult = await _api.loginWithFirebase(
        uid: fUser.uid,
        phone: fUser.phoneNumber ?? _phoneController.text.trim(),
        isGuest: false,
      );

      if (!mounted) return;
      _goToChat(authResult.user);
    } catch (e) {
      _showError('Kod doğrulanamadı. Lütfen tekrar deneyin: $e');
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
            child: _authMethod == AuthMethod.phone
                ? _buildPhoneInputSection()
                : Column(
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
                            ? 'E-posta ve şifrenizle giriş yapın.'
                            : 'Kişisel detaylarınızı belirleyin, size özel terapi sunalım.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInput(_usernameController, 'E-posta Adresi', Icons.email, isRequired: true, keyboardType: TextInputType.emailAddress),
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
                                    _firebaseEmailLogin();
                                  } else {
                                    _firebaseRegister();
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
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _isLoginMode = !_isLoginMode;
                                  });
                                },
                          child: Text(
                            _isLoginMode
                                ? 'Hesabınız yoksa kayıt olun'
                                : 'Hesabınız varsa buradan giriş yapabilirsiniz',
                            style: const TextStyle(
                              color: Color(0xFF90CAF9),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
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
                          onPressed: _isLoading ? null : _firebaseGoogleLogin,
                          icon: const Icon(Icons.g_mobiledata, size: 30, color: Colors.redAccent),
                          label: const Text(
                            'Google ile Devam Et',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                backgroundColor: Colors.white.withValues(alpha: 0.03),
                              ),
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        _authMethod = AuthMethod.phone;
                                        _otpSent = false;
                                      });
                                    },
                              icon: const Icon(Icons.phone, size: 18),
                              label: const Text('Telefon', style: TextStyle(fontSize: 14)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                backgroundColor: Colors.white.withValues(alpha: 0.03),
                              ),
                              onPressed: _isLoading ? null : _firebaseGuestLogin,
                              icon: const Icon(Icons.person_outline, size: 18),
                              label: const Text('Misafir', style: TextStyle(fontSize: 14)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneInputSection() {
    return Column(
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
                Icons.phone_android,
                color: Color(0xFF90CAF9),
                size: 32,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Telefon Girişi',
              style: TextStyle(
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
          _otpSent
              ? 'Telefonunuza gönderilen 6 haneli doğrulama kodunu girin.'
              : 'Telefon numaranızı girerek doğrulama kodu (SMS) talep edin.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.7),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        if (!_otpSent) ...[
          _buildInput(
            _phoneController,
            'Telefon Numarası (örn: +905...)',
            Icons.phone,
            keyboardType: TextInputType.phone,
            isRequired: true,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isLoading ? null : _verifyPhoneNumber,
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Doğrulama Kodu Gönder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ] else ...[
          _buildInput(
            _otpController,
            'SMS Doğrulama Kodu',
            Icons.pin,
            keyboardType: TextInputType.number,
            isRequired: true,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isLoading ? null : _signInWithPhoneNumber,
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Doğrula ve Giriş Yap', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _otpSent = false;
                  _otpController.clear();
                });
              },
              child: Text(
                'Numarayı Değiştir',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Divider(color: Colors.white.withValues(alpha: 0.15)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _authMethod = AuthMethod.email;
                _otpSent = false;
              });
            },
            icon: const Icon(Icons.email, color: Colors.white70),
            label: const Text('E-posta Girişine Dön', style: TextStyle(color: Colors.white70)),
          ),
        ),
      ],
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
