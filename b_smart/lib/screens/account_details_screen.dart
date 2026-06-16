import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/auth_api.dart';
import '../api/account_verification_api.dart';
import '../api/upload_api.dart';
import '../api/users_api.dart';
import '../theme/design_tokens.dart';
import '../utils/url_helper.dart';
import '../widgets/ad_interests_sheet.dart';
import '../widgets/safe_network_image.dart';

class AccountDetailsScreen extends StatefulWidget {
  const AccountDetailsScreen({super.key});

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  final _usersApi = UsersApi();
  final _authApi = AuthApi();
  final _uploadApi = UploadApi();
  final _imagePicker = ImagePicker();

  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _websiteController = TextEditingController();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _dobController = TextEditingController();
  final _genderController = TextEditingController(text: 'Prefer Not to Say');
  final _interestsController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _uploadingAvatar = false;
  bool _verifyingEmail = false;
  bool _verifyingMobile = false;

  String? _userId;
  String? _avatarUrl;
  DateTime? _dateOfBirth;
  String _gender = 'Prefer Not to Say';
  bool _emailVerified = false;
  bool _phoneVerified = false;
  int? _ageOnRecord;
  List<String> _interests = const <String>[];

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _websiteController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _genderController.dispose();
    _interestsController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _normalizeUser(dynamic raw) {
    if (raw is! Map) return const <String, dynamic>{};
    final map = Map<String, dynamic>.from(raw);
    if (map['user'] is Map) {
      return Map<String, dynamic>.from(map['user'] as Map);
    }
    if (map['data'] is Map) {
      final data = Map<String, dynamic>.from(map['data'] as Map);
      if (data['user'] is Map) {
        return Map<String, dynamic>.from(data['user'] as Map);
      }
      return data;
    }
    return map;
  }

