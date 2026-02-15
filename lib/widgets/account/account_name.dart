import 'package:flutter/material.dart';
import '../../models/user_profile.dart';

class AccountNameWidget extends StatelessWidget {
  final UserProfile account;
  final TextStyle? style;

  const AccountNameWidget({
    super.key,
    required this.account,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            account.username,
            style: style ?? const TextStyle(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
