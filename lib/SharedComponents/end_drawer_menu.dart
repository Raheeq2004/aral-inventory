import 'package:flutter/material.dart';

class EndDrawerMenu extends StatelessWidget {
  const EndDrawerMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                'Account',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              hoverColor: const Color(0xFFFDE6D2).withValues(alpha: 0.7),
              splashColor: const Color(0xFFFDE6D2),
              leading: const Icon(Icons.lock_reset_rounded),
              title: const Text('Change password'),
              onTap: () {
                Navigator.pop(context); // Close the drawer first
                _showChangePasswordDialog(context);
              },
            ),
            const Spacer(),
            const Divider(height: 1),
            ListTile(
              hoverColor: Colors.red.withValues(alpha: 0.08),
              splashColor: Colors.red.withValues(alpha: 0.15),
              leading: const Icon(Icons.logout_rounded, color: Colors.red),
              title: const Text(
                'Log out',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(context); // Close the drawer first
                // TODO: Run your sign-out logic and navigate to login/landing page
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showChangePasswordDialog(BuildContext parentContext) async {
  final TextEditingController passwordController = TextEditingController();
  final scaffoldMessenger = ScaffoldMessenger.of(parentContext);
  bool obscurePassword = true;
  String? errorText;

  await showDialog<void>(
    context: parentContext,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Change password',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: TextField(
              controller: passwordController,
              obscureText: obscurePassword,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'New password',
                hintText: 'Enter new password',
                errorText: errorText,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setDialogState(() {
                      obscurePassword = !obscurePassword;
                    });
                  },
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final newPassword = passwordController.text.trim();
                  if (newPassword.length < 6) {
                    setDialogState(() {
                      errorText = 'Password must be at least 6 characters';
                    });
                    return;
                  }

                  Navigator.pop(dialogContext);

                  // TODO: Hook up your actual password update logic (e.g., Firebase / API)
                  // using `newPassword`.

                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Password updated successfully'),
                    ),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );

  // Dispose after the dialog route has completely finished unmounting
  WidgetsBinding.instance.addPostFrameCallback((_) {
    passwordController.dispose();
  });
}
