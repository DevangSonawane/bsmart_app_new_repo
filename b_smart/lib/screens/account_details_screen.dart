import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/auth_api.dart';
import '../api/email_api.dart';
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
  final _emailApi = EmailApi();
  final _uploadApi = UploadApi();
  final _imagePicker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _websiteController = TextEditingController();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _uploadingAvatar = false;
  bool _verifyingEmail = false;
  final bool _verifyingMobile = false;

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
        _dateOfBirth = dob;
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
        setState(() => _interests = next);
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

    final otpController = TextEditingController();
    bool loading = false;
    String? error;
    int cooldown = 0;
    Timer? timer;
    StateSetter? setDialogState;

    Future<void> sendOtp(StateSetter setLocal) async {
      setLocal(() {
        loading = true;
        error = null;
      });
      try {
        await _emailApi.sendOtp(email: email, purpose: 'two_factor');
        setLocal(() => cooldown = 60);
        timer?.cancel();
        timer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (cooldown <= 1) {
            t.cancel();
            setDialogState?.call(() => cooldown = 0);
            return;
          }
          setDialogState?.call(() => cooldown -= 1);
        });
      } catch (e) {
        setLocal(() => error = e.toString().replaceAll('Exception: ', ''));
      } finally {
        setLocal(() => loading = false);
      }
    }

    Future<void> verifyOtp(StateSetter setLocal) async {
      final otp = otpController.text.trim();
      if (otp.length < 6) {
        setLocal(() => error = 'Enter the 6-digit code.');
        return;
      }
      setLocal(() {
        loading = true;
        error = null;
      });
      try {
        await _emailApi.verifyOtp(
          email: email,
          otp: otp,
          purpose: 'two_factor',
        );
        await _usersApi.updateUser(
          _userId!,
          extra: {
            'email_verified': true,
            'emailVerified': true,
            'is_email_verified': true,
          },
        );
        if (!mounted) return;
        setState(() => _emailVerified = true);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email verified')),
        );
      } catch (e) {
        setLocal(() => error = e.toString().replaceAll('Exception: ', ''));
      } finally {
        setLocal(() => loading = false);
      }
    }

    setState(() => _verifyingEmail = true);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            setDialogState = setLocal;
            return AlertDialog(
              title: const Text('Verify Email'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(email, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  if (error != null) ...[
                    Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const Text(
                    'We will send an OTP to your email. Enter it here to confirm.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      hintText: '000000',
                      counterText: '',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: (loading || cooldown > 0)
                      ? null
                      : () => sendOtp(setLocal),
                  child: Text(cooldown > 0 ? 'Resend in $cooldown s' : 'Send OTP'),
                ),
                FilledButton(
                  onPressed: loading ? null : () => verifyOtp(setLocal),
                  child: const Text('Verify'),
                ),
              ],
            );
          },
        );
      },
    );
    timer?.cancel();
    if (mounted) setState(() => _verifyingEmail = false);
  }

  Future<void> _verifyMobile() async {
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a mobile number first.')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mobile verification is not wired to a backend endpoint yet.'),
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

      final dob = _dateOfBirth;
      if (dob != null) {
        updates['date_of_birth'] = DateFormat('yyyy-MM-dd').format(dob);
        final age = _calculateAge(dob);
        if (age != null) updates['age'] = age;
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
          final updatedDob = _parseDate(_pickString(updated, [
                'date_of_birth',
                'dateOfBirth',
                'dob',
                'birth_date',
                'birthDate',
              ]) ??
              updated['date_of_birth'] ??
              updated['dob']);
          if (updatedDob != null) _dateOfBirth = updatedDob;
          _ageOnRecord = int.tryParse(
            _pickString(updated, ['age']) ?? '',
          ) ?? _ageOnRecord;
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Account'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              bottom: true,
              top: false,
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _headerCard(isDark),
                    const SizedBox(height: 20),
                    _sectionTitle('Profile Picture'),
                    _avatarCard(),
                    const SizedBox(height: 18),
                    const Divider(height: 1, thickness: 1),
                    const SizedBox(height: 18),
                    _sectionTitle('Profile'),
                    _buildTextField(
                      controller: _fullNameController,
                      label: 'Full Name',
                      hint: 'Enter your full name',
                      icon: Icons.person_outline,
                    ),
                    _buildTextField(
                      controller: _usernameController,
                      label: 'Username',
                      hint: 'Choose a unique username',
                      icon: Icons.alternate_email,
                    ),
                    _buildTextField(
                      controller: _bioController,
                      label: 'Bio',
                      hint: 'Write a short bio',
                      icon: Icons.short_text,
                      maxLines: 4,
                    ),
                    _buildTextField(
                      controller: _websiteController,
                      label: 'Website',
                      hint: 'https://yourwebsite.com',
                      icon: Icons.language,
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 14),
                    _dateTile(),
                    const SizedBox(height: 14),
                    _genderTile(),
                    const SizedBox(height: 14),
                    _interestTile(),
                    const SizedBox(height: 18),
                    const Divider(height: 1, thickness: 1),
                    const SizedBox(height: 18),
                    _sectionTitle('Location'),
                    _buildTextField(
                      controller: _locationController,
                      label: 'Location',
                      hint: 'City, State, Country',
                      icon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 18),
                    const Divider(height: 1, thickness: 1),
                    const SizedBox(height: 18),
                    _sectionTitle('Contact Information'),
                    _contactCard(),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _saving ? null : _saveAccount,
                      icon: _saving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Saving…' : 'Save Changes'),
                      style: FilledButton.styleFrom(
                        backgroundColor: DesignTokens.instaPink,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _headerCard(bool isDark) {
    final avatar = _avatarUrl?.trim() ?? '';
    final initials = _initials(_fullNameController.text.isNotEmpty
        ? _fullNameController.text
        : _usernameController.text);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: DesignTokens.instaGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.14),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit your account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Update your profile, contact details, interests, and identity settings.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip(_emailVerified ? 'Email verified' : 'Email not verified'),
                    _chip(_phoneVerified ? 'Mobile verified' : 'Mobile not verified'),
                    _chip(_gender),
                  ],
                ),
              ],
            ),
          ),
          if (avatar.isNotEmpty)
            const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _avatarCard() {
    final avatar = UrlHelper.normalizeUrl(_avatarUrl);
    final initials = _initials(_fullNameController.text.isNotEmpty
        ? _fullNameController.text
        : _usernameController.text);

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: _uploadingAvatar ? null : _pickAvatar,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          DesignTokens.instaPink.withValues(alpha: 0.18),
                          DesignTokens.instaOrange.withValues(alpha: 0.18),
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
                              width: 78,
                              height: 78,
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
                                      fontSize: 22,
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
                                    fontSize: 22,
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
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile Picture',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tap to change your avatar',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                color: Theme.of(context).iconTheme.color ?? Colors.grey,
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
    final fillColor = isDark ? const Color(0xFF242424) : const Color(0xFFF6F7F9);
    final borderColor = isDark ? const Color(0xFF444444) : const Color(0xFFD7DCE3);
    final labelColor = isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1F2937);
    final hintColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return InkWell(
      onTap: _pickDob,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: DesignTokens.instaPink.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cake_outlined,
                color: DesignTokens.instaPink,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date of Birth',
                    style: TextStyle(
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
                const Icon(Icons.chevron_right, color: Colors.grey),
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
    final fillColor = isDark ? const Color(0xFF242424) : const Color(0xFFF6F7F9);
    final borderColor = isDark ? const Color(0xFF444444) : const Color(0xFFD7DCE3);
    final labelColor = isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1F2937);
    final hintColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: DesignTokens.instaPink.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.transgender_outlined,
                  color: DesignTokens.instaPink,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Gender',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _gender,
            isExpanded: true,
            dropdownColor: theme.cardColor,
            iconEnabledColor: hintColor,
            style: TextStyle(color: labelColor),
            items: const [
              DropdownMenuItem(value: 'Male', child: Text('Male')),
              DropdownMenuItem(value: 'Female', child: Text('Female')),
              DropdownMenuItem(
                value: 'Third Gender',
                child: Text('Third Gender'),
              ),
              DropdownMenuItem(
                value: 'Prefer Not to Say',
                child: Text('Prefer Not to Say'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _gender = value);
            },
            decoration: InputDecoration(
              labelText: 'Select gender',
              labelStyle: TextStyle(color: hintColor),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: DesignTokens.instaPink, width: 1.4),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _interestTile() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark ? const Color(0xFF242424) : const Color(0xFFF6F7F9);
    final borderColor = isDark ? const Color(0xFF444444) : const Color(0xFFD7DCE3);
    final labelColor = isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1F2937);
    final hintColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return InkWell(
      onTap: _editInterests,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: DesignTokens.instaPink.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.interests_outlined,
                color: DesignTokens.instaPink,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Interests',
                    style: TextStyle(
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
                const SizedBox(height: 2),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactCard() {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _contactField(
              label: 'Email Address',
              controller: _emailController,
              icon: Icons.mail_outline,
              readOnly: true,
              helper: _emailVerified ? 'Verified' : 'Not verified',
              action: TextButton(
                onPressed: (_verifyingEmail || _emailVerified) ? null : _verifyEmail,
                child: Text(_emailVerified ? 'Verified' : 'Verify Email'),
              ),
            ),
            const SizedBox(height: 16),
            _contactField(
              label: 'Mobile Number',
              controller: _phoneController,
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              helper: _phoneVerified ? 'Verified' : 'Not verified',
              action: TextButton(
                onPressed: (_verifyingMobile || _phoneVerified) ? null : _verifyMobile,
                child: Text(_phoneVerified ? 'Verified' : 'Verify Mobile Number'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    bool readOnly = false,
    String? helper,
    Widget? action,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark ? const Color(0xFF242424) : const Color(0xFFF6F7F9);
    final borderColor = isDark ? const Color(0xFF444444) : const Color(0xFFD7DCE3);
    final labelColor = isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1F2937);
    final hintColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: DesignTokens.instaPink.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: DesignTokens.instaPink, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: labelColor,
                    ),
                  ),
                  if (helper != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      helper,
                      style: TextStyle(fontSize: 12, color: hintColor),
                    ),
                  ],
                ],
              ),
            ),
            if (action != null) action,
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: label,
            filled: true,
            fillColor: fillColor,
            labelStyle: TextStyle(color: labelColor),
            hintStyle: TextStyle(color: hintColor),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: DesignTokens.instaPink, width: 1.4),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: borderColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark ? const Color(0xFF242424) : const Color(0xFFF6F7F9);
    final borderColor = isDark ? const Color(0xFF444444) : const Color(0xFFD7DCE3);
    final labelColor = isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1F2937);
    final hintColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: hintColor),
          filled: true,
          fillColor: fillColor,
          labelStyle: TextStyle(color: labelColor),
          hintStyle: TextStyle(color: hintColor),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: borderColor, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: DesignTokens.instaPink, width: 1.4),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: borderColor),
          ),
          alignLabelWithHint: maxLines > 1,
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: DesignTokens.instaPink,
          letterSpacing: 0.7,
        ),
      ),
    );
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
