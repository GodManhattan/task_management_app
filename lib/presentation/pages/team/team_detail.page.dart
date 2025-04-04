// lib/presentation/pages/team/team_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:task_management_app/cubits/auth/cubit/auth_cubit.dart';
import 'package:task_management_app/cubits/team/cubit/team_cubit.dart';
import 'package:task_management_app/cubits/user/cubit/user_cubit.dart';
import 'package:task_management_app/domain/models/team.model.dart';
import 'package:task_management_app/domain/models/user.model.dart';

class TeamDetailPage extends StatefulWidget {
  final String teamId;
  const TeamDetailPage({super.key, required this.teamId});

  @override
  State<TeamDetailPage> createState() => _TeamDetailPageState();
}

// lib/presentation/pages/team/team_detail_page.dart (continued)
class _TeamDetailPageState extends State<TeamDetailPage> {
  bool _isLoading = true;
  Team? _loadedTeam;
  bool _hasInitiallyLoaded = false;

  @override
  void initState() {
    super.initState();
    // Load the team on page load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTeamDetails();
    });
  }

  void _loadTeamDetails() {
    if (mounted) {
      context.read<TeamCubit>().loadTeamById(widget.teamId);
      // Subscribe to real-time updates for team members
      context.read<TeamCubit>().subscribeToTeamMembers(widget.teamId);
    }
  }

  void _showDeleteConfirmation(BuildContext context, Team team) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Team'),
            content: Text('Are you sure you want to delete "${team.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.read<TeamCubit>().deleteTeam(team.id).then((_) {
                    context.go('/team'); // Navigate back after deletion
                  });
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  void _showAddMemberDialog(BuildContext context, Team team) {
    showDialog(
      context: context,
      builder: (context) => AddMemberDialog(teamId: team.id),
    );
  }

  void _showEditTeamDialog(BuildContext context, Team team) {
    showDialog(
      context: context,
      builder: (context) => EditTeamDialog(team: team),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Details'),
        actions: [
          BlocBuilder<TeamCubit, TeamState>(
            builder: (context, state) {
              if (state is TeamDetailLoaded) {
                final team = state.team;
                final authState = context.read<AuthCubit>().state;

                // Only show edit/delete if user is the owner
                if (authState is AuthAuthenticated &&
                    authState.user.id == team.ownerId) {
                  return Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showEditTeamDialog(context, team),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _showDeleteConfirmation(context, team),
                      ),
                    ],
                  );
                }
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocConsumer<TeamCubit, TeamState>(
        listener: (context, state) {
          if (state is TeamDetailLoaded) {
            // Store the loaded team for backup
            _loadedTeam = state.team;
            _hasInitiallyLoaded = true;
          }

          if (state is TeamOperationSuccess) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          } else if (state is TeamError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is TeamLoading && !_hasInitiallyLoaded) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is TeamDetailLoaded) {
            _loadedTeam = state.team; // Keep the cached team updated
            return _buildTeamDetail(context, state.team);
          } else if (_loadedTeam != null) {
            // Use the cached team if available
            return _buildTeamDetail(context, _loadedTeam!);
          } else if (state is TeamError) {
            return Center(
              child: Text(
                state.message,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          // If we get here, reload the team
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadTeamDetails();
          });

          return const Center(child: CircularProgressIndicator());
        },
      ),
      floatingActionButton: BlocBuilder<TeamCubit, TeamState>(
        builder: (context, state) {
          if (state is TeamDetailLoaded || _loadedTeam != null) {
            final team = state is TeamDetailLoaded ? state.team : _loadedTeam!;
            final authState = context.read<AuthCubit>().state;

            // Only show add member button if user is owner or admin
            if (authState is AuthAuthenticated) {
              final userId = authState.user.id;
              final userRole = _getUserRole(team, userId);

              if (userRole == TeamRole.owner || userRole == TeamRole.admin) {
                return FloatingActionButton(
                  onPressed: () => _showAddMemberDialog(context, team),
                  tooltip: 'Add Member',
                  child: const Icon(Icons.person_add),
                );
              }
            }
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  TeamRole? _getUserRole(Team team, String userId) {
    final member = team.members.where((m) => m.userId == userId).firstOrNull;
    return member?.role;
  }

  Widget _buildTeamDetail(BuildContext context, Team team) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            margin: const EdgeInsets.only(top: 16, bottom: 24),
            child: ListTile(
              leading: const Icon(Icons.task_alt, color: Colors.blue),
              title: const Text('Team Tasks'),
              subtitle: const Text(
                'View and manage tasks assigned to this team',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.push('/team/${team.id}/tasks');
              },
            ),
          ),
          // Team header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          team.name.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              team.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (team.description != null) ...[
                              const SizedBox(height: 8),
                              Text(team.description!),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Text(
            'Team Members',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // List of team members
          _buildMembersList(context, team),
        ],
      ),
    );
  }

  Widget _buildMembersList(BuildContext context, Team team) {
    final authState = context.read<AuthCubit>().state;
    final isOwner =
        authState is AuthAuthenticated && authState.user.id == team.ownerId;

    if (team.members.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No members in this team yet'),
        ),
      );
    }

    // Preload all user data
    final userIds = team.members.map((m) => m.userId).toList();
    context.read<UserCubit>().preloadUsers(userIds);

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: team.members.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final member = team.members[index];
        return _buildMemberItem(context, member, team, isOwner);
      },
    );
  }

  Widget _buildMemberItem(
    BuildContext context,
    TeamMember member,
    Team team,
    bool isCurrentUserOwner,
  ) {
    final userCubit = context.read<UserCubit>();
    final authState = context.read<AuthCubit>().state;
    final isCurrentUser =
        authState is AuthAuthenticated && authState.user.id == member.userId;

    // Check if current user can manage this member
    final canManageMember =
        isCurrentUserOwner ||
        (member.role != TeamRole.owner &&
            _getUserRole(team, (authState as AuthAuthenticated).user.id) ==
                TeamRole.admin);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // User avatar
            BlocBuilder<UserCubit, UserState>(
              buildWhen: (previous, current) {
                return current is UserLoaded &&
                    current.user.id == member.userId;
              },
              builder: (context, state) {
                final user = userCubit.getUserFromCache(member.userId);

                return CircleAvatar(
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage:
                      user?.avatarUrl != null
                          ? NetworkImage(user!.avatarUrl!)
                          : null,
                  child:
                      user?.avatarUrl == null
                          ? Text(user?.initials ?? '?')
                          : null,
                );
              },
            ),

            const SizedBox(width: 12),

            // User info
            Expanded(
              child: BlocBuilder<UserCubit, UserState>(
                buildWhen: (previous, current) {
                  return current is UserLoaded &&
                      current.user.id == member.userId;
                },
                builder: (context, state) {
                  final userName = userCubit.getDisplayName(member.userId);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getRoleColor(member.role),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              member.role.name.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isCurrentUser) ...[
                            const SizedBox(width: 8),
                            const Text(
                              '(You)',
                              style: TextStyle(fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),

            // Action buttons
            if (canManageMember && !isCurrentUser) ...[
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  switch (value) {
                    case 'change_role':
                      _showChangeRoleDialog(context, member, team);
                      break;
                    case 'remove':
                      _showRemoveMemberConfirmation(context, member, team);
                      break;
                  }
                },
                itemBuilder:
                    (context) => [
                      if (isCurrentUserOwner) ...[
                        const PopupMenuItem(
                          value: 'change_role',
                          child: Text('Change Role'),
                        ),
                      ],
                      const PopupMenuItem(
                        value: 'remove',
                        child: Text('Remove from Team'),
                      ),
                    ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showChangeRoleDialog(
    BuildContext context,
    TeamMember member,
    Team team,
  ) {
    showDialog(
      context: context,
      builder: (context) => ChangeRoleDialog(member: member, teamId: team.id),
    );
  }

  void _showRemoveMemberConfirmation(
    BuildContext context,
    TeamMember member,
    Team team,
  ) {
    final userCubit = context.read<UserCubit>();
    final userName = userCubit.getDisplayName(member.userId);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Remove Member'),
            content: Text(
              'Are you sure you want to remove $userName from the team?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.read<TeamCubit>().removeTeamMember(
                    team.id,
                    member.userId,
                  );
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Remove'),
              ),
            ],
          ),
    );
  }

  Color _getRoleColor(TeamRole role) {
    switch (role) {
      case TeamRole.owner:
        return Colors.purple.shade100;
      case TeamRole.admin:
        return Colors.orange.shade100;
      case TeamRole.member:
        return Colors.blue.shade100;
      default:
        return Colors.grey.shade100;
    }
  }
}

class EditTeamDialog extends StatefulWidget {
  final Team team;

  const EditTeamDialog({super.key, required this.team});

  @override
  State<EditTeamDialog> createState() => _EditTeamDialogState();
}

class _EditTeamDialogState extends State<EditTeamDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.team.name);
    _descriptionController = TextEditingController(
      text: widget.team.description,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _updateTeam() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedTeam = widget.team.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
      );

      await context.read<TeamCubit>().updateTeam(updatedTeam);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update team: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Team'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Team Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a team name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateTeam,
          child:
              _isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('Save'),
        ),
      ],
    );
  }
}

