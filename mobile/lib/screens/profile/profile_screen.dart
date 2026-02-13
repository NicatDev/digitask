import 'dart:io';
import 'package:mobile/core/api/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:http_parser/http_parser.dart'; // Transitive dependency usually available

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isSaving = false;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _usernameController = TextEditingController();
  final _roleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    try {
      final response = await ApiClient().dio.get('/users/me/');
      if (response.statusCode == 200) {
        final data = response.data;
        setState(() {
          _userData = data;
          _firstNameController.text = data['first_name'] ?? '';
          _lastNameController.text = data['last_name'] ?? '';
          _emailController.text = data['email'] ?? '';
          _phoneController.text = data['phone_number'] ?? '';
          _usernameController.text = data['username'] ?? '';
          
           // Determine group/role name safely
          String roleText = 'User';
          if (data['group_name'] != null && data['group_name'].toString().isNotEmpty) {
            roleText = data['group_name'];
          } else if (data['role_name'] != null) {
            roleText = data['role_name'];
          }
          _roleController.text = roleText;

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isSaving = true);
    try {
      final data = {
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'email': _emailController.text,
        'phone_number': _phoneController.text,
      };
      
      await ApiClient().dio.patch('/users/me/', data: data);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        _fetchUserProfile(); // Refresh data
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image == null) return;

    setState(() => _isSaving = true);
    try {
      String fileName = image.path.split('/').last;
      
      // Ensure filename has an extension. If not, default to .jpg (common for camera/gallery)
      if (!fileName.contains('.')) {
        fileName = '$fileName.jpg';
      }
      
      // Read bytes to avoid dart:io File issues in some contexts
      final bytes = await image.readAsBytes();
      
      FormData formData = FormData.fromMap({
        'avatar': MultipartFile.fromBytes(
          bytes, 
          filename: fileName,
          // content-type is usually inferred by Dio from filename extension
        ),
      });

      await ApiClient().dio.patch('/users/me/', data: formData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar updated successfully')),
        );
        _fetchUserProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload avatar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showChangePasswordModal() {
    final passController = TextEditingController();
    final confirmController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          left: 24, 
          right: 24, 
          top: 24
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Change Password', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextField(
              controller: passController,
              decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder()),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmController,
              decoration: const InputDecoration(labelText: 'Confirm Password', border: OutlineInputBorder()),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (passController.text != confirmController.text) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Passwords do not match')),
                    );
                    return;
                  }
                  if (passController.text.length < 6) {
                     ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password must be at least 6 characters')),
                    );
                    return;
                  }

                  Navigator.pop(ctx);
                  setState(() => _isSaving = true);
                  
                  try {
                    await ApiClient().dio.patch('/users/me/', data: {'password': passController.text});
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Password changed successfully')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to change password: $e')),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isSaving = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Update Password'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // Light grey background
      appBar: AppBar(
        title: const Text('My Profile'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userData == null
              ? const Center(child: Text('Failed to load profile'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Section 1: Avatar
                      _buildSection(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _pickAndUploadAvatar,
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 50,
                                    backgroundImage: _userData!['avatar'] != null
                                        ? NetworkImage(_userData!['avatar'])
                                        : null,
                                    child: _userData!['avatar'] == null
                                        ? const Icon(Icons.person, size: 50)
                                        : null,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tap to change avatar',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Section 2: Details
                      _buildSection(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Account Details',
                               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 24),
                            TextField(
                              controller: _usernameController,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Username', 
                                border: OutlineInputBorder(),
                                fillColor: Color(0xFFEEEEEE),
                                filled: true,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _roleController,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Role', 
                                border: OutlineInputBorder(),
                                fillColor: Color(0xFFEEEEEE),
                                filled: true,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _firstNameController,
                              decoration: const InputDecoration(labelText: 'First Name', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _lastNameController,
                              decoration: const InputDecoration(labelText: 'Last Name', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _emailController,
                              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _phoneController,
                              decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 24),
                            if (_isSaving)
                              const Center(child: CircularProgressIndicator())
                            else
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _updateProfile,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Save Changes'),
                                ),
                              ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: _showChangePasswordModal,
                                child: const Text('Change Password', style: TextStyle(color: Colors.red)),
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
