import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../l10n/app_localizations.dart';
import '../models/user_profile.dart';
import '../services/auth_state.dart';
import '../services/api/tf_api_client.dart';
import '../widgets/account/profile_picture.dart';
import '../utils/talker.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  UserProfile? _currentUser;
  bool _isSubmitting = false;

  // File picker
  PlatformFile? _selectedAvatar;

  // Form fields
  late TextEditingController _emailController;
  late TextEditingController _bioController;
  late TextEditingController _introductionController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _bioController = TextEditingController();
    _introductionController = TextEditingController();
    _loadUser();
  }

  void _loadUser() {
    final user = AuthState.instance.currentUser;
    if (user == null) return;
    setState(() {
      _currentUser = user;
      _emailController.text = user.email;
      _bioController.text = user.personalSign ?? '';
      _introductionController.text = user.introduction ?? '';
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _bioController.dispose();
    _introductionController.dispose();
    super.dispose();
  }

  Future<void> _selectAvatar() async {
    final l10n = AppLocalizations.of(context)!;

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileEditAvatar),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Symbols.photo_library),
              title: Text(l10n.profileEditChangeAvatar),
              onTap: () => Navigator.of(context).pop('change'),
            ),
            if (_selectedAvatar != null || _currentUser?.avatar != null)
              ListTile(
                leading: const Icon(Symbols.delete),
                title: Text(l10n.profileEditRemoveAvatar),
                onTap: () => Navigator.of(context).pop('remove'),
              ),
          ],
        ),
      ),
    );

    if (choice == 'change') {
      FilePickerResult? result;

      if (!kIsWeb && Platform.isAndroid) {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: [
            'jpg',
            'jpeg',
            'png',
            'gif',
            'bmp',
            'webp',
            'heic',
            'heif',
          ],
          allowMultiple: false,
          withData: false,
        );
      } else {
        result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: true,
        );
      }

      if (result != null) {
        final file = result.files.single;
        if (file.bytes != null || file.path != null) {
          setState(() {
            _selectedAvatar = file;
          });
        }
      }
    } else if (choice == 'remove') {
      setState(() {
        _selectedAvatar = null;
      });
    }
  }

  Future<void> _saveProfile() async {
    final l10n = AppLocalizations.of(context)!;
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null || _currentUser == null) return;

    setState(() => _isSubmitting = true);
    try {
      bool allOk = true;

      // 修改个性签名
      final newSign = _bioController.text.trim();
      if (newSign != (_currentUser!.personalSign ?? '')) {
        final ok = await TfApiClient.instance.changeSign(
          uid,
          password,
          newSign,
        );
        if (!ok) allOk = false;
      }

      // 修改个人介绍
      final newIntro = _introductionController.text.trim();
      if (newIntro != (_currentUser!.introduction ?? '')) {
        final ok = await TfApiClient.instance.changeIntroduction(
          uid,
          password,
          newIntro,
        );
        if (!ok) allOk = false;
      }

      // 修改邮筱
      final newEmail = _emailController.text.trim();
      if (newEmail != _currentUser!.email && newEmail.isNotEmpty) {
        final ok = await TfApiClient.instance.changeEmail(
          uid,
          password,
          newEmail,
        );
        if (!ok) allOk = false;
      }

      // 上传头像
      if (_selectedAvatar != null) {
        final bytes =
            _selectedAvatar!.bytes ??
            ((_selectedAvatar!.path != null)
                ? await File(_selectedAvatar!.path!).readAsBytes()
                : null);
        if (bytes != null) {
          final b64 = base64.encode(bytes);
          final ok = await TfApiClient.instance.uploadUserAvatar(
            uid,
            password,
            b64,
          );
          if (ok) {
            AuthState.instance.bumpAvatarVersion();
            imageCache.clear();
          } else {
            allOk = false;
          }
        }
      }

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      await AuthState.instance.refreshProfile();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            allOk ? l10n.profileEditUpdated : l10n.profileEditSaveFailed,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (allOk) context.pop();
    } catch (e) {
      talker.error('_saveProfile failed', e);
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.profileEditSaveFailed),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    if (_currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileEditTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar Section
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: GestureDetector(
                  onTap: _selectAvatar,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.outline.withOpacity(0.2),
                            width: 3,
                          ),
                        ),
                        child: _selectedAvatar != null
                            ? CircleAvatar(
                                radius: 60,
                                backgroundImage:
                                    kIsWeb && _selectedAvatar!.bytes != null
                                    ? MemoryImage(_selectedAvatar!.bytes!)
                                    : (_selectedAvatar!.path != null
                                          ? FileImage(
                                                  File(_selectedAvatar!.path!),
                                                )
                                                as ImageProvider
                                          : null),
                              )
                            : ProfilePictureWidget(
                                avatarUrl: _currentUser!.avatar,
                                radius: 60,
                              ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.surface,
                              width: 3,
                            ),
                          ),
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            Symbols.edit,
                            size: 20,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Basic Info Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.profileEditBasicInfo,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Username (readonly)
                  TextField(
                    decoration: InputDecoration(
                      labelText: l10n.profileEditUsername,
                      helperText: l10n.profileEditUsernameCannotChange,
                      prefixIcon: const Icon(Symbols.person),
                      prefixText: '@',
                    ),
                    controller: TextEditingController(
                      text: _currentUser!.username,
                    ),
                    readOnly: true,
                  ),

                  const SizedBox(height: 16),

                  // Email
                  TextField(
                    decoration: InputDecoration(
                      labelText: l10n.profileEditEmail,
                      prefixIcon: const Icon(Symbols.email),
                    ),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                  ),

                  const SizedBox(height: 16),

                  // Bio / Personal Sign
                  TextField(
                    decoration: InputDecoration(
                      labelText: l10n.profileEditBio,
                      hintText: l10n.profileEditBioPlaceholder,
                      prefixIcon: const Icon(Symbols.chat_bubble),
                    ),
                    controller: _bioController,
                    maxLength: 100,
                  ),

                  const SizedBox(height: 16),

                  // Introduction
                  TextField(
                    decoration: InputDecoration(
                      labelText: l10n.profileEditIntroduction,
                      hintText: l10n.profileEditIntroductionPlaceholder,
                      prefixIcon: const Icon(Symbols.article),
                      alignLabelWithHint: true,
                    ),
                    controller: _introductionController,
                    maxLines: 6,
                    maxLength: 500,
                  ),

                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : _saveProfile,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Symbols.save),
                      label: Text(l10n.profileEditSaveChanges),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