class AddMemberDialog extends StatefulWidget {
  final String teamId;

  const AddMemberDialog({super.key, required this.teamId});

  @override
  State<AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<AddMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  TeamRole _selectedRole = TeamRole.member;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _addMember() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // In a real app, you would first search for a user by email
      // and then add them to the team with their userId

      // For simplicity, let's implement this with a placeholder message

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'User lookup by email not implemented. In a complete app, we would search for the user by email and add them to the team.',
            ),
          ),
        );
      }

      // In the complete implementation:
      // 1. Look up user by email
      // 2. If found, add to team:
      // await context.read<TeamCubit>().addTeamMember(
      //   widget.teamId,
      //   foundUser.id,
      //   role: _selectedRole,
      // );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add member: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Team Member'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'Enter user\'s email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an email';
                }
                if (!RegExp(
                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                ).hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TeamRole>(
              decoration: const InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(),
              ),
              value: _selectedRole,
              items:
                  TeamRole.values
                      .map((role) {
                        // Don't allow adding owners through this dialog
                        if (role == TeamRole.owner) return null;

                        return DropdownMenuItem(
                          value: role,
                          child: Text(role.name),
                        );
                      })
                      .whereType<DropdownMenuItem<TeamRole>>()
                      .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedRole = value;
                  });
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addMember,
          child:
              _isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('Add'),
        ),
      ],
    );
  }
}

