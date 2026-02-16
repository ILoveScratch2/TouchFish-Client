import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../l10n/app_localizations.dart';
import '../models/user_profile.dart';
import '../widgets/account/profile_picture.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  UserProfile? _currentUser;
  bool _isSubmitting = false;
  
  // Image pickers
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _selectedAvatar;
  XFile? _selectedBackground;
  
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
    setState(() {
      _currentUser = UserProfileDemoData.getDemoProfile('1');
      _emailController.text = _currentUser!.email;
      _bioController.text = _currentUser!.personalSign ?? '';
      _introductionController.text = _currentUser!.introduction ?? '';
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
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedAvatar = image;
        });
      }
    } else if (choice == 'remove') {
      setState(() {
        _selectedAvatar = null;
      });
    }
  }

  Future<void> _selectBackground() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    
    if (image != null) {
      setState(() {
        _selectedBackground = image;
      });
    }
  }

  void _removeBackground() {
    setState(() {
      _selectedBackground = null;
    });
  }

  Future<void> _saveProfile() async {
    final l10n = AppLocalizations.of(context)!;
    
    setState(() {
      _isSubmitting = true;
    });

    // 以为有网络吗？
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() {
        _currentUser = UserProfile(
          uid: _currentUser!.uid,
          username: _currentUser!.username,
          email: _emailController.text,
          stat: _currentUser!.stat,
          createTime: _currentUser!.createTime,
          personalSign: _bioController.text,
          introduction: _introductionController.text,
          avatar: _selectedAvatar?.path ?? _currentUser!.avatar,
        );
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.profileEditUpdated),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    if (_currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
            // Background and Avatar Section
            AspectRatio(
              aspectRatio: 16 / 7,
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [
                  // Background
                  GestureDetector(
                    onTap: _selectBackground,
                    child: Container(
                      color: colorScheme.surfaceContainerHigh,
                      child: _selectedBackground != null
                          ? Image.file(
                              File(_selectedBackground!.path),
                              fit: BoxFit.cover,
                            )
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Symbols.add_photo_alternate,
                                    size: 48,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    l10n.profileEditChangeBackground,
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                  
                  // Background remove button
                  if (_selectedBackground != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filled(
                        icon: const Icon(Symbols.delete),
                        onPressed: _removeBackground,
                        tooltip: l10n.profileEditRemoveBackground,
                      ),
                    ),
                  
                  // Avatar
                  Positioned(
                    left: 20,
                    bottom: -32,
                    child: GestureDetector(
                      onTap: _selectAvatar,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colorScheme.surface,
                                width: 4,
                              ),
                            ),
                            child: _selectedAvatar != null
                                ? CircleAvatar(
                                    radius: 40,
                                    backgroundImage: FileImage(
                                      File(_selectedAvatar!.path),
                                    ),
                                  )
                                : ProfilePictureWidget(
                                    avatarUrl: _currentUser!.avatar,
                                    radius: 40,
                                  ),
                          ),
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: Container(
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colorScheme.surface,
                                  width: 2,
                                ),
                              ),
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Symbols.edit,
                                size: 16,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 48),
            
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
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
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
