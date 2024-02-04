import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:localization/localization.dart';

import '../bloc/authentication/authentication_bloc.dart';

class GoogleSignButton extends StatefulWidget {
  const GoogleSignButton({super.key});

  @override
  _GoogleSignButtonState createState() => _GoogleSignButtonState();
}

class _GoogleSignButtonState extends State<GoogleSignButton> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  bool _isUserSignedIn = false;

  @override
  void initState() {
    super.initState();
    _initializeSignInState();
  }

  Future<void> _initializeSignInState() async {
    await _checkSignInState();
    // use other methods here
  }

  Future<void> _checkSignInState() async {
    var isUserSignedIn = await _googleSignIn.isSignedIn();
    setState(() {
      _isUserSignedIn = isUserSignedIn;
    });
  }


  Future<UserCredential?> signInWithGoogle() async {
    // Trigger the authentication flow
    final googleUser = await _googleSignIn.signIn();
    try {
      // Obtain the auth details from the request
      final googleAuth = await googleUser?.authentication;

      // Create a new credential
      if (googleAuth != null) {
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        return await FirebaseAuth.instance.signInWithCredential(credential);
      } else {
        setState(() {
          _isUserSignedIn = false;
        });
        return null;
      }


    } catch (e) {
      setState(() {
        _isUserSignedIn = false;
      });
      return null;
    }


  }



    Future<void> _navigateToRecipes() async {
      // Let the AuthenticationBloc know that the user has signed out
      BlocProvider.of<AuthenticationBloc>(context).logOut();
      await Navigator.pushNamed(context, '/recipes');
    }


  Future<void> signOut() async {
    // Sign out from Google and Firebase
    await _googleSignIn.signOut();
    await _auth.signOut();

    // Update _isUserSignedIn after sign out
    setState(() {
      _isUserSignedIn = false;
    });

    await Future.delayed(Duration.zero);
    // Navigate to '/recipes' after sign out
    await _navigateToRecipes();
  }



  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        icon: Image.asset(
          'assets/images/google-icon.png',
          height: 24.0,
          width: 24.0,
        ), // specify your desired height and width
        label: Text(
          _isUserSignedIn ? 'google-sign-out'.i18n() : 'google-sign-in'.i18n(),
          style: TextStyle(color: Theme.of(context).colorScheme.secondary),
        ),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(40),
          ),
          side: const BorderSide(color: Colors.grey),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        ),
        onPressed: () {
          // Check if the user is already signed in
          if (_isUserSignedIn) {
            // User is already signed in, perform sign out
            signOut();
          } else {
            // User is not signed in, perform sign in
            try {
              signInWithGoogle().then(
                onError: (e) => setState(() { _isUserSignedIn = false; }),
                      (value) {
                  if (value != null) {
                    var userToken = FirebaseAuth.instance.currentUser;
                    if (userToken != null) {
                      BlocProvider.of<AuthenticationBloc>(context)
                          .logIn(userToken.uid);
                      setState(() {
                        _isUserSignedIn = true;
                      });
                  }

                  }


              });
            } catch (e) {
              setState(() {
                _isUserSignedIn = false;
              });
            }
          }
        },
      ),
    );
  }
}