class ChangeRoleDialog extends StatefulWidget {
  final TeamMember member;
  final String teamId;

  const ChangeRoleDialog({
    super.key,
    required this.member,
    required this.teamId,
  });

  @override
  State<ChangeRoleDialog> createState() => _ChangeRoleDialogState();
}

class _ChangeRoleDialogState extends State<ChangeRoleDialog> {
  late TeamRole _selectedRole;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.member.role;
  }

  Future<void> _updateRole() async {
    if (_selectedRole == widget.member.role) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await context.read<TeamCubit>().updateMemberRole(
        widget.teamId,
        widget.member.userId,
        _selectedRole,
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update role: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userCubit = context.read<UserCubit>();
    final userName = userCubit.getDisplayName(widget.member.userId);

    return AlertDialog(
      title: const Text('Change Role'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Change role for $userName:'),
          const SizedBox(height: 16),
          DropdownButtonFormField<TeamRole>(
            decoration: const InputDecoration(
              labelText: 'Role',
              border: OutlineInputBorder(),
            ),
            value: _selectedRole,
            items:
                TeamRole.values
                    .map((role) {
                      // Don't allow changing to owner
                      if (role == TeamRole.owner) return null;

                      return DropdownMenuItem(
                        value: role,
                        child: Text(role.name),
                      );
                    })
                    .whereType<DropdownMenuItem<TeamRole>>()
                    .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedRole = value;
                });
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateRole,
          child:
              _isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('Save'),
        ),
      ],
    );
  }
}
