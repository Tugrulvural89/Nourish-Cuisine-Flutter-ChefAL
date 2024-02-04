import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:localization/localization.dart';

import '../../bloc/authentication/authentication_bloc.dart';
import '../../bloc/authentication/authentication_state.dart';
import '../../generated/assets.dart';
import '../../models/chat_model.dart';
import '../../services/revenuecat_api.dart';
import '../../widgets/pre_alert_dialog.dart';
import '../notes/notes_page.dart';

class ChatDetailPageWidget extends StatefulWidget {
  const ChatDetailPageWidget({super.key});

  @override
  _ChatDetailPageWidgetState createState() => _ChatDetailPageWidgetState();
}

class _ChatDetailPageWidgetState extends State<ChatDetailPageWidget> {
  String replyContent = '';
  List<dynamic> messages = [
    ChatMessage(
      messageContent: 'noruish-chef-welcome-text'.i18n(),
      messageType: 'receiver',
      userEmail: 'tugrulv89@gmail.com',
    ),
  ];

  bool isLoading = false;
  late User? user;
  late TextEditingController _messageController;
  final RevenueApi memberShip = RevenueApi();
  bool isSubscribed = false;
  bool isLoggedIn = false;
  final String mxToken = dotenv.get('MAXTOKENUSER');

  void _scrollToBottom() {
    if (_scrollController.hasClients == true) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  void showCustomDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CustomAlertDialog(isSubscription: isSubscribed);
      },
    );
  }

  bool buttonEnabled = true;
  final ScrollController _scrollController = ScrollController();

  Timer? _scrollTimer;
  bool _userScrolling = false;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    isSubscribed = memberShip.isSubscribedCheckSync();

    try {
      user = FirebaseAuth.instance.currentUser;
      setState(() {
        isLoggedIn = (user != null);
        if (isLoggedIn) {
          BlocProvider.of<AuthenticationBloc>(context).logIn(user!.uid);
        }
      });
    } on FirebaseAuthException catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace);
    }

    if (!_userScrolling) {
      _scrollToBottom();
    }

    // Kullanıcının scroll yapmasını izlemek için bir dinleyici ekleyin
    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection ==
          ScrollDirection.reverse) {
        // Kullanıcı scroll yapmaya başladı
        _userScrolling = true;
        cancelScrollTimer(); // Timer'ı iptal et
      }
    });
  }

  void startScrollTimer() {
    if (_scrollTimer == null || !_scrollTimer!.isActive) {
      _scrollTimer = Timer(const Duration(milliseconds: 500), () {
        if (!_userScrolling) {
          _scrollToBottom();
        }
      });
    }
  }

  void cancelScrollTimer() {
    if (_scrollTimer != null && _scrollTimer!.isActive) {
      _scrollTimer!.cancel();
    }
  }

  Future<void> generateChatMessage(String msg) async {
    var replyMessage = ChatMessage(
      messageContent: replyContent,
      messageType: 'receiver',
      userEmail: 'tugrulv89@gmail.com',
    );
    setState(() {
      messages.add(replyMessage);
    });
    OpenAI.apiKey = dotenv.get('GPTAPIKEY');
    var contextText = 'you are professional chef and help people '
        'complate their '
        'food if they need help to how is cooking. Your response only '
        'about cooking. don\'t answer other questions';
    if (buttonEnabled == false) {
      var chatStream = OpenAI.instance.chat.createStream(
        model: 'gpt-3.5-turbo',
        temperature: 0.3,
        maxTokens: 1500,
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            content: contextText,
            role: OpenAIChatMessageRole.system,
          ),
          OpenAIChatCompletionChoiceMessageModel(
            content: msg,
            role: OpenAIChatMessageRole.user,
          )
        ],
      );
      chatStream.listen((streamChatCompletion) {
        final content = streamChatCompletion.choices.first.delta.content;
        setState(() {
          replyContent += content ?? '';
          // Update the last item in the messages list
          messages[messages.length - 1] = ChatMessage(
            messageContent: replyContent,
            messageType: 'receiver',
            userEmail: 'tugrulv89@gmail.com',
          );
        });
      }).onDone(() {
        var nowUtc = DateTime.now().toUtc();
        aiProgramActionsCollection.doc(user?.uid).update({
          'daily_usage': FieldValue.increment(1),
          'last_action_date': nowUtc
        ,});
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  final CollectionReference aiProgramActionsCollection =
      FirebaseFirestore.instance.collection('ai_program_actions');

  Future<void> resetDailyUsageForTomorrow() async {
    var user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    var today = DateTime.now();

    await aiProgramActionsCollection
        .doc(user.uid)
        .update({'daily_usage': 0, 'last_action_date': today.toUtc()});
  }

  Future<bool> canUserGenerateText() async {
    var user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    var aiProgramSnapshot =
        await aiProgramActionsCollection.doc(user.uid).get();
    if (!aiProgramSnapshot.exists) {
      await aiProgramActionsCollection.doc(user.uid).set({
        'last_action_date': DateTime.now().toUtc(), // Initial action date
        'daily_usage': 0,
      });
      // Set the aiProgramSnapshot to the new document
      aiProgramSnapshot = await aiProgramActionsCollection.doc(user.uid).get();
    }

    DateTime? aiProgramLastActionDate =
        (aiProgramSnapshot.data() as Map<String, dynamic>?)?['last_action_date']
            ?.toDate();

    int aiProgramDailyUsage =
        (aiProgramSnapshot.data() as Map<String, dynamic>)['daily_usage'] ?? 0;

    if (!_isSameDay(aiProgramLastActionDate, DateTime.now())) {
      await resetDailyUsageForTomorrow();
      aiProgramDailyUsage = 0;
    }
    isSubscribed =
        memberShip.isSubscribedCheckSync(); // check subscription status again
    var aiManLimit = int.parse(dotenv.get('MAXCHEFAI'));
    var aiManNonPreLimit = int.parse(dotenv.get('MAXNONPREAI'));
    if (isSubscribed == true) {
      return aiProgramDailyUsage < aiManLimit;
    } else {
      return aiProgramDailyUsage < aiManNonPreLimit;
    }
  }

  Future<void> startChat(BuildContext context) async {
    if (_messageController.text.length > 3 && isLoading == false
        && buttonEnabled == false) {
      setState((){
        isLoading = true;
      });
      await canUserGenerateText().then((canGenerate) {
        if (!canGenerate) {
          showCustomDialog(context);
        } else if (canGenerate) {
          var myInput = _messageController.text;
          if (myInput.length < int.parse(mxToken)) {
            var message = ChatMessage(
              messageContent: myInput,
              messageType: 'sender',
              userEmail: 'tugrulv89@gmail.com',
            );
            setState(() {
              replyContent = '';
              messages.add(message);
            });
            generateChatMessage(myInput);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'cant-use-more-'
                          'than-350-token'
                      .i18n(),
                ),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'something-went-wrong'.i18n(),
              ),
            ),
          );
        }
      });
    }
  }

  bool _isSameDay(DateTime? date1, DateTime date2) {
    if (date1 == null) return false;
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthenticationBloc, AuthenticationState>(
      builder: (context, state) {
        if (state is Authenticated) {
          return Scaffold(
            appBar: AppBar(
              elevation: 0,
              automaticallyImplyLeading: false,
              backgroundColor: Colors.white,
              flexibleSpace: SafeArea(
                child: Container(
                  padding: const EdgeInsets.only(right: 16),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(
                        width: 2,
                      ),
                      CircleAvatar(
                        backgroundColor: Colors.pink.shade700,
                        backgroundImage: const AssetImage(Assets.imagesChef),
                        radius: 20,
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Text(
                              'Nourish Chef',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(
                              height: 6,
                            ),
                            Text(
                              'Online',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            body: Stack(
              children: <Widget>[
                const SizedBox(
                  height: 20,
                ),
                (isLoading &&
                        _messageController.text.length > 2 &&
                        replyContent.length > 3)
                    ? const LinearProgressIndicator()
                    : const SizedBox.shrink(),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.80,
                  child: ListView.builder(
                    controller: _scrollController,
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: messages.length,
                    itemBuilder: (
                      BuildContext context,
                      int index,
                    ) {
                      startScrollTimer();
                      return Container(
                        padding: messages[index].messageType == 'receiver'
                            ? const EdgeInsets.only(
                                top: 12.0,
                                left: 12.0,
                                right: 50.0,
                                bottom: 12.0,
                              )
                            : const EdgeInsets.all(12.0),
                        child: Align(
                          alignment: messages[index].messageType == 'receiver'
                              ? Alignment.topLeft
                              : Alignment.topRight,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: messages[index].messageType == 'receiver'
                                  ? Colors.grey.shade200
                                  : Colors.blue.shade300,
                            ),
                            child: Padding(
                              padding: messages[index].messageType == 'receiver'
                                  ? const EdgeInsets.only(
                                      top: 15.0,
                                      left: 15.0,
                                      right: 15.0,
                                      bottom: 15.0,
                                    )
                                  : const EdgeInsets.only(
                                      top: 15.0,
                                      left: 15.0,
                                      right: 15.0,
                                      bottom: 15.0,
                                    ),
                              child: Text(messages[index].messageContent),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.only(left: 10, bottom: 10, top: 10),
                    height: 120,
                    width: double.infinity,
                    color: Colors.white,
                    child: Row(
                      children: <Widget>[
                        const SizedBox(
                          width: 25,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            maxLines: null,
                            decoration: InputDecoration(
                              hintText: 'write-your-message-here'.i18n(),
                              hintStyle: const TextStyle(color: Colors.black54),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 15,
                        ),
                        buttonEnabled
                            ? IconButton(
                                onPressed: isLoading
                                    ? null
                                    : () {
                                        setState(() {
                                          buttonEnabled = false;
                                        });
                                        startChat(context).then((value) {
                                          setState(() {
                                            buttonEnabled = true;
                                            isLoading = false;
                                            _messageController.clear();
                                            startScrollTimer();
                                          });
                                        });

                                      },
                                icon: Icon(
                                  Icons.send,
                                  color: isLoading
                                      ? Colors.grey.shade800
                                      : Colors.green.shade600,
                                  size: 28,
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.send),
                                color: Colors.grey.shade800,
                                onPressed: null,
                              ),
                        const SizedBox(
                          width: 25,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          return const RedirectLoginPage();
        }
      },
    );
  }
}
