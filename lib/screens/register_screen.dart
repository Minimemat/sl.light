import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/auth_bloc.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _stateProvinceController = TextEditingController();

  bool _obscurePassword = true;
  bool _agreeToTerms = false;
  bool _registerForWarranty = false;
  String _selectedCountry = 'Canada';
  DateTime? _installationDate = DateTime.now();

  final List<String> _countries = ['Canada', 'United States'];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _stateProvinceController.dispose();
    super.dispose();
  }

  void _onRegister() {
    if (_formKey.currentState!.validate()) {
      if (!_agreeToTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please agree to Terms & Conditions')),
        );
        return;
      }

      if (_registerForWarranty && _installationDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select installation date')),
        );
        return;
      }

      context.read<AuthBloc>().add(
        AuthRegisterRequested(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          firstName: _registerForWarranty
              ? _firstNameController.text.trim()
              : null,
          lastName: _registerForWarranty
              ? _lastNameController.text.trim()
              : null,
          phone: _registerForWarranty ? _phoneController.text.trim() : null,
          address: _registerForWarranty ? _addressController.text.trim() : null,
          city: _registerForWarranty ? _cityController.text.trim() : null,
          postalCode: _registerForWarranty
              ? _postalCodeController.text.trim()
              : null,
          province: _registerForWarranty
              ? _stateProvinceController.text.trim()
              : null,
          country: _registerForWarranty ? _selectedCountry : null,
          installationDate: _registerForWarranty ? _installationDate : null,
          registerForWarranty: _registerForWarranty,
        ),
      );
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+').hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateRequired(String? value, String fieldName) {
    if (_registerForWarranty && (value == null || value.isEmpty)) {
      return 'Please enter your $fieldName';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (!_registerForWarranty) return null;
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your phone number';
    }
    final digitsOnly = value.replaceAll(RegExp(r'[^0-9+]'), '');
    // For CA/US, require 10 digits (optionally with country code)
    if (_selectedCountry == 'Canada' || _selectedCountry == 'United States') {
      final tenDigits = RegExp(r'^\+?1?[0-9]{10}$');
      return tenDigits.hasMatch(digitsOnly)
          ? null
          : 'Enter a valid phone number';
    }
    // Generic: 7-15 digits
    final generic = RegExp(r'^\+?[0-9]{7,15}$');
    return generic.hasMatch(digitsOnly) ? null : 'Enter a valid phone number';
  }

  String? _validatePostal(String? value) {
    if (!_registerForWarranty) return null;
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your postal/zip code';
    }
    final trimmed = value.trim();
    if (_selectedCountry == 'Canada') {
      final ca = RegExp(r'^[A-Za-z]\d[A-Za-z][\s-]?\d[A-Za-z]\d$');
      return ca.hasMatch(trimmed) ? null : 'Enter a valid Canadian postal code';
    }
    if (_selectedCountry == 'United States') {
      final us = RegExp(r'^\d{5}(?:-\d{4})?$');
      return us.hasMatch(trimmed) ? null : 'Enter a valid US ZIP code';
    }
    return null;
  }

  // Valid state/province names for US and Canada (full names; case-insensitive match)
  static const List<String> _caStates = [
    'Alberta',
    'British Columbia',
    'Manitoba',
    'New Brunswick',
    'Newfoundland and Labrador',
    'Northwest Territories',
    'Nova Scotia',
    'Nunavut',
    'Ontario',
    'Prince Edward Island',
    'Quebec',
    'Saskatchewan',
    'Yukon',
  ];

  static const List<String> _usStatesFull = [
    'Alabama',
    'Alaska',
    'Arizona',
    'Arkansas',
    'California',
    'Colorado',
    'Connecticut',
    'Delaware',
    'Florida',
    'Georgia',
    'Hawaii',
    'Idaho',
    'Illinois',
    'Indiana',
    'Iowa',
    'Kansas',
    'Kentucky',
    'Louisiana',
    'Maine',
    'Maryland',
    'Massachusetts',
    'Michigan',
    'Minnesota',
    'Mississippi',
    'Missouri',
    'Montana',
    'Nebraska',
    'Nevada',
    'New Hampshire',
    'New Jersey',
    'New Mexico',
    'New York',
    'North Carolina',
    'North Dakota',
    'Ohio',
    'Oklahoma',
    'Oregon',
    'Pennsylvania',
    'Rhode Island',
    'South Carolina',
    'South Dakota',
    'Tennessee',
    'Texas',
    'Utah',
    'Vermont',
    'Virginia',
    'Washington',
    'West Virginia',
    'Wisconsin',
    'Wyoming',
  ];

  String? _validateStateProvince(String? value) {
    if (!_registerForWarranty) return null;
    if (value == null || value.trim().isEmpty)
      return 'Please enter your state/province';
    final input = value.trim().toLowerCase();
    List<String> valid;
    if (_selectedCountry == 'Canada') {
      valid = _caStates;
    } else if (_selectedCountry == 'United States') {
      valid = _usStatesFull;
    } else {
      // Only US/Canada allowed
      return 'Please select Canada or United States';
    }
    final isValid = valid.any((n) => n.toLowerCase() == input);
    return isValid ? null : 'Enter a valid state/province name';
  }

  bool _isRegisterEnabled(AuthState state) {
    // Don't enable if currently authenticating
    if (state is AuthAuthenticating) return false;

    // Check basic required fields (always required)
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      return false;
    }

    // Check if terms are agreed to (always required)
    if (!_agreeToTerms) return false;

    // If NOT registering for warranty, only basic fields are needed
    if (!_registerForWarranty) {
      return true; // Email, password, and terms are all that's needed
    }

    // If warranty IS selected, check all warranty fields
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty ||
        _cityController.text.trim().isEmpty ||
        _postalCodeController.text.trim().isEmpty ||
        _stateProvinceController.text.trim().isEmpty ||
        _installationDate == null) {
      return false;
    }

    return true;
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms & Conditions'),
        content: const SingleChildScrollView(child: Text('TOS here')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showWarrantyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Warranty Information'),
        content: const SingleChildScrollView(child: Text('Warranty info here')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectInstallationDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _installationDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(), // No future dates
    );
    if (picked != null && picked != _installationDate) {
      setState(() {
        _installationDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register'), centerTitle: true),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Join the Stay Lit community',
                          style: TextStyle(fontSize: 16, color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: _validateEmail,
                          enabled: state is! AuthAuthenticating,
                          onChanged: (value) => setState(() {}),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          validator: _validatePassword,
                          enabled: state is! AuthAuthenticating,
                          onChanged: (value) => setState(() {}),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Checkbox(
                              value: _agreeToTerms,
                              onChanged: (value) {
                                setState(() {
                                  _agreeToTerms = value ?? false;
                                });
                              },
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _agreeToTerms = !_agreeToTerms;
                                  });
                                },
                                child: RichText(
                                  text: TextSpan(
                                    text: 'I agree to ',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                    children: [
                                      WidgetSpan(
                                        child: GestureDetector(
                                          onTap: _showTermsDialog,
                                          child: const Text(
                                            'Terms & Conditions',
                                            style: TextStyle(
                                              color: Colors.blue,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Warranty Registration Checkbox (in container)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    value: _registerForWarranty,
                                    onChanged: (value) {
                                      setState(() {
                                        _registerForWarranty = value ?? false;
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _registerForWarranty =
                                              !_registerForWarranty;
                                        });
                                      },
                                      child: RichText(
                                        text: TextSpan(
                                          text:
                                              'Register for warranty: 10 years on all products and parts, lifetime warranty on the lights (',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                          children: [
                                            WidgetSpan(
                                              child: GestureDetector(
                                                onTap: _showWarrantyDialog,
                                                child: const Text(
                                                  'Warranty Terms',
                                                  style: TextStyle(
                                                    color: Colors.blue,
                                                    decoration: TextDecoration
                                                        .underline,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const TextSpan(
                                              text: ')',
                                              style: TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Warranty Fields (outside container)
                        if (_registerForWarranty) ...[
                          const SizedBox(height: 24),

                          // Personal Information Section
                          const Text(
                            'Personal Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _firstNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'First Name',
                                  ),
                                  validator: (value) =>
                                      _validateRequired(value, 'first name'),
                                  enabled: state is! AuthAuthenticating,
                                  onChanged: (value) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _lastNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Last Name',
                                  ),
                                  validator: (value) =>
                                      _validateRequired(value, 'last name'),
                                  enabled: state is! AuthAuthenticating,
                                  onChanged: (value) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            validator: _validatePhone,
                            enabled: state is! AuthAuthenticating,
                            onChanged: (value) => setState(() {}),
                          ),

                          const SizedBox(height: 32),

                          // Address Information Section
                          const Text(
                            'Address Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _addressController,
                            decoration: const InputDecoration(
                              labelText: 'Address',
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
                            validator: (value) =>
                                _validateRequired(value, 'address'),
                            enabled: state is! AuthAuthenticating,
                            onChanged: (value) => setState(() {}),
                          ),
                          const SizedBox(height: 20),

                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _cityController,
                                  decoration: const InputDecoration(
                                    labelText: 'City',
                                  ),
                                  validator: (value) =>
                                      _validateRequired(value, 'city'),
                                  enabled: state is! AuthAuthenticating,
                                  onChanged: (value) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _postalCodeController,
                                  decoration: const InputDecoration(
                                    labelText: 'Postal Code',
                                  ),
                                  validator: _validatePostal,
                                  enabled: state is! AuthAuthenticating,
                                  onChanged: (value) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // State/Province and Country (side by side)
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _stateProvinceController,
                                  decoration: const InputDecoration(
                                    labelText: 'State/Province',
                                  ),
                                  validator: _validateStateProvince,
                                  enabled: state is! AuthAuthenticating,
                                  onChanged: (value) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedCountry,
                                  decoration: const InputDecoration(
                                    labelText: 'Country',
                                  ),
                                  items: _countries.map((String country) {
                                    return DropdownMenuItem<String>(
                                      value: country,
                                      child: Text(country),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _selectedCountry = newValue!;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // Installation Information Section
                          const Text(
                            'Installation Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),

                          InkWell(
                            onTap: state is! AuthAuthenticating
                                ? _selectInstallationDate
                                : null,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Installation Date',
                                prefixIcon: Icon(Icons.calendar_today_outlined),
                              ),
                              child: Text(
                                _installationDate != null
                                    ? '${_installationDate!.day}/${_installationDate!.month}/${_installationDate!.year}'
                                    : 'Select date',
                                style: TextStyle(
                                  color: _installationDate != null
                                      ? Colors.white
                                      : Colors.white54,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),
                        if (state is AuthError)
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              border: Border.all(color: Colors.red),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              state.message,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isRegisterEnabled(state)
                                ? _onRegister
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isRegisterEnabled(state)
                                  ? null
                                  : Colors.grey.withOpacity(0.3),
                              foregroundColor: _isRegisterEnabled(state)
                                  ? null
                                  : Colors.grey.withOpacity(0.7),
                            ),
                            child: state is AuthAuthenticating
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text('Creating account...'),
                                    ],
                                  )
                                : Text(
                                    'Register',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: _isRegisterEnabled(state)
                                          ? null
                                          : Colors.grey.withOpacity(0.7),
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
