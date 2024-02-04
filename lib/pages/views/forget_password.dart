import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:localization/localization.dart';


// Flutter Firebase forget password view
class ForgetPasswordView extends StatefulWidget {
  const ForgetPasswordView({super.key});

  @override
  State<ForgetPasswordView> createState() => _ForgetPasswordViewState();
}

class _ForgetPasswordViewState extends State<ForgetPasswordView> {
  late TextEditingController _emailController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late String message = 'sss';

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
  }

  Future<void> _resetPassword() async {
    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text);
      setState(() {
        message = 'check-email'.i18n();
      });
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        setState(() {
          message = 'user-not-found'.i18n();
        });
      } else if (e.code == 'invalid-email') {
        setState(() {
          message = 'invalid-email'.i18n();
        });
      } else {
        setState(() {
          message = 'error'.i18n();
        });
      }
    }

  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('reset-password'.i18n()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          children: [
            const SizedBox(
              height: 50,
            ),
            Center(
              child: Image.asset(
                'assets/images/icons8-password-256.png',
                width: 100,
                height: 100,
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            Text('reset-password-message'.i18n()),
            const SizedBox(
              height: 20,
            ),
            Container(
              decoration: const BoxDecoration(
                boxShadow: [
                    BoxShadow(
                      color: Colors.grey,
                      offset: Offset(1.0, 1.0),
                      blurRadius: 2.0,
                    ),
                  ],
              ),
              child: TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'email'.i18n(),
                  hintText: 'email'.i18n(),
                  prefixIcon: const Icon(Icons.email, color: Colors.grey,),

                ),
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                elevation: 4,
              ),
              onPressed: () async {
                await _resetPassword().then((_) {
                  setState(() {
                      showDialog(context: context, builder: (ctx) {
                        return AlertDialog(
                          title: Text('reset-password'.i18n()),
                          content: Text(message),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                              },
                              child: Text('ok'.i18n()),
                            ),
                            TextButton(
                                onPressed: () =>
                                 Navigator.of(context)
                                     .pushNamedAndRemoveUntil('/login',
                                         (Route route) => false,),
                                child: Text('go-to-login'.i18n(),
                                )
                            ,)
                          ],
                        );
                      },);
                  });
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('reset-password'.i18n()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