  String? _pickString(Map<String, dynamic> user, List<String> keys) {
    for (final key in keys) {
      final value = user[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  bool _asBool(dynamic value) {
    if (value == true) return true;
    if (value is String) {
      return value.toLowerCase().trim() == 'true';
    }
    return false;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  int? _calculateAge(DateTime dob) {
    final now = DateTime.now();
    var age = now.year - dob.year;
    final hadBirthday = now.month > dob.month ||
        (now.month == dob.month && now.day >= dob.day);
    if (!hadBirthday) age--;
    return age < 0 ? null : age;
  }

  DateTime? _tryParseDobCandidates(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return null;
    const formats = [
      'dd MMM yyyy',
      'd MMM yyyy',
      'dd/MM/yyyy',
      'd/M/yyyy',
      'yyyy-MM-dd',
      'MM/dd/yyyy',
      'M/d/yyyy',
    ];
    for (final pattern in formats) {
      try {
        return DateFormat(pattern).parseStrict(raw);
      } catch (_) {
        // Try the next known format.
      }
    }
    return null;
  }

  String _locationFromUser(Map<String, dynamic> user) {
    final location = _pickString(user, ['location']);
    if (location != null) return location;

    final address = user['address'];
    if (address is Map) {
      final a = Map<String, dynamic>.from(address);
      final parts = <String>[
        _pickString(a, ['address_line1', 'addressLine1']) ?? '',
        _pickString(a, ['address_line2', 'addressLine2']) ?? '',
        _pickString(a, ['city']) ?? '',
        _pickString(a, ['state']) ?? '',
        _pickString(a, ['country']) ?? '',
      ].where((e) => e.trim().isNotEmpty).toList();
      if (parts.isNotEmpty) return parts.join(', ');
    }
    return '';
  }

  String _genderLabel(String raw) {
    final value = raw.trim().toLowerCase();
    switch (value) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      case 'third gender':
      case 'third_gender':
      case 'other':
        return 'Third Gender';
      case 'prefer not to say':
      case 'prefer_not_to_say':
      default:
        return 'Prefer Not to Say';
    }
  }

  String _genderBackendValue() {
    final current = _genderController.text.trim();
    switch (current) {
      case 'Male':
        return 'male';
      case 'Female':
        return 'female';
      case 'Third Gender':
        return 'third_gender';
      case 'Prefer Not to Say':
        return 'prefer_not_to_say';
    }
    switch (_gender) {
      case 'Male':
        return 'male';
      case 'Female':
        return 'female';
      case 'Third Gender':
        return 'third_gender';
      case 'Prefer Not to Say':
      default:
        return 'prefer_not_to_say';
    }
  }

  Future<void> _loadAccount() async {
    setState(() => _loading = true);
    try {
      final raw = await _authApi.me();
      final user = _normalizeUser(raw);
      final userId = (user['id'] ?? user['_id'] ?? user['user_id'])?.toString().trim();
      if (userId == null || userId.isEmpty) {
        throw Exception('Unable to resolve your account id.');
      }

      final interestsRes = await _usersApi.getAdInterests(userId);
      final interestsRaw = interestsRes['ad_interests'];
      final interests = <String>[];
      if (interestsRaw is List) {
        for (final item in interestsRaw) {
          final text = (item ?? '').toString().trim();
          if (text.isNotEmpty) interests.add(text);
        }
      }

      final dob = _parseDate(_pickString(user, [
            'date_of_birth',
            'dateOfBirth',
            'dob',
            'birth_date',
            'birthDate',
          ]) ??
          user['date_of_birth'] ??
          user['dob'] ??
          user['birth_date'] ??
          user['birthDate']);

      if (!mounted) return;
      setState(() {
        _userId = userId;
        _avatarUrl = _pickString(user, [
          'avatar_url',
          'avatarUrl',
          'profile_picture',
          'profilePicture',
          'avatar',
        ]);
        _fullNameController.text =
            _pickString(user, ['full_name', 'fullName', 'name']) ?? '';
        _usernameController.text =
            _pickString(user, ['username', 'handle']) ?? '';
        _bioController.text = _pickString(user, ['bio', 'about']) ?? '';
        _websiteController.text = _pickString(user, [
              'website',
              'website_url',
              'websiteUrl',
              'online_presence.website_url',
            ]) ??
            '';
        _locationController.text = _locationFromUser(user);
        _phoneController.text = _pickString(user, [
              'phone',
              'phone_number',
              'phoneNumber',
              'mobile_number',
            ]) ??
            '';
        _emailController.text =
            _pickString(user, ['email', 'email_address', 'emailAddress']) ?? '';
        _gender = _genderLabel(
          _pickString(user, ['gender', 'sex']) ?? 'Prefer Not to Say',
        );
        _genderController.text = _gender;
        _dateOfBirth = dob;
        _dobController.text = dob == null ? '' : DateFormat('dd MMM yyyy').format(dob);
        _ageOnRecord = int.tryParse(
          _pickString(user, ['age']) ?? '',
        );
        _emailVerified = _asBool(user['email_verified']) ||
            _asBool(user['emailVerified']) ||
            _asBool(user['is_email_verified']);
        _phoneVerified = _asBool(user['phone_verified']) ||
            _asBool(user['phoneVerified']) ||
            _asBool(user['is_phone_verified']);
        _interests = interests;
        _interestsController.text = interests.join(', ');
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load account: $e')),
      );
    }
  }

  Future<void> _pickAvatar() async {
    if (_userId == null || _userId!.isEmpty || _uploadingAvatar) return;
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await picked.readAsBytes();
      final upload = await _uploadApi.uploadAvatarBytes(
        bytes: bytes,
        filename: picked.name.isNotEmpty ? picked.name : 'avatar.jpg',
      );
      final newUrl = (upload['avatar_url'] ??
              upload['url'] ??
              upload['fileUrl'] ??
              upload['file_url'])
          ?.toString()
          .trim();
      if (newUrl == null || newUrl.isEmpty) {
        throw Exception('Upload did not return an avatar URL.');
      }

      await _usersApi.updateUser(
        _userId!,
        avatarUrl: newUrl,
        extra: {'avatar_url': newUrl},
      );

      if (!mounted) return;
      setState(() => _avatarUrl = newUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Avatar upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _editInterests() async {
    if (_userId == null || _userId!.isEmpty) return;
    await AdInterestsSheet.show(
      context,
      userId: _userId!,
      initialInterests: _interests,
      editable: true,
      onSaved: (next) {
        if (!mounted) return;
        setState(() {
          _interests = next;
          _interestsController.text = next.join(', ');
        });
      },
    );
    await _loadAccount();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dateOfBirth ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select Date of Birth',
    );
    if (picked == null) return;
    setState(() => _dateOfBirth = picked);
  }

  Future<void> _verifyEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email address found.')),
      );
      return;
    }
    if (_verifyingEmail) return;
    setState(() => _verifyingEmail = true);
    await _showVerificationDialog(
      type: 'email',
      title: 'Verify Email',
      value: email,
      successMessage: 'Email verified',
      onVerified: () async {
        if (!mounted) return;
        setState(() => _emailVerified = true);
      },
    );
    if (mounted) setState(() => _verifyingEmail = false);
  }

  Future<void> _verifyMobile() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a mobile number first.')),
      );
      return;
    }
    if (_verifyingMobile) return;
    setState(() => _verifyingMobile = true);
    await _showVerificationDialog(
      type: 'phone',
      title: 'Verify Mobile Number',
      value: phone,
      successMessage: 'Mobile verified',
      onVerified: () async {
        if (!mounted) return;
        setState(() => _phoneVerified = true);
      },
    );
    if (mounted) setState(() => _verifyingMobile = false);
  }

  Future<void> _showVerificationDialog({
    required String type,
    required String title,
    required String value,
    required String successMessage,
    required Future<void> Function() onVerified,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _VerificationOtpDialog(
        type: type,
        title: title,
        value: value,
        successMessage: successMessage,
        onVerified: onVerified,
      ),
    );
  }

  Future<void> _saveAccount() async {
    if (_userId == null || _userId!.isEmpty || _saving) return;

    setState(() => _saving = true);
    try {
      final updates = <String, dynamic>{
        'full_name': _fullNameController.text.trim(),
        'username': _usernameController.text.trim(),
        'bio': _bioController.text.trim(),
        'website': _websiteController.text.trim(),
        'phone': _phoneController.text.trim(),
        'gender': _genderBackendValue(),
        'location': _locationController.text.trim(),
      };

      final dobText = _dobController.text.trim();
      if (dobText.isNotEmpty) {
        final parsedDob = _parseDate(dobText) ??
            _tryParseDobCandidates(dobText);
        if (parsedDob != null) {
          updates['date_of_birth'] = DateFormat('yyyy-MM-dd').format(parsedDob);
          final age = _calculateAge(parsedDob);
          if (age != null) updates['age'] = age;
          _dateOfBirth = parsedDob;
        } else {
          updates['date_of_birth'] = dobText;
        }
      }
      if (_avatarUrl != null && _avatarUrl!.trim().isNotEmpty) {
        updates['avatar_url'] = _avatarUrl!.trim();
      }

      final response = await _usersApi.updateUser(
        _userId!,
        fullName: _fullNameController.text.trim(),
        bio: _bioController.text.trim(),
        avatarUrl: _avatarUrl?.trim(),
        phone: _phoneController.text.trim(),
        username: _usernameController.text.trim(),
        extra: updates,
      );

      await _usersApi.updateAdInterests(
        _userId!,
        interests: _interests,
      );

      final updated = _normalizeUser(response);
      if (mounted && updated.isNotEmpty) {
        setState(() {
          _fullNameController.text =
              _pickString(updated, ['full_name', 'fullName', 'name']) ??
                  _fullNameController.text;
          _usernameController.text =
              _pickString(updated, ['username', 'handle']) ??
                  _usernameController.text;
          _bioController.text =
              _pickString(updated, ['bio', 'about']) ?? _bioController.text;
          _websiteController.text =
              _pickString(updated, ['website', 'website_url', 'websiteUrl']) ??
                  _websiteController.text;
          _locationController.text =
              _locationFromUser(updated).isNotEmpty
                  ? _locationFromUser(updated)
                  : _locationController.text;
          _phoneController.text =
              _pickString(updated, ['phone', 'phone_number', 'phoneNumber']) ??
                  _phoneController.text;
          _gender = _genderLabel(
            _pickString(updated, ['gender', 'sex']) ?? _gender,
          );
          _genderController.text = _gender;
          final updatedDob = _parseDate(_pickString(updated, [
                'date_of_birth',
                'dateOfBirth',
                'dob',
                'birth_date',
                'birthDate',
              ]) ??
              updated['date_of_birth'] ??
              updated['dob']);
          if (updatedDob != null) {
            _dateOfBirth = updatedDob;
            _dobController.text = DateFormat('dd MMM yyyy').format(updatedDob);
          }
          _ageOnRecord = int.tryParse(
            _pickString(updated, ['age']) ?? '',
          ) ?? _ageOnRecord;
          _interestsController.text = _interests.join(', ');
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save account: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formattedDob() {
    final dob = _dateOfBirth;
    if (dob == null) return 'Select your date of birth';
    return DateFormat('dd MMM yyyy').format(dob);
  }

  String _ageLabel() {
    if (_dateOfBirth != null) {
      final age = _calculateAge(_dateOfBirth!);
      if (age != null) return '$age years old';
    }
    if (_ageOnRecord != null) return '${_ageOnRecord!} years old';
    return 'Age not set';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 56,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Account',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              bottom: true,
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [
                  _sectionTitle('Profile Picture'),
                  _avatarCard(),
                  const SizedBox(height: 10),
                  _sectionTitle('Profile'),
                  _inlineFieldCard(
                    icon: LucideIcons.userRound,
                    label: 'Full Name',
                    controller: _fullNameController,
                    hintText: 'Enter your full name',
                  ),
                  _inlineFieldCard(
                    icon: LucideIcons.atSign,
                    label: 'Username',
                    controller: _usernameController,
                    hintText: 'Choose a username',
                  ),
                  _inlineFieldCard(
                    icon: LucideIcons.textCursorInput,
                    label: 'Bio',
                    controller: _bioController,
                    hintText: 'Write a short bio',
                    maxLines: 3,
                  ),
                  _inlineFieldCard(
                    icon: LucideIcons.globe,
                    label: 'Website',
                    controller: _websiteController,
                    hintText: 'https://www.example.com',
                    keyboardType: TextInputType.url,
                  ),
                  _inlineFieldCard(
                    icon: LucideIcons.cake,
                    label: 'Date of Birth',
                    controller: _dobController,
                    hintText: 'dd MMM yyyy',
                    onChanged: (value) {
                      final parsed = _tryParseDobCandidates(value);
                      setState(() {
                        _dateOfBirth = parsed;
                      });
                    },
                  ),
                  _inlineFieldCard(
                    icon: LucideIcons.transgender,
                    label: 'Gender',
                    controller: _genderController,
                    hintText: 'Male, Female, Third Gender, Prefer Not to Say',
                    onChanged: (value) {
                      setState(() => _gender = value.trim().isEmpty ? _gender : value.trim());
                    },
                  ),
                  _interestTile(),
                  const SizedBox(height: 10),
                  _sectionTitle('Location'),
                  _inlineFieldCard(
                    icon: LucideIcons.mapPin,
                    label: 'Location',
                    controller: _locationController,
                    hintText: 'City, State, Country',
                  ),
                  const SizedBox(height: 10),
                  _sectionTitle('Contact Information'),
                  _contactCard(),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 56,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: DesignTokens.instaGradient,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: _saving ? null : _saveAccount,
                          child: Center(
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        LucideIcons.save,
                                        color: Colors.white,
                                        size: 17,
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        'Save Changes',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _avatarCard() {
    final avatar = UrlHelper.normalizeUrl(_avatarUrl);
    final initials = _initials(_fullNameController.text.isNotEmpty
        ? _fullNameController.text
        : _usernameController.text);

    return Material(
      color: const Color(0xFFFFF3F8),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _uploadingAvatar ? null : _pickAvatar,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          DesignTokens.instaPink.withValues(alpha: 0.16),
                          DesignTokens.instaOrange.withValues(alpha: 0.16),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Container(
                      decoration: const BoxDecoration(shape: BoxShape.circle),
                      clipBehavior: Clip.antiAlias,
                      child: avatar.isNotEmpty
                          ? SafeNetworkImage(
                              url: avatar,
                              width: 66,
                              height: 66,
                              fit: BoxFit.cover,
                              placeholder: Container(
                                color: Colors.grey.shade200,
                              ),
                              errorWidget: Container(
                                color: Colors.grey.shade200,
                                child: Center(
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              child: Center(
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  if (_uploadingAvatar)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile Picture',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF24364B),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Tap to change your avatar',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateTile() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark ? const Color(0xFF242424) : Colors.white;
    final borderColor = isDark ? const Color(0xFF444444) : const Color(0xFFF5D5E1);
    final labelColor = isDark ? const Color(0xFFE8E8E8) : const Color(0xFF24364B);
    final hintColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF526071);

    return InkWell(
      onTap: _pickDob,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: DesignTokens.instaPink.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cake_outlined,
                color: DesignTokens.instaPink,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date of Birth',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formattedDob(),
                    style: TextStyle(color: hintColor, fontSize: 13),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _ageLabel(),
                  style: TextStyle(
                    fontSize: 12,
                    color: hintColor,
                  ),
                ),
                const SizedBox(height: 2),
                const Icon(Icons.chevron_right, color: Color(0xFF526071), size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _genderTile() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark ? const Color(0xFF242424) : Colors.white;
    final borderColor = isDark ? const Color(0xFF444444) : const Color(0xFFF5D5E1);
    final labelColor = isDark ? const Color(0xFFE8E8E8) : const Color(0xFF24364B);
    final hintColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF526071);

    return InkWell(
      onTap: () async {
        final next = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (ctx) {
            return SafeArea(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                children: [
                  const Center(
                    child: SizedBox(
                      width: 40,
                      child: Divider(thickness: 4, height: 20),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Select Gender',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  RadioListTile<String>(
                    value: 'Male',
                    groupValue: _gender,
                    activeColor: DesignTokens.instaPink,
                    onChanged: (value) => Navigator.of(ctx).pop(value),
                    title: const Text('Male'),
                  ),
                  RadioListTile<String>(
                    value: 'Female',
                    groupValue: _gender,
                    activeColor: DesignTokens.instaPink,
                    onChanged: (value) => Navigator.of(ctx).pop(value),
                    title: const Text('Female'),
                  ),
                  RadioListTile<String>(
                    value: 'Third Gender',
                    groupValue: _gender,
                    activeColor: DesignTokens.instaPink,
                    onChanged: (value) => Navigator.of(ctx).pop(value),
                    title: const Text('Third Gender'),
                  ),
                  RadioListTile<String>(
                    value: 'Prefer Not to Say',
                    groupValue: _gender,
                    activeColor: DesignTokens.instaPink,
                    onChanged: (value) => Navigator.of(ctx).pop(value),
                    title: const Text('Prefer Not to Say'),
                  ),
                ],
              ),
            );
          },
        );
        if (next != null && mounted) setState(() => _gender = next);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: DesignTokens.instaPink.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.transgender_outlined,
                    color: DesignTokens.instaPink,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Gender',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              _gender,
              style: TextStyle(color: hintColor, fontSize: 13),
            ),
            const SizedBox(height: 2),
            const Align(
              alignment: Alignment.centerRight,
              child: Icon(Icons.chevron_right, color: Color(0xFF526071), size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _interestTile() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark ? const Color(0xFF242424) : const Color(0xFFFFF3F8);
    final borderColor = isDark ? const Color(0xFF444444) : const Color(0xFFF6CFE0);
    final labelColor = isDark ? const Color(0xFFE8E8E8) : const Color(0xFF24364B);
    final hintColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF526071);

    return InkWell(
      onTap: _editInterests,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: DesignTokens.instaPink.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.interests_outlined,
                color: DesignTokens.instaPink,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Interests',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _interests.isEmpty ? 'No interests selected' : _interests.join(', '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: hintColor, fontSize: 13),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_interests.length} selected',
                  style: TextStyle(fontSize: 12, color: hintColor),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right, color: Color(0xFF526071), size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _editableRowCard({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
    int maxValueLines = 1,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark ? const Color(0xFF242424) : Colors.white;
    final borderColor = isDark ? const Color(0xFF444444) : const Color(0xFFF5D5E1);
    final titleColor = isDark ? const Color(0xFFE8E8E8) : const Color(0xFF24364B);
    final valueColor = isDark ? const Color(0xFFB6BBC6) : const Color(0xFF526071);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: fillColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: DesignTokens.instaPink.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: DesignTokens.instaPink, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        value,
                        maxLines: maxValueLines,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: valueColor,
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Color(0xFF526071), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _contactCard() {
    return Column(
      children: [
        _inlineFieldCard(
          icon: Icons.mail_outline,
          label: 'Email Address',
          controller: _emailController,
          hintText: 'Enter your email address',
          keyboardType: TextInputType.emailAddress,
          verified: _emailVerified,
          trailing: _emailVerified
              ? const Icon(
                  Icons.check_circle,
                  color: Color(0xFF22C55E),
                  size: 24,
                )
              : TextButton(
                  onPressed: (_verifyingEmail || _emailVerified)
                      ? null
                      : _verifyEmail,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: DesignTokens.instaPink.withValues(alpha: 0.95),
                        width: 1.4,
                      ),
                    ),
                    foregroundColor: DesignTokens.instaPink,
                    backgroundColor: Colors.transparent,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text(
                    'Verify Email',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
        ),
        _inlineFieldCard(
          icon: Icons.phone_outlined,
          label: 'Mobile Number',
          controller: _phoneController,
          hintText: 'Enter your mobile number',
          keyboardType: TextInputType.phone,
          verified: _phoneVerified,
          trailing: _phoneVerified
              ? const Icon(
                  Icons.check_circle,
                  color: Color(0xFF22C55E),
                  size: 24,
                )
              : TextButton(
                  onPressed: (_verifyingMobile || _phoneVerified)
                      ? null
                      : _verifyMobile,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: DesignTokens.instaPink.withValues(alpha: 0.95),
                        width: 1.4,
                      ),
                    ),
                    foregroundColor: DesignTokens.instaPink,
                    backgroundColor: Colors.transparent,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text(
                    'Verify Mobile Number',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _inlineFieldCard({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool verified = false,
    ValueChanged<String>? onChanged,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark ? const Color(0xFF242424) : const Color(0xFFFFF3F8);
    final borderColor = isDark ? const Color(0xFF444444) : const Color(0xFFF6CFE0);
    final titleColor = isDark ? const Color(0xFFE8E8E8) : const Color(0xFF24364B);
    final hintColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF526071);

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: DesignTokens.instaPink.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: DesignTokens.instaPink, size: 16),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  maxLines: maxLines,
                  minLines: maxLines,
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: hintText,
                    hintStyle: TextStyle(
                      color: hintColor,
                      fontSize: 13,
                    ),
                  ),
                  style: TextStyle(
                    color: hintColor,
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
                if (verified) ...[
                  const SizedBox(height: 2),
                  const SizedBox.shrink(),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            Align(
              alignment: Alignment.centerRight,
              child: trailing,
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: DesignTokens.instaPink,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Future<void> _editTextField({
    required String title,
    required TextEditingController controller,
    String hintText = '',
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) async {
    final tempController = TextEditingController(text: controller.text);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: tempController,
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hintText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(tempController.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    tempController.dispose();
    if (result == null || !mounted) return;
    setState(() {
      controller.text = result;
    });
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _initials(String name) {
    final u = name.trim();
    if (u.isEmpty) return 'U';
    final parts = u.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final first = parts.isNotEmpty ? parts.first : u;
    final second = parts.length > 1 ? parts[1] : '';
    final a = first.characters.first.toUpperCase();
    final b = second.isNotEmpty ? second.characters.first.toUpperCase() : '';
    return (a + b).trim().isEmpty ? 'U' : (a + b);
  }
}

class _VerificationOtpDialog extends StatefulWidget {
  const _VerificationOtpDialog({
    required this.type,
    required this.title,
    required this.value,
    required this.successMessage,
    required this.onVerified,
  });

  final String type;
  final String title;
  final String value;
  final String successMessage;
  final Future<void> Function() onVerified;

  @override
  State<_VerificationOtpDialog> createState() => _VerificationOtpDialogState();
}

class _VerificationOtpDialogState extends State<_VerificationOtpDialog> {
  final _accountVerificationApi = AccountVerificationApi();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());

  bool _loading = false;
  bool _sent = false;
  String? _error;
  String? _success;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _startCooldown() async {
    _timer?.cancel();
    if (!mounted) return;
    setState(() => _cooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldown <= 1) {
        timer.cancel();
        setState(() => _cooldown = 0);
        return;
      }
      setState(() => _cooldown -= 1);
    });
  }

  Future<void> _sendOtp() async {
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
      _sent = false;
    });
    try {
      await _accountVerificationApi.send(type: widget.type);
      if (!mounted) return;
      setState(() => _sent = true);
      await _startCooldown();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join().trim();
    if (otp.length < 6) {
      setState(() => _error = 'Please enter all 6 digits.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    try {
      await _accountVerificationApi.confirm(type: widget.type, otp: otp);
      await widget.onVerified();
      if (!mounted) return;
      setState(() => _success = widget.successMessage);
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeCard = isDark ? const Color(0xFF111827) : Colors.white;
    final muted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final maxDialogWidth = MediaQuery.sizeOf(context).width - 32;
    final dialogWidth = maxDialogWidth < 360 ? maxDialogWidth : 360.0;

    Widget otpBoxes() {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(6, (index) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? 0 : 4,
                right: index == 5 ? 0 : 4,
              ),
              child: SizedBox(
                height: 42,
                child: TextField(
                  controller: _otpControllers[index],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '0',
                  ),
                  onChanged: (value) {
                    final digits = value.replaceAll(RegExp(r'\D'), '');
                    final cleaned = digits.isEmpty ? '' : digits.substring(0, 1);
                    if (cleaned != value) {
                      _otpControllers[index].text = cleaned;
                      _otpControllers[index].selection = TextSelection.fromPosition(
                        TextPosition(offset: _otpControllers[index].text.length),
                      );
                    }
                  },
                ),
              ),
            ),
          );
        }),
      );
    }

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: dialogWidth,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: themeCard,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.shield,
                    color: Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _loading ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.x, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_success != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD1FAE5)),
                ),
                child: Text(
                  _success!,
                  style: const TextStyle(
                    color: Color(0xFF047857),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (!_sent) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              Center(
                child: Text(
                  'Sending OTP…',
                  style: TextStyle(fontSize: 13, color: muted),
                ),
              ),
            ] else ...[
              Text(
                'Code sent. Enter the 6-digit code to confirm.',
                style: TextStyle(
                  fontSize: 12,
                  color: muted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              otpBoxes(),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _verifyOtp,
                  style: FilledButton.styleFrom(
                    backgroundColor: DesignTokens.instaPink,
                  ),
                  child: _loading
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('Verifying…'),
                          ],
                        )
                      : const Text('Verify & Confirm'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: (_cooldown > 0 || _loading) ? null : _sendOtp,
                  icon: const Icon(LucideIcons.refreshCw, size: 14),
                  label: Text(
                    _cooldown > 0 ? 'Resend in ${_cooldown}s' : 'Resend',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
