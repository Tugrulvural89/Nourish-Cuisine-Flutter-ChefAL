import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:localization/localization.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../bloc/authentication/authentication_bloc.dart';
import '../../bloc/authentication/authentication_state.dart';
import '../../generated/assets.dart';
import '../../utils/apple_sign.dart';
import '../../utils/constant.dart';
import '../../utils/google_sign.dart';
import '../recipe_generator.dart';
import 'forget_password.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late bool _platformController;

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
      }
    });
    if (Platform.isIOS) {
      _platformController = true;
    } else {
      _platformController = false;
    }
  }


  Future<void> _launchUrl(_url) async {
    final url = Uri.parse(_url);
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  Widget _buildLoginForm(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              height: 50,
            ),
            Center(
              child: Container(
                height: 175,
                width: 175,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 5,
                      blurRadius: 7,
                      offset: const Offset(
                          0, 3,),
                    ),
                  ],
                ),
                child: Image.asset(Assets.imagesLoginscreen),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 15, top: 40),
              child: Text('welcome'.i18n(),
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,),),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text('login-account-text'.i18n(),
                  style:
                      TextStyle(fontSize: 18, color: Colors.green.shade800),),
            ),
            Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.5),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: TextFormField(
                          style: Theme.of(context).textTheme.bodyLarge,
                          controller: _emailController,
                          decoration:  InputDecoration(
                              labelText: 'Email',
                              labelStyle: Theme.of(context)
                                  .textTheme.bodyLarge
                          ,),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'enter-email-warning'.i18n();
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextFormField(
                          style: Theme.of(context).textTheme.bodyLarge,
                          controller: _passwordController,
                          decoration:
                              InputDecoration(
                                  labelText: 'password'.i18n(),
                                  labelStyle: Theme.of(context)
                                      .textTheme.bodyLarge
                              ,),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'password-text'.i18n();
                            }
                            return null;
                          },
                        ),
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
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          try {
                            await FirebaseAuth.instance
                                .signInWithEmailAndPassword(
                              email: _emailController.text,
                              password: _passwordController.text,
                            )
                                .then((UserCredential userCredential) {
                              FirebaseAuth.instance
                                  .authStateChanges()
                                  .listen((User? user) {
                                if (user != null) {
                                  BlocProvider.of<AuthenticationBloc>(context)
                                      .logIn(user.uid);
                               //Todo: add user redirect to recipe generator
                                }
                              });
                            }).catchError((error) {
                              // Cast the error to a FirebaseAuthException
                              var fbError = error as FirebaseAuthException;
                              String message;
                              switch (fbError.code) {
                                case 'invalid-email':
                                  message = 'non-valid-email'.i18n();
                                  break;
                                case 'wrong-password':
                                  message = 'non-valid-password'.i18n();
                                  break;
                                case 'user-not-found':
                                  message = 'user-not-found'.i18n();
                                  break;
                                default:
                                  message = 'unknown-error'.i18n();
                                  break;
                              }
                              // Show the message in a SnackBar
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                    content: Text(message),
                              ),
                              );
                            });
                          } on FirebaseAuthException catch (e) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(
                                  content:
                                  Text(e.message ?? 'unknown-error'.i18n()),
                            ),);
                          }
                        }
                      },
                      child: Text('login'.i18n()),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () {
                            //canLaunchUrl(Uri.parse(policyUrl));
                            _launchUrl(policyUrl);
                          },
                          child: Text('privacy-policy'.i18n()),
                        ),
                        TextButton(
                          onPressed: () {
                            _launchUrl(eulaUrl);
                          },
                          child: Text('terms-and-conditions'.i18n()),
                        )
                      ],
                    ),
                    TextButton(onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgetPasswordView(),
                        ),
                      );
                    },
                      child: Text('forget-password'.i18n(),
                        style: Theme.of(context)
                            .textTheme.bodySmall,),),
                    const SizedBox(height: 5),
                    const GoogleSignButton(),
                    const SizedBox( height: 5,),
                    _platformController ? const AppleSignButton() :
                      const SizedBox.shrink(),
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
                            child: Text('discover'.i18n(),
                                style: Theme.of(context)
                                    .textTheme.bodySmall,),
                          ),
                          TextButton(
                            onPressed: () {
                             Navigator.pushNamedAndRemoveUntil(context,
                                 '/signUp', (Route route) => false,);
                            },
                            child: Text('get-started'.i18n(),
                                style: Theme.of(context)
                                    .textTheme.bodySmall,),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthenticationBloc, AuthenticationState>(
      builder: (context, state) {
        if (state is Authenticated) {
          return const RecipeGenerator();
        } else {
          return _buildLoginForm(context);
        }
      },
    );
  }
}
