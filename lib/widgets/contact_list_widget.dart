import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations.dart';
import '../models/chat_model.dart';
import 'account/online_avatar_badge.dart';
import 'optimized_image.dart';
import 'ui/empty_state.dart';
import 'ui/refreshable.dart';

class ContactListWidget extends StatelessWidget {
  final List<Contact> contacts;

  const ContactListWidget({super.key, required this.contacts});

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) {
      return ScrollableFill(
        child: EmptyState(
          icon: Icons.contacts_outlined,
          title: AppLocalizations.of(context)!.contactListEmpty,
        ),
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        return _buildContactTile(context, contact);
      },
    );
  }

  Widget _buildContactTile(BuildContext context, Contact contact) {
    final colorScheme = Theme.of(context).colorScheme;
    final peerUid = int.tryParse(contact.id.replaceFirst('U', ''));

    final avatar = CircleAvatar(
      backgroundColor: colorScheme.primaryContainer,
      backgroundImage: contact.avatar != null
          ? resizedImageProvider(
              NetworkImage(contact.avatar!),
              MediaQuery.of(context).devicePixelRatio,
              width: 40,
              height: 40,
            )
          : null,
      child: contact.avatar == null
          ? Icon(Icons.person, color: colorScheme.onPrimaryContainer)
          : null,
    );

    return ListTile(
      leading: OnlineAvatarBadge(uid: peerUid, radius: 20, child: avatar),
      title: Text(contact.name),
      onTap: () {
        final userId = contact.id.startsWith('U')
            ? contact.id.substring(1)
            : contact.id;
        context.push('/user/$userId');
      },
    );
  }
}
