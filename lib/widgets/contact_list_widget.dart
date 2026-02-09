import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/chat_model.dart';
import '../l10n/app_localizations.dart';

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
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        child: contact.avatar != null
            ? null
            : Icon(
                Icons.person,
                color: colorScheme.onPrimaryContainer,
              ),
      ),
      title: Text(contact.name),
      onTap: () {
        context.push('/user/${contact.id}');
      },
    );
  }
}
