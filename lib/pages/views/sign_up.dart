import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:localization/localization.dart';

import '../../bloc/authentication/authentication_bloc.dart';
import '../../generated/assets.dart';
import '../../utils/google_sign.dart';
import '../recipe_generator.dart';
import 'login_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPage createState() => _SignUpPage();
}

class _SignUpPage extends State<SignUpPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  User? user = FirebaseAuth.instance.currentUser;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();


  Future<void> _signUp() async {
    final completer = Completer();

      try {
        var userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (_auth.currentUser != null) {
          await _auth.currentUser!.sendEmailVerification();
        }
        // Check if the state is still mounted.
        if(mounted) {
          // Call the logIn method with user id after user is signed up.
          context.read<AuthenticationBloc>().logIn(userCredential.user!.uid);
          completer.complete();
        } else {
          completer.completeError('Error');
        }

        await completer.future.then((_) {
        Navigator.of(context).pushNamedAndRemoveUntil('/emailVerification',
          (Route route) => false,
        );
        }).catchError((error) {
        });
      } on FirebaseAuthException catch (e) {
        if (e.code == 'weak-password') {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('error'.i18n()),
              content: Text('weak-password'.i18n()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('ok'.i18n()),
                ),
              ],
            ),
          );
        } else if (e.code == 'email-already-in-use') {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('error'.i18n()),
              content: Text('email-already-in-use'.i18n()),
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


  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              height: 70,
            ),
            Center(
              child: Container(
                height: 300,
                width: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10), // Yuvarlak köşeler
                  boxShadow: [
                    // Gölge efekti
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 5,
                      blurRadius: 7,
                      offset: const Offset(
                          0, 3,),
                    ),
                  ],
                ),
                child: Image.asset(Assets.imagesSignupimage),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 15, top: 10),
              child: Text('sign-up'.i18n(),
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,),),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text('create-account'.i18n(),
                  style: TextStyle(fontSize: 12,
                      color: Colors.green.shade800,),),
            ),
            const SizedBox(
              height: 10,
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailController,
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'non-valid-email'.i18n();
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        label: const Text('Email'),
                        labelStyle: const TextStyle(
                          color: Colors.grey,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: const BorderSide(color: Colors.green),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.email),
                        prefixIconColor: Colors.grey,
                      ),
                    ),
                    const SizedBox(
                      height: 15,
                    ),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'non-valid-password'.i18n();
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        label:  Text('password'.i18n()),
                        labelStyle: const TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: const  BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: const BorderSide(color: Colors.green),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.lock),
                        prefixIconColor: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor:
                              MaterialStateProperty.resolveWith<Color>(
                            (Set<MaterialState> states) {
                              if (states.contains(MaterialState.pressed)) {
                                return Colors.green
                                    .shade300;
                              }
                              return Colors.green
                                  .shade800;
                            },
                          ),
                        ),
                        onPressed: _signUp,
                        child: Text('sign-up'.i18n()),),
                    const SizedBox(height: 15),
                    const GoogleSignButton(),
                    const SizedBox(height: 15),
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                      const RecipeGenerator(),),);
                            },
                            child:Text('discover'.i18n(),
                                style: Theme.of(context).textTheme.bodySmall,),
                          ),
                          TextButton(
                              onPressed: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                        const LoginPage(),),);
                              },
                              child:  Text('login'.i18n(),
                                  style: Theme.of(context)
                                      .textTheme.bodySmall,),)
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


