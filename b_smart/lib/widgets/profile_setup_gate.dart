import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../api/api.dart';
import '../state/app_state.dart';
import '../state/profile_actions.dart';
import '../theme/design_tokens.dart';

class ProfileSetupGate extends StatefulWidget {
  final Widget child;
  final int routeVersion;

  const ProfileSetupGate({
    super.key,
    required this.child,
    required this.routeVersion,
  });

  @override
  State<ProfileSetupGate> createState() => _ProfileSetupGateState();
}

class _ProfileSetupGateState extends State<ProfileSetupGate>
    with WidgetsBindingObserver {
  static final Set<String> _dismissedSession = <String>{};

  final ApiClient _apiClient = ApiClient();

  final TextEditingController _addressLine1Controller = TextEditingController();
  final TextEditingController _addressLine2Controller = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();

  String _gender = '';
  String _currentUserId = '';

  bool _showProfileSetup = false;
  bool _savingProfileSetup = false;
  bool _checkingProfileSetup = false;
  bool _saveSuccess = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshProfileSetupState();
    });
  }

  @override
  void didUpdateWidget(covariant ProfileSetupGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeVersion != widget.routeVersion) {
      _refreshProfileSetupState();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshProfileSetupState();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _pincodeController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  String _dismissKey(String userId) {
    if (userId.isEmpty) return 'profile_setup_dismissed';
    return 'profile_setup_dismissed_$userId';
  }

  Map<String, dynamic>? _normalizeProfile(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    Map<String, dynamic> data = Map<String, dynamic>.from(raw);
    if (raw['user'] is Map) {
      data = Map<String, dynamic>.from(raw['user'] as Map);
    } else if (raw['data'] is Map) {
      final wrapped = Map<String, dynamic>.from(raw['data'] as Map);
      if (wrapped['user'] is Map) {
        data = Map<String, dynamic>.from(wrapped['user'] as Map);
      } else {
        data = wrapped;
      }
    }

    final normalized = Map<String, dynamic>.from(data);
    final id = data['id'] ?? data['_id'] ?? data['user_id'];
    if (id != null) {
      normalized['id'] = id.toString();
      normalized['_id'] = id.toString();
    }
    return normalized;
  }

  Map<String, dynamic> _extractAddress(Map<String, dynamic>? profile) {
    if (profile == null) return const <String, dynamic>{};
    final raw = profile['address'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const <String, dynamic>{};
  }

  String _normalizeGender(dynamic rawGender) {
    final lower = (rawGender ?? '').toString().trim().toLowerCase();
    if (lower == 'male' || lower == 'female' || lower == 'other') return lower;
    return '';
  }

  bool _needsProfileSetup(Map<String, dynamic>? profile) {
    if (profile == null) return false;
    final gender = _normalizeGender(profile['gender'] ?? profile['sex']);
    final address = _extractAddress(profile);
    final addressLine1 =
        (address['address_line1'] ?? address['addressLine1'] ?? '')
            .toString()
            .trim();
    final pincode = (address['pincode'] ?? '').toString().trim();
    final city = (address['city'] ?? '').toString().trim();
    final state = (address['state'] ?? '').toString().trim();
    final country = (address['country'] ?? '').toString().trim();
    return gender.isEmpty ||
        addressLine1.isEmpty ||
        pincode.isEmpty ||
        city.isEmpty ||
        state.isEmpty ||
        country.isEmpty;
  }

  void _fillFormFromProfile(Map<String, dynamic>? profile) {
    final address = _extractAddress(profile);
    _gender = _normalizeGender(profile?['gender'] ?? profile?['sex']);
    _addressLine1Controller.text =
        (address['address_line1'] ?? address['addressLine1'] ?? '').toString();
    _addressLine2Controller.text =
        (address['address_line2'] ?? address['addressLine2'] ?? '').toString();
    _pincodeController.text = (address['pincode'] ?? '').toString();
    _cityController.text = (address['city'] ?? '').toString();
    _stateController.text = (address['state'] ?? '').toString();
    _countryController.text = (address['country'] ?? '').toString();
  }

  Future<void> _refreshProfileSetupState() async {
    if (_checkingProfileSetup) return;
    _checkingProfileSetup = true;
    try {
      final hasToken = await _apiClient.hasToken;
      if (!hasToken) {
        if (!mounted) return;
        setState(() {
          _showProfileSetup = false;
          _error = '';
          _saveSuccess = false;
        });
        return;
      }

      Map<String, dynamic>? meRaw;
      try {
        meRaw = await AuthApi().me();
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _showProfileSetup = false;
        });
        return;
      }

      final profile = _normalizeProfile(meRaw);
      final userId = (profile?['id'] ?? profile?['_id'] ?? '').toString();

      if (!mounted) return;
      final store = StoreProvider.of<AppState>(context);
      if (profile != null && profile.isNotEmpty) {
        store.dispatch(SetProfile(profile));
      }

      final needsSetup = _needsProfileSetup(profile);
      final dismissKey = _dismissKey(userId);
      _currentUserId = userId;
      _fillFormFromProfile(profile);

      setState(() {
        if (!needsSetup) {
          _showProfileSetup = false;
          _error = '';
          _saveSuccess = false;
          return;
        }
        _showProfileSetup = !_dismissedSession.contains(dismissKey);
      });
    } finally {
      _checkingProfileSetup = false;
    }
  }

  void _closeForSession() {
    _dismissedSession.add(_dismissKey(_currentUserId));
    setState(() {
      _showProfileSetup = false;
      _error = '';
      _saveSuccess = false;
    });
  }

  Future<void> _saveProfileSetup() async {
    final gender = _gender.trim().toLowerCase();
    final addressLine1 = _addressLine1Controller.text.trim();
    final addressLine2 = _addressLine2Controller.text.trim();
    final pincode = _pincodeController.text.trim();
    final city = _cityController.text.trim();
    final state = _stateController.text.trim();
    final country = _countryController.text.trim();

    if (gender.isEmpty) {
      setState(() => _error = 'Please select your gender.');
      return;
    }
    if (addressLine1.isEmpty ||
        pincode.isEmpty ||
        city.isEmpty ||
        state.isEmpty ||
        country.isEmpty) {
      setState(() {
        _error =
            'Please fill all required address fields (Address Line 1, Pincode, City, State, Country).';
      });
      return;
    }

    if (_currentUserId.isEmpty) {
      setState(() {
        _error = 'User session not found. Please log in again.';
      });
      return;
    }

    setState(() {
      _savingProfileSetup = true;
      _error = '';
      _saveSuccess = false;
    });

    final payload = <String, dynamic>{
      'gender': gender,
      'address': {
        'address_line1': addressLine1,
        'address_line2': addressLine2,
        'pincode': pincode,
        'city': city,
        'state': state,
        'country': country,
      },
      'location': [city, country].where((e) => e.isNotEmpty).join(', '),
    };

    try {
      try {
        await _apiClient.patch('/users/$_currentUserId', body: payload);
      } catch (_) {
        await _apiClient.put('/users/$_currentUserId', body: payload);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _savingProfileSetup = false;
        _error = 'Failed to save profile. Please try again.';
      });
      return;
    }

    await _refreshProfileSetupState();
    if (!mounted) return;
    setState(() {
      _savingProfileSetup = false;
      _saveSuccess = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _showProfileSetup = false;
      _saveSuccess = false;
    });
  }

  Widget _field({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool requiredField = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
            children: [
              TextSpan(text: label),
              if (requiredField)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: Colors.redAccent),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            filled: true,
            fillColor: isDark ? const Color(0xFF061633) : const Color(0xFFF5F5F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF16305E) : const Color(0xFFE5E7EB),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF16305E) : const Color(0xFFE5E7EB),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: DesignTokens.instaPink),
            ),
          ),
        ),
      ],
    );
  }

  Widget _genderOption(String value, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = _gender == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _gender = value;
          _error = '';
        });
      },
      labelStyle: TextStyle(
        color: selected
            ? Colors.white
            : (isDark ? Colors.white70 : Colors.black87),
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: isDark ? const Color(0xFF061633) : const Color(0xFFF5F5F5),
      selectedColor: DesignTokens.instaPink,
      side: BorderSide(
        color: selected
            ? DesignTokens.instaPink
            : (isDark ? const Color(0xFF16305E) : const Color(0xFFE5E7EB)),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.60),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          child: Material(
            color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Complete your profile',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                                children: const [
                                  TextSpan(
                                    text: 'Add gender and address to continue. ',
                                  ),
                                  TextSpan(
                                    text: '* required',
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _savingProfileSetup ? null : _closeForSession,
                        icon: Icon(
                          Icons.close,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_error.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF3A1D1F)
                                  : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _error,
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFFFCA5A5)
                                    : const Color(0xFFB91C1C),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_saveSuccess) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1A3A2A)
                                  : const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Profile saved successfully!',
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFF86EFAC)
                                    : const Color(0xFF166534),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          'Gender *',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _genderOption('male', 'Male'),
                            _genderOption('female', 'Female'),
                            _genderOption('other', 'Other'),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _field(
                          label: 'Address Line 1',
                          hint: 'Flat / House No., Building, Street',
                          controller: _addressLine1Controller,
                          requiredField: true,
                        ),
                        const SizedBox(height: 14),
                        _field(
                          label: 'Address Line 2 (optional)',
                          hint: 'Area, Landmark',
                          controller: _addressLine2Controller,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                label: 'Pincode',
                                hint: '560001',
                                controller: _pincodeController,
                                requiredField: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _field(
                                label: 'City',
                                hint: 'Bengaluru',
                                controller: _cityController,
                                requiredField: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                label: 'State',
                                hint: 'Karnataka',
                                controller: _stateController,
                                requiredField: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _field(
                                label: 'Country',
                                hint: 'India',
                                controller: _countryController,
                                requiredField: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: isDark
                              ? const Color(0xFF3A3A3A)
                              : const Color(0xFFE5E7EB),
                          foregroundColor: isDark ? Colors.white : Colors.black87,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _savingProfileSetup ? null : _closeForSession,
                        child: const Text('Later'),
                      ),
                      const SizedBox(width: 8),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            colors: [
                              DesignTokens.instaPurple,
                              DesignTokens.instaPink,
                              DesignTokens.instaOrange,
                            ],
                          ),
                        ),
                        child: ElevatedButton(
                          onPressed:
                              _savingProfileSetup ? null : _saveProfileSetup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _savingProfileSetup
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Save',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showProfileSetup) _buildModal(),
      ],
    );
  }
}
