import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:localization/localization.dart';

import '../../bloc/authentication/authentication_bloc.dart';
import '../../models/notes_model.dart';
import '../../services/firestore_service.dart';
import '../../services/revenuecat_api.dart';

class EditNoteScreen extends StatefulWidget {
  final String userId;
  final Note note;

  const EditNoteScreen({super.key, required this.userId, required this.note});

  @override
  _EditNoteScreenState createState() => _EditNoteScreenState();
}

class _EditNoteScreenState extends State<EditNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late List<TextEditingController> _controllers;
  final RevenueApi memberShip = RevenueApi();
  bool isSubscription = false;
  bool isLoggedIn = false;
  User? user;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _controllers = widget.note.items
        .map((item) => TextEditingController(text: item))
        .toList();
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

  @override
  void dispose() {
    _titleController.dispose();
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (_formKey.currentState!.validate()) {
      final note = Note(
        id: widget.note.id,
        title: _titleController.text,
        time: widget.note.time,
        items: _controllers.map((controller) => controller.text).toList(),
      );

      await FirestoreService().saveNote(widget.userId, note);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text('notes-saved-success'.i18n()),
            action: SnackBarAction(
              label: 'continue'.i18n(),
              onPressed: () => Navigator.pop(context),),
          ),
        );
      }


    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('edit-note'.i18n()),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: <Widget>[
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'title'.i18n(),
                  labelStyle: Theme.of(context).textTheme.bodyLarge,

                ),
                style: Theme.of(context).textTheme.bodyLarge,
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
                          labelStyle: Theme.of(context).textTheme.bodyLarge,
                        ),
                        style: Theme.of(context).textTheme.bodyLarge,
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
                        icon:  Icon(Icons.delete,
                          color: Theme.of(context).cardColor,),),
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
}