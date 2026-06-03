import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/auth_models.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.userId,
    required this.initialUser,
  });

  final int userId;
  final AuthUser initialUser;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  late TextEditingController _displayNameController;
  late TextEditingController _ageController;
  late TextEditingController _professionController;
  late TextEditingController _cityController;
  late TextEditingController _maritalStatusController;
  late TextEditingController _childCountController;
  late TextEditingController _chronicIllnessController;
  late TextEditingController _traumaSummaryController;
  
  String _avatarBase64 = '';
  late String _gender;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final u = widget.initialUser;
    _displayNameController = TextEditingController(text: u.displayName);
    _ageController = TextEditingController(text: u.age.toString());
    _professionController = TextEditingController(text: u.profession);
    _cityController = TextEditingController(text: u.city);
    _maritalStatusController = TextEditingController(text: u.maritalStatus);
    _childCountController = TextEditingController(text: u.childCount.toString());
    _chronicIllnessController = TextEditingController(text: u.chronicIllness);
    _traumaSummaryController = TextEditingController(text: u.traumaSummary);
    _avatarBase64 = u.avatar;
    _gender = u.gender;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _ageController.dispose();
    _professionController.dispose();
    _cityController.dispose();
    _maritalStatusController.dispose();
    _childCountController.dispose();
    _chronicIllnessController.dispose();
    _traumaSummaryController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1E1F3B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Profil Resmi Seç',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white70),
              title: const Text('Galeriden Seç', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white70),
              title: const Text('Kamera ile Çek', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final file = await picker.pickImage(
      source: source,
      maxWidth: 200,
      maxHeight: 200,
      imageQuality: 80,
    );

    if (file == null) return;

    final bytes = await file.readAsBytes();
    final base64Str = base64Encode(bytes);

    setState(() {
      _avatarBase64 = base64Str;
    });
  }

  Widget _buildAvatarWidget() {
    final avatarStr = _avatarBase64;
    ImageProvider? imageProvider;

    if (avatarStr.isNotEmpty && avatarStr != 'default') {
      try {
        String cleanBase64 = avatarStr;
        if (avatarStr.contains(',')) {
          cleanBase64 = avatarStr.split(',')[1];
        }
        final bytes = base64Decode(cleanBase64);
        imageProvider = MemoryImage(bytes);
      } catch (e) {
        if (avatarStr.startsWith('http')) {
          imageProvider = NetworkImage(avatarStr);
        }
      }
    }

    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              backgroundImage: imageProvider,
              child: imageProvider == null
                  ? const Icon(Icons.person, size: 60, color: Colors.white70)
                  : null,
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF6C63FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt,
                size: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final updated = await _api.updateUserProfile(
        userId: widget.userId,
        profile: widget.initialUser.copyWith(
          displayName: _displayNameController.text.trim(),
          age: int.tryParse(_ageController.text.trim()) ?? 0,
          gender: _gender,
          profession: _professionController.text.trim(),
          city: _cityController.text.trim(),
          maritalStatus: _maritalStatusController.text.trim(),
          childCount: int.tryParse(_childCountController.text.trim()) ?? 0,
          chronicIllness: _chronicIllnessController.text.trim(),
          traumaSummary: _traumaSummaryController.text.trim(),
          avatar: _avatarBase64.isEmpty ? "default" : _avatarBase64,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil kaydedilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildCard({required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF90CAF9),
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInput(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Düzenle'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E1F3B),
        foregroundColor: Colors.white,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F1026),
              Color(0xFF1E1F3B),
              Color(0xFF323673),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildAvatarWidget(),
                  const SizedBox(height: 24),
                  _buildCard(
                    title: 'Kişisel Bilgiler',
                    children: [
                      _buildInput(_displayNameController, 'Ad Soyad', Icons.person, isRequired: true),
                      _buildInput(_ageController, 'Yaş', Icons.calendar_today, keyboardType: TextInputType.number),
                      DropdownButtonFormField<String>(
                        initialValue: _gender,
                        dropdownColor: const Color(0xFF1E1F3B),
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.wc, color: Colors.white70),
                          labelText: 'Cinsiyet',
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
                        onChanged: (v) => setState(() => _gender = v ?? 'Belirtilmedi'),
                      ),
                      const SizedBox(height: 16),
                      _buildInput(_professionController, 'Meslek', Icons.work),
                      _buildInput(_cityController, 'Şehir', Icons.location_city),
                    ],
                  ),
                  _buildCard(
                    title: 'Sağlık & Sosyal Bilgiler',
                    children: [
                      _buildInput(_maritalStatusController, 'Medeni Durum', Icons.favorite),
                      _buildInput(_childCountController, 'Çocuk Sayısı', Icons.child_care, keyboardType: TextInputType.number),
                      _buildInput(_chronicIllnessController, 'Kronik Rahatsızlıklar', Icons.medical_services),
                      _buildInput(_traumaSummaryController, 'Travma Özeti', Icons.psychology),
                    ],
                  ),
                  const SizedBox(height: 8),
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
                      onPressed: _loading ? null : _save,
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Profili Kaydet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _loading
                          ? null
                          : () async {
                              setState(() => _loading = true);
                              try {
                                await _api.logout();
                                if (!context.mounted) return;
                                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Çıkış yapılamadı: $e')),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _loading = false);
                              }
                            },
                      icon: const Icon(Icons.logout, color: Colors.redAccent),
                      label: const Text('Hesaptan Çıkış Yap', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
