import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:localization/localization.dart';

import '../recipe_generator.dart';
class UpdatePasswordScreen extends StatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
   _UpdatePasswordScreenState createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _currentPasswordController =
    TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  Future<void> _updatePassword() async {
    try {
      // Step 1: Get the current user
      var user = _auth.currentUser;
      if (user != null) {
        // Step 2: Reauthenticate the user to verify their current password
        var credentials = EmailAuthProvider.credential(
          email: user.email!,
          password: _currentPasswordController.text,
        );
        await user.reauthenticateWithCredential(credentials);

        // Step 3: Update the password
        await user.updatePassword(_newPasswordController.text).then((_) {

            // Step 4: Show success message and navigate back
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('pass-update'.i18n()),
                content: Text('updated-password'.i18n()),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context)=>const RecipeGenerator(),),),
                    child: Text('ok'.i18n()),
                  ),
                ],
              ),
            );
        });
      }
    } on FirebaseAuthException catch (e) {
      // Handle any errors that occur during password update
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('error'.i18n()),
          content: Text('pass-error $e'.i18n()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('ok'.i18n()),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('update-pass-title'.i18n()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _currentPasswordController,
              decoration: InputDecoration(labelText: 'current-password'.i18n()),
              obscureText: true,
            ),
            TextFormField(
              controller: _newPasswordController,
              decoration: InputDecoration(labelText: 'new-password'.i18n()),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _updatePassword,
              child: Text('update-password-button-title'.i18n()),
            ),
          ],
        ),
      ),
    );
  }
}
