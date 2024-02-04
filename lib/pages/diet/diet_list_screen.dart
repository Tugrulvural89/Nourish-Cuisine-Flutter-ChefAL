import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:localization/localization.dart';

import '../../bloc/authentication/authentication_bloc.dart';
import '../../bloc/authentication/authentication_state.dart';
import '../../services/firestore_service.dart';
import '../notes/notes_page.dart';

class DietListWidget extends StatelessWidget {
  const DietListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthenticationBloc, AuthenticationState>(
      builder: (context, state) {
        if (state is Authenticated) {
          String? userId =
              state.userId; // Retrieve the user ID from the AuthenticationState

          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pushNamed(context, '/recipes');
                },
              ),
              title: Text('check-diet-title'.i18n()),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    Navigator.pushNamed(context, '/createDiet');
                  },
                ),
              ],
            ),
            body: FutureBuilder<String?>(
              future: FirestoreService().getDietProgram(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else {
                  var dietProgram = snapshot.data;
                  if (dietProgram != null) {
                    return Padding(
                      padding: const EdgeInsets.all(5.0),
                      child: ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top:15.0,left:10.0),
                            child: ListTile(
                              title: Text(dietProgram),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () async {
                                  var firestoreService =
                                      FirestoreService();
                                  await firestoreService
                                      .deleteDietProgram(userId)
                                      .then((value) => {
                                            Navigator.pushNamed(
                                                context, '/createDiet',)
                                          },);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    return Center(child: Text('no-diet-found'.i18n()));
                  }
                }
              },
            ),
          );
        } else {
          return const RedirectLoginPage();
        }
      },
    );
  }
}
