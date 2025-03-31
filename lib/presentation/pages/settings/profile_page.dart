import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task_management_app/core/routing/navigation_helpers.dart';
import 'package:task_management_app/cubits/auth/cubit/auth_cubit.dart' as auth;
import 'package:task_management_app/domain/models/user.model.dart';
import 'package:intl/intl.dart';
import 'package:task_management_app/domain/models/user.model.dart' as user;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  File? _avatarFile;
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();

    // Load current user data
    final authState = context.read<auth.AuthCubit>().state;
    if (authState is auth.AuthAuthenticated) {
      _nameController.text = authState.user.fullName ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // Reduce image size
        maxWidth: 800, // Constrain dimensions
      );

      if (image != null) {
        setState(() {
          _avatarFile = File(image.path);
        });
      } else {
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
      print(e);
      return;
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authState = context.read<auth.AuthCubit>().state;
      final bucketName = 'avatars';
      final baseUrl =
          'https://chwswwssmegejiknagqz.supabase.co/storage/v1/object/public/';
      if (authState is! auth.AuthAuthenticated) return;

      String? avatarUrl;
      // Upload avatar if selected
      if (_avatarFile != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final fileBytes = await _avatarFile!.readAsBytes();

        await Supabase.instance.client.storage
            .from('avatars')
            .uploadBinary(fileName, fileBytes);

        avatarUrl = avatarUrl = '$baseUrl$bucketName/$fileName';
      }

      // Update user profile in the backend
      await Supabase.instance.client
          .from('profiles')
          .update({
            'full_name': _nameController.text.trim(),
            if (avatarUrl != null) 'avatar_url': avatarUrl,
          })
          .eq('id', authState.user.id);

      if (mounted) {
        // Refresh auth state to get updated user data
        await context.read<auth.AuthCubit>().verifySession();
      }

      setState(() {
        _isEditing = false;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await context.read<auth.AuthCubit>().signOut();
      if (mounted) {
        context.goToLogin();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<auth.AuthCubit, auth.AuthState>(
      listener: (context, state) {
        if (state is auth.AuthLoading) {
          setState(() {
            _isLoading = true;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      },
      builder: (context, state) {
        if (state is auth.AuthLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is auth.AuthUnauthenticated) {
          return const Center(
            child: Text('Please sign in to view your profile'),
          );
        }

        if (state is auth.AuthAuthenticated) {
          return _buildProfileContent(context, state.user);
        }

        return const Center(child: Text('Something went wrong'));
      },
    );
  }

  Widget _buildProfileContent(BuildContext context, user.User user) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                  _nameController.text = user.fullName ?? '';
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _avatarFile = null;
                });
              },
            ),
        ],
      ),
      body: _isEditing ? _buildEditForm(user) : _buildProfileView(user),
    );
  }

  Widget _buildProfileView(user.User user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildProfileHeader(user),
          const SizedBox(height: 32),
          _buildInfoCard(user),
          const SizedBox(height: 16),
          _buildStatsCard(user),
          const SizedBox(height: 16),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(user.User user) {
    return Column(
      children: [
        // Avatar
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.shade200,
          ),
          child: ClipOval(
            child:
                user.avatarUrl != null
                    ? Image.network(
                      user.avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Text(
                            user.initials,
                            style: const TextStyle(
                              fontSize: 40,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      },
                    )
                    : Center(
                      child: Text(
                        user.initials,
                        style: const TextStyle(
                          fontSize: 40,
                          color: Colors.grey,
                        ),
                      ),
                    ),
          ),
        ),
        const SizedBox(height: 16),

        // Name
        Text(
          user.fullName ?? 'No Name',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildInfoCard(user.User user) {
    final createdDate = DateFormat('MMMM d, yyyy').format(user.createdAt);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Account Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildInfoRow(Icons.email, 'Email', user.email),
            const Divider(),
            _buildInfoRow(Icons.calendar_today, 'Member Since', createdDate),
            const Divider(),
            _buildInfoRow(
              Icons.circle,
              'Status',
              user.status.name,
              statusColor: _getStatusColor(user.status),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(user.User user) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Task Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Active', '12', Colors.blue),
                _buildStatItem('Completed', '24', Colors.green),
                _buildStatItem('Total', '36', Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? statusColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: statusColor ?? Colors.blue),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                Text(value, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _signOut,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.logout),
              SizedBox(width: 8),
              Text('Sign Out'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditForm(user.User user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar with edit option
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage:
                      _avatarFile != null
                          ? FileImage(_avatarFile!)
                          : (user.avatarUrl != null
                              ? NetworkImage(user.avatarUrl!)
                              : null),
                  child:
                      (_avatarFile == null && user.avatarUrl == null)
                          ? Text(
                            user.initials,
                            style: const TextStyle(
                              fontSize: 40,
                              color: Colors.grey,
                            ),
                          )
                          : null,
                ),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Name field
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Email (disabled)
            TextFormField(
              initialValue: user.email,
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
                helperText: 'Email cannot be changed',
              ),
            ),
            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child:
                    _isLoading
                        ? const CircularProgressIndicator()
                        : const Text(
                          'Save Changes',
                          style: TextStyle(fontSize: 16),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(UserStatus status) {
    switch (status) {
      case UserStatus.active:
        return Colors.green;
      case UserStatus.inactive:
        return Colors.grey;
      case UserStatus.pending:
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}
