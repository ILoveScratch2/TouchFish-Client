import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/chat_model.dart';

class ContactListWidget extends StatelessWidget {
  final List<Contact> contacts;

  const ContactListWidget({super.key, required this.contacts});

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
        backgroundImage: contact.avatar != null
            ? NetworkImage(contact.avatar!)
            : null,
        child: contact.avatar == null
            ? Icon(Icons.person, color: colorScheme.onPrimaryContainer)
            : null,
      ),
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
