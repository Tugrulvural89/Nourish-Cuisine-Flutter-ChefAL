import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:localization/localization.dart';

import '../../bloc/authentication/authentication_bloc.dart';
import '../../bloc/authentication/authentication_state.dart';
import '../../models/notes_model.dart';
import '../../services/firestore_service.dart';
import '../../services/revenuecat_api.dart';
import '../recipe_generator.dart';

class CreateNoteScreen extends StatefulWidget {
  final String userId;

  const CreateNoteScreen({super.key, required this.userId});

  @override
  _CreateNoteScreenState createState() => _CreateNoteScreenState();
}

class _CreateNoteScreenState extends State<CreateNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final List<TextEditingController> _controllers = [TextEditingController()];
  final RevenueApi memberShip = RevenueApi();
  bool isSubscription = false;
  bool isLoggedIn = false;
  User? user;


  @override
  void initState () {
    super.initState();
    isSubscription = memberShip.isSubscribedCheckSync();

    try {
      user =  FirebaseAuth.instance.currentUser;
      setState(() {
        isLoggedIn = (user != null);
        if (isLoggedIn) {
          BlocProvider.of<AuthenticationBloc>(context).logIn(user!.uid);
        }
      });

    } on FirebaseAuthException catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace);
    }
  }



  Future<void> _saveNote() async {
    if (_formKey.currentState!.validate()) {
      var now = DateTime.now();
      var formatter = DateFormat('yyyy-MM-dd HH:mm');
      var formattedTime = formatter.format(now);
      final note = Note(
        id: FirebaseFirestore.instance.collection('notes').doc().id,
        title: _titleController.text,
        time: formattedTime,
        items: _controllers.map((controller) => controller.text).toList(),
      );

      await FirestoreService().saveNote(widget.userId, note).then((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('notes-saved-success'.i18n())),
        );
        Navigator.pushNamed(context, '/notes');
      }).catchError((e) {
        if (e) {
          FirebaseCrashlytics.instance.recordError(
            e,
            StackTrace.current,
            reason: 'Error saving note',
          );
        }
        Future.delayed(const Duration(seconds: 2));
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('error'.i18n()),
              content: Text('${"failed-save-note".i18n()} : $e'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('ok'.i18n()),
                ),
              ],
            ),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _buildBlocSate(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('create-note'.i18n()),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: <Widget>[
              TextFormField(
                controller: _titleController,
                decoration:
                    InputDecoration(labelText: 'shopping-list-title'.i18n()),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'enter-title'.i18n();
                  }
                  return null;
                },
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _controllers.length,
                itemBuilder: (context, index) {
                  return Stack(
                    alignment: Alignment.topRight,
                    children: [
                      TextFormField(
                        controller: _controllers[index],
                        decoration: InputDecoration(
                          labelText: '${"list".i18n()} ${index + 1}',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'enter-item'.i18n();
                          }
                          return null;
                        },
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _controllers[index].dispose();
                            _controllers.removeAt(index);
                          });
                        },
                        icon: const Icon(Icons.delete),
                      )
                    ],
                  );
                },
              ),
              const SizedBox(height: 16.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => setState(() {
                      _controllers.add(TextEditingController());
                    }),
                    child: Text('add'.i18n()),
                  ),
                  const SizedBox(height: 16.0),
                  ElevatedButton(
                    onPressed: _saveNote,
                    child: Text('save'.i18n()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthenticationBloc, AuthenticationState>(
      builder: (context, state) {
        if (state is Unauthenticated) {
          return const RecipeGenerator();
        } else {
          return _buildBlocSate(context);
        }
      },
    );
  }
}
