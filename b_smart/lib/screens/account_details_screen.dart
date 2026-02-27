import 'package:flutter/material.dart';
import '../services/wallet_service.dart';
import '../models/account_details_model.dart';
import '../theme/instagram_theme.dart';

class AccountDetailsScreen extends StatefulWidget {
  const AccountDetailsScreen({super.key});

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  final WalletService _walletService = WalletService();
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _ifscController = TextEditingController();
  
  String _selectedPaymentMethod = 'UPI';
  bool _isLoading = false;
  AccountDetails? _existingDetails;

  @override
  void initState() {
    super.initState();
    _loadAccountDetails();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _accountNumberController.dispose();
    _bankNameController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  void _loadAccountDetails() {
    final details = _walletService.getAccountDetails();
    if (details != null) {
      setState(() {
        _existingDetails = details;
        _nameController.text = details.accountHolderName;
        _accountNumberController.text = details.accountNumber;
        _selectedPaymentMethod = details.paymentMethod;
        _bankNameController.text = details.bankName ?? '';
        _ifscController.text = details.ifscCode ?? '';
      });
    }
  }

  Future<void> _saveAccountDetails() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final details = AccountDetails(
      id: _existingDetails?.id ?? 'acc-${DateTime.now().millisecondsSinceEpoch}',
      accountHolderName: _nameController.text.trim(),
      paymentMethod: _selectedPaymentMethod,
      accountNumber: _accountNumberController.text.trim(),
      bankName: _selectedPaymentMethod == 'Bank' ? _bankNameController.text.trim() : null,
      ifscCode: _selectedPaymentMethod == 'Bank' ? _ifscController.text.trim() : null,
      createdAt: _existingDetails?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await _walletService.saveAccountDetails(details);

    setState(() {
      _isLoading = false;
    });

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account details saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save. Please check all fields.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deleteAccountDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account Details'),
        content: const Text(
          'Are you sure you want to delete your account details?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _walletService.deleteAccountDetails();
              Navigator.of(context).pop();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account details deleted'),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_existingDetails == null ? 'Add Account Details' : 'Edit Account Details'),
        backgroundColor: Colors.transparent,
        foregroundColor: InstagramTheme.textBlack,
        actions: [
          if (_existingDetails != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteAccountDetails,
              tooltip: 'Delete',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Payment Method Selection
              const Text(
                'Payment Method',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'UPI',
                    label: Text('UPI'),
                  ),
                  ButtonSegment(
                    value: 'Bank',
                    label: Text('Bank'),
                  ),
                  ButtonSegment(
                    value: 'PayPal',
                    label: Text('PayPal'),
                  ),
                ],
                selected: {_selectedPaymentMethod},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _selectedPaymentMethod = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Account Holder Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Account Holder Name',
                  hintText: 'Enter full name',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter account holder name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Account Number / UPI ID
              TextFormField(
                controller: _accountNumberController,
                decoration: InputDecoration(
                  labelText: _selectedPaymentMethod == 'UPI'
                      ? 'UPI ID'
                      : _selectedPaymentMethod == 'Bank'
                          ? 'Account Number'
                          : 'Email / ID',
                  hintText: _selectedPaymentMethod == 'UPI'
                      ? 'yourname@upi'
                      : 'Enter account number',
                  prefixIcon: const Icon(Icons.account_balance_wallet),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter ${_selectedPaymentMethod == 'UPI' ? 'UPI ID' : 'account number'}';
                  }
                  if (_selectedPaymentMethod == 'UPI' && !value.contains('@')) {
                    return 'Please enter a valid UPI ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Bank Name (only for Bank method)
              if (_selectedPaymentMethod == 'Bank') ...[
                TextFormField(
                  controller: _bankNameController,
                  decoration: InputDecoration(
                    labelText: 'Bank Name',
                    hintText: 'Enter bank name',
                    prefixIcon: const Icon(Icons.account_balance),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter bank name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ifscController,
                  decoration: InputDecoration(
                    labelText: 'IFSC Code',
                    hintText: 'Enter IFSC code',
                    prefixIcon: const Icon(Icons.code),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter IFSC code';
                    }
                    if (value.length != 11) {
                      return 'IFSC code must be 11 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveAccountDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _existingDetails == null ? 'Save Details' : 'Update Details',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
