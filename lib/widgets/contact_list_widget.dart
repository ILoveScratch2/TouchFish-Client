import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/chat_model.dart';
import 'optimized_image.dart';

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
