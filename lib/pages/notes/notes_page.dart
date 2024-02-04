import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:localization/localization.dart';

import '../../bloc/authentication/authentication_bloc.dart';
import '../../bloc/authentication/authentication_state.dart';
import '../../helpers/ad_helper.dart';
import '../../models/notes_model.dart';
import '../../services/firestore_service.dart';
import '../../services/revenuecat_api.dart';
import '../../widgets/custom_bottombar.dart';
import '../views/login_page.dart';
import 'create_notes_page.dart';
import 'edit_notes.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});


  @override
  _NotesPageState createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final _db = FirestoreService();
  BannerAd? _bannerAd;

  void _loadFirstBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _bannerAd = ad as BannerAd;
          });
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
        },
        // Called when an ad opens an overlay that covers the screen.
        onAdOpened: (Ad ad) {},
        // Called when an ad removes an overlay that covers the screen.
        onAdClosed: (Ad ad) {},
        // Called when an impression occurs on the ad.
        onAdImpression: (Ad ad) {},
      ),
    )..load();
  }


  bool isSubscription = false;
  final RevenueApi memberShip = RevenueApi();
  bool isLoggedIn = false;
  User? user;


  @override
  void initState() {
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

    isSubscription = memberShip.isSubscribed;
    if (isSubscription == false) {
      _loadFirstBannerAd();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthenticationBloc, AuthenticationState>(
      builder: (context, state) {
        if (state is Authenticated) {
          final userId = state.userId; // Local variable for user.uid
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/recipes', (route) => false,);
                },
                icon: const FaIcon(
                  FontAwesomeIcons.house,
                  color: Colors.white,
                ),
              ),
              title: Text('shopping-list'.i18n()),
              actions: [
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateNoteScreen(
                            userId: userId,), // Pass the userId here
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            body: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: <Widget>[
                  const SizedBox(height: 20),
                  if (_bannerAd != null && isSubscription == false)
                    Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: _bannerAd!.size.width.toDouble(),
                        height: _bannerAd!.size.height.toDouble(),
                        child: AdWidget(ad: _bannerAd!),
                      ),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.8,
                    child: StreamBuilder<List<Note>>(
                      stream: _db.getNotes(userId), // Using the local variable
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          var notes = snapshot.data!; // Get the notes
                          notes.sort((a, b) => b.time
                              .compareTo(a.time),); // Sort the notes by time

                          return ListView.builder(
                            itemCount:
                                max(0, (snapshot.data?.length ?? 0) * 2 - 1),
                            itemBuilder: (context, index) {
                              if (index.isOdd) {
                                return const Divider();
                              }
                              final itemIndex = index ~/ 2;
                              final note = snapshot.data![itemIndex];
                              return ListTile(
                                title: Text(
                                    "${note.title} ${note.time
                                        .toString().split(' ')[0]}"),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: note.items.length,
                                      itemBuilder: (context, i) {
                                        return Text('- ${note.items[i]}');
                                      },
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                EditNoteScreen(
                                              userId: userId,
                                              note: note,
                                            ), // Pass the userId and note here
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () async {
                                        final confirmDelete = await showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title:  Text('confirm-delete'
                                                .i18n(),),
                                            content:  Text(
                                                'sure-delete'.i18n(),),
                                            actions: [
                                              TextButton(
                                                child:  Text('cancel'.i18n()),
                                                onPressed: () =>
                                                    Navigator.of(context)
                                                        .pop(false),
                                              ),
                                              TextButton(
                                                child:  Text('delete'.i18n()),
                                                onPressed: () =>
                                                    Navigator.of(context)
                                                        .pop(true),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirmDelete == true) {
                                          // Delete the note
                                          await _db.deleteNote(userId, note.id);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        } else if (snapshot.hasError) {
                          return Column(
                            children: [
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          CreateNoteScreen(userId: userId),
                                    ),
                                  );
                                },
                                child:  Text('create-note'.i18n()),
                              ),
                              Text(' ${'error'.i18n()} : ${snapshot.error}'),
                            ],
                          );
                        }
                        return const Center(child: CircularProgressIndicator());
                      },
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar:
            CustomBottomBar(isSubscription: isSubscription,),
          );
        } else if (state is Unauthenticated) {
          return const RedirectLoginPage();
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  @override
  void dispose() {

    _bannerAd?.dispose();


    super.dispose();
  }
}

class RedirectLoginPage extends StatelessWidget {
  const RedirectLoginPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.green.shade800, // Set black background
      child: Center(
          child: TextButton(
        onPressed: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const LoginPage()),);
        },
        child:  Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'login-account-text'.i18n(),
              style: const TextStyle(color: Colors.white),
            ),
            const Icon(Icons.arrow_right, color: Colors.white),
          ],
        ),
      ),),
    );
  }
}


