import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/chat_model.dart';
import '../l10n/app_localizations.dart';
import '../screens/user_profile_screen.dart';

class ContactListWidget extends StatelessWidget {
  final List<Contact> contacts;

  const ContactListWidget({
    super.key,
    required this.contacts,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        return _buildContactTile(context, contact);
      },
    );
  }

  Widget _buildContactTile(BuildContext context, Contact contact) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: colorScheme.primaryContainer,
            child: contact.avatar != null
                ? null
                : Icon(
                    Icons.person,
                    color: colorScheme.onPrimaryContainer,
                  ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _getStatusColor(context, contact.status),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.surface,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
      title: Text(contact.name),
      subtitle: contact.status != null
          ? Text(
              _getStatusText(l10n, contact.status!),
              style: TextStyle(
                color: _getStatusColor(context, contact.status),
              ),
            )
          : null,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => UserProfileScreen(
              userId: contact.id,
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(BuildContext context, String? status) {
    final colorScheme = Theme.of(context).colorScheme;
    
    if (status == null) return colorScheme.onSurfaceVariant;
    
    switch (status) {
      case '在线':
        return Colors.green;
      case 'Online':
        return Colors.green;
      case '离开':
        return Colors.orange;
      case 'Away':
        return Colors.orange;
      case '离线':
        return colorScheme.onSurfaceVariant;
      case 'Offline':
        return colorScheme.onSurfaceVariant;
      case '很忙':
        return Colors.red;
      case 'Busy':
        return Colors.red;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }

  String _getStatusText(AppLocalizations l10n, String status) {
    switch (status) {
      case '在线':
        return l10n.chatOnline;
      case 'Online':
        return l10n.chatOnline;
      case '离开':
        return l10n.chatAway;
      case 'Away':
        return l10n.chatAway;
      case '离线':
        return l10n.chatOffline;
      case 'Offline':
        return l10n.chatOffline;
      default:
        return status;
    }
  }
}
