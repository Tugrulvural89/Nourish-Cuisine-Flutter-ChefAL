import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:localization/localization.dart';

import '../../bloc/authentication/authentication_bloc.dart';
import '../../bloc/authentication/authentication_state.dart';
import '../../services/firestore_service.dart';
import '../../services/revenuecat_api.dart';
import '../../widgets/info_popup.dart';
import '../../widgets/pre_alert_dialog.dart';
import '../notes/notes_page.dart';
import 'diet_list_screen.dart';

class DietForm extends StatefulWidget {
  const DietForm({super.key});

  @override
  _DietFormState createState() => _DietFormState();
}

class _DietFormState extends State<DietForm>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _ageController = TextEditingController();
  final _genderController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _typeController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isCardExpanded = true;
  bool isSubscription = false;
  User? user;
  bool isLoggedIn = false;
  final RevenueApi memberShip = RevenueApi();

  final List<String> _genderOptions = [
    'man'.i18n(),
    'women'.i18n(),
    'other'.i18n()
  ];
  String? _selectedGender;

  String? _selectedType;
  final List<String> _typeOptions = [
    'meat'.i18n(),
    'vegan'.i18n(),
    'vegetarian'.i18n()
  ];

  bool isStreaming = false;
  bool isLoading = false;
  String recipe = '';
  String mainText = 'diet-step-one-main-text'.i18n();


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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      InfoPopup.show(
        context,
        'diet-screen-popup-main-text'.i18n(),
        'diet-screen-popup-long-text'.i18n(),
        'CreateDiet',
      );
    });
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }



  void showCustomDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CustomAlertDialog(isSubscription: isSubscription);
      },
    );
  }


  Future<void> generateDietProgram(
    String age,
    String weight,
    String height,
    String gender,
    String type,
    String mainText,
  ) async {
    setState(() {
      recipe = '';
      isLoading = false;
      isStreaming = true;
    });

    await dotenv.load();
    OpenAI.apiKey = dotenv.get('GPTAPIKEY');
    var contentText = 'second-main-text'.i18n();
    var chatStream =  OpenAI.instance.chat.createStream(
      model: 'gpt-3.5-turbo',
      messages: [
        OpenAIChatCompletionChoiceMessageModel(
          content: mainText,
          role: OpenAIChatMessageRole.system,
        ),
        OpenAIChatCompletionChoiceMessageModel(
          //content: '$secondMainText $age $height $weight $gender $type',
          content: '$type $contentText',
          role: OpenAIChatMessageRole.user,
        )
      ],
    );
    chatStream.listen((streamChatCompletion) {
      final content = streamChatCompletion.choices.first.delta.content;

      setState(() {
        recipe += content ?? '';
      });
    }).onDone(() {
      setState(() {
        isLoading = true;
        isStreaming = false;
      });
    });
  }

  void _toggleCardExpansion() {
    setState(() {
      _isCardExpanded = !_isCardExpanded;
      if (_isCardExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  String? _selectedUnitWeight;

  List<DropdownMenuItem<int>> _buildDropdownMenuItems() {
    var items = <DropdownMenuItem<int>>[];
    // Add the items with decimal values (3.1 to 11.0)
    for (var i = 5.2; i <= 7.2; i += 0.1) {
      var intValue = i.toInt();
      var decimalPart = ((i * 10) % 10).toInt();
      var cmValue = ((intValue * 12) + decimalPart) * 2.54;
      items.add(
        DropdownMenuItem(
          value: (i * 10).toInt(),
          child: Text('${i.toStringAsFixed(1)} in '
              ' ${cmValue.toStringAsFixed(2)} cm'),
        ),
      );
    }
    return items;
  }

  Future<void> saveDietProgram(String dietProgram) async {
    setState(() {
      user = FirebaseAuth.instance.currentUser;
    });
    var userId = user?.uid;
    if (userId != null) {
      var firestoreService = FirestoreService();
      await firestoreService.saveDietProgram(dietProgram).then((_) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('diet-saved'.i18n()),
              content: Text('diet-successfully-saved'.i18n()),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil('/dietsList', (Route route) => false);
                  },
                  child: Text('check-my-diet-list'.i18n()),
                ),
              ],
            );
          },
        );
      });
    }
  }

  @override
  void dispose() {
    _ageController.dispose();
    _genderController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _typeController.dispose();
    _animationController.dispose();

    super.dispose();
  }

  int limitForUserDiet = 1;


  bool isStartAi = false;

  final CollectionReference dietProgramActionsCollection =
      FirebaseFirestore.instance.collection('diet_program_actions');

  Future<void> resetDailyUsageForTomorrow() async {
    var user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    var today = DateTime.now();

    await dietProgramActionsCollection
        .doc(user.uid)
        .update({'daily_usage': 0, 'last_action_date': today.toUtc()});
    limitForUserDiet = 0;
  }

  Future<bool> canUserGenerateText() async {
    var user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    var dietProgramSnapshot =
        await dietProgramActionsCollection.doc(user.uid).get();
    if (!dietProgramSnapshot.exists) {
      await dietProgramActionsCollection.doc(user.uid).set({
        'last_action_date': DateTime.now().toUtc(), // Initial action date
        'daily_usage': 0,
      });
      // Set the dietProgramSnapshot to the new document
      dietProgramSnapshot =
          await dietProgramActionsCollection.doc(user.uid).get();
    }

    DateTime? dietProgramLastActionDate = (dietProgramSnapshot.data()
            as Map<String, dynamic>?)?['last_action_date']
        ?.toDate();

    int dietProgramDailyUsage =
        (dietProgramSnapshot.data() as Map<String, dynamic>)['daily_usage'] ??
            0;

    if (!_isSameDay(dietProgramLastActionDate, DateTime.now())) {
      await resetDailyUsageForTomorrow();
      dietProgramDailyUsage=0;
    }
    // handle any changes to customerInfo
    final dietMaxLimit = int.parse(dotenv.get('MAXAICOUNTDIET'));
    final dietMinLimit = int.parse(dotenv.get('MINCOUTNTDIET'));
    isSubscription = memberShip.isSubscribedCheckSync();
    if (isSubscription == false) {
      limitForUserDiet = dietMinLimit; //dietMinLimit;
    } else {
      // Handle the case when the user is subscribed
      limitForUserDiet = dietMaxLimit;
    }

    return dietProgramDailyUsage < limitForUserDiet;
  }

  bool _isSameDay(DateTime? date1, DateTime date2) {
    if (date1 == null) return false;
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Future<bool> generateText(
    String age,
    String weight,
    String height,
    String gender,
    String type,
  ) async {
    var canGenerate = await canUserGenerateText();
    if (canGenerate) {
      var user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        var nowUtc = DateTime.now().toUtc();
        await dietProgramActionsCollection.doc(user.uid).update({
          'daily_usage': FieldValue.increment(1),
          'last_action_date': nowUtc
        });

        await generateDietProgram(
          age,
          weight,
          height,
          gender,
          type,
          mainText,
        );
      }
    }
    return canGenerate;
  }

  @override
  Widget build(BuildContext context) {
    final topPaddingSize = MediaQuery.of(context).size.height * 0.15;
    return BlocBuilder<AuthenticationBloc, AuthenticationState>(
      builder: (context, state) {
        if (state is Authenticated) {
          return Container(
            color: Colors.green.shade800,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: topPaddingSize),
                    child: Center(
                      child: Row(
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: IconButton(
                              icon:  FaIcon(
                                FontAwesomeIcons.leftLong,
                                color: (!isStreaming) ? Colors.white
                                    : Colors.grey,
                              ),
                              onPressed: () =>  (!isStreaming) ? Navigator
                                  .of(context).pushNamed('/recipes') : null,
                            ),
                          ),
                          const Spacer(),
                          Material(
                            color: Colors.transparent,
                            child: IconButton(
                              icon: const FaIcon(
                                FontAwesomeIcons.bowlFood,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                if (!isStreaming) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const DietListWidget(),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                          GestureDetector(
                            onTap: _toggleCardExpansion,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedBuilder(
                                  animation: _animation,
                                  builder: (context, child) {
                                    return Transform.rotate(
                                      angle: _animation.value *
                                          0.5 *
                                          3.1415926535897932,
                                      child: _isCardExpanded
                                          ? const FaIcon(
                                              FontAwesomeIcons.eye,
                                              color: Colors.white,
                                            )
                                          : const FaIcon(
                                              FontAwesomeIcons.eyeSlash,
                                              color: Colors.white,
                                            ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      height: _isCardExpanded ? 550.0 : 0.0,
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.0),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Form(
                            key: _formKey,
                            child: ListView(
                              children: [
                                TextFormField(
                                  controller: _ageController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    enabledBorder: const OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.green,
                                        width: 2.0,
                                      ),
                                    ), // Border when the field is enabled
                                    focusedBorder: const OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.lightGreen,
                                        width: 2.0,
                                      ),
                                    ),
                                    labelText: 'age'.i18n(),
                                  ),
                                  validator: (value) {
                                    if (value!.isEmpty) {
                                      return 'please-age-input'.i18n();
                                    }
                                    final age = int.tryParse(value);
                                    if (age == null || age < 18 || age > 70) {
                                      return 'age-warning'.i18n();
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(
                                  height: 10,
                                ),
                                DropdownButtonFormField(
                                  value: _selectedGender,
                                  items: _genderOptions.map((String gender) {
                                    return DropdownMenuItem(
                                      value: gender,
                                      child: Text(
                                        gender,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedGender = value.toString();
                                    });
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'gender'.i18n(),
                                    enabledBorder: const OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.green,
                                        width: 2.0,
                                      ),
                                    ), // Border when the field is enabled
                                    focusedBorder: const OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.lightGreen,
                                        width: 2.0,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null) {
                                      return 'choose-gender'.i18n();
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(
                                  height: 10,
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _weightController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          enabledBorder:
                                              const OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Colors.green,
                                              width: 2.0,
                                            ),
                                          ),
                                          focusedBorder:
                                              const OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Colors.lightGreen,
                                              width: 2.0,
                                            ),
                                          ),
                                          labelText: 'weight'.i18n(),
                                        ),
                                        validator: (value) {
                                          if (value!.isEmpty) {
                                            return 'please-weight-input'.i18n();
                                          }
                                          final weight = int.tryParse(value);
                                          if (weight == null ||
                                              weight < 40 ||
                                              weight > 250) {
                                            return 'weight-warning'.i18n();
                                          }

                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 16,
                                    ),
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: _selectedUnitWeight,
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'kg',
                                            child: Text('kg'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'lb',
                                            child: Text('lb'),
                                          ),
                                        ],
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedUnitWeight = value;
                                          });
                                        },
                                        decoration: InputDecoration(
                                          enabledBorder:
                                              const OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Colors.green,
                                              width: 2.0,
                                            ),
                                          ),
                                          focusedBorder:
                                              const OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Colors.lightGreen,
                                              width: 2.0,
                                            ),
                                          ),
                                          labelText: 'unit'.i18n(),
                                        ),
                                        validator: (value) {
                                          if (value == null) {
                                            return 'please-unit-input'.i18n();
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(
                                  height: 10,
                                ),
                                DropdownButtonFormField<int>(
                                  items: _buildDropdownMenuItems(),
                                  onChanged: (value) {
                                    setState(() {
                                      _heightController.text = value.toString();
                                    });
                                  },
                                  decoration: InputDecoration(
                                    enabledBorder: const OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.green,
                                        width: 2.0,
                                      ),
                                    ),
                                    focusedBorder: const OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.lightGreen,
                                        width: 2.0,
                                      ),
                                    ),
                                    labelText: 'height'.i18n(),
                                  ),
                                  validator: (value) {
                                    if (value == null) {
                                      return 'please-height-input'.i18n();
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(
                                  height: 10,
                                ),
                                DropdownButtonFormField(
                                  value: _selectedType,
                                  items: _typeOptions.map((String gender) {
                                    return DropdownMenuItem(
                                      value: gender,
                                      child: Text(gender),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedType = value.toString();
                                    });
                                  },
                                  decoration: InputDecoration(
                                    enabledBorder: const OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.green,
                                        width: 2.0,
                                      ),
                                    ),
                                    focusedBorder: const OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.lightGreen,
                                        width: 2.0,
                                      ),
                                    ),
                                    labelText: 'diet-type'.i18n(),
                                  ),
                                  validator: (value) {
                                    if (value == null) {
                                      return 'please-diet-type-input'.i18n();
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(
                                  height: 20,
                                ),
                                ElevatedButton(
                                  onPressed: isStreaming
                                      ? null
                                      : () async {
                                          if (_formKey.currentState!
                                              .validate()) {
                                            _toggleCardExpansion();
                                            isStartAi = true;
                                            var canGenerate =
                                                await canUserGenerateText();

                                            if (!canGenerate) {
                                              await Future.delayed(
                                                const Duration(seconds: 2),
                                              );
                                              if (mounted) {
                                                showCustomDialog(context);
                                              }
                                            } else {
                                              await generateText(
                                                _ageController.text,
                                                '${_weightController.text}'
                                                ' $_selectedUnitWeight',
                                                _heightController.text,
                                                _selectedGender!,
                                                _selectedType!,
                                              );
                                            }
                                          }
                                        },
                                  style: isStreaming
                                      ? ElevatedButton.styleFrom(
                                          fixedSize: const Size(200, 50),
                                          backgroundColor: Colors.grey,
                                        )
                                      : ElevatedButton.styleFrom(
                                          fixedSize: const Size(200, 50),
                                          backgroundColor: Colors.green,
                                        ),
                                  child: Text('generate'.i18n()),
                                ),
                                const SizedBox(
                                  height: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  if (recipe.length<=2 && isStartAi)
                    const LinearProgressIndicator(
                        backgroundColor: Colors.white,
                    ),
                  if (isStartAi && recipe.length > 2)
                    Card(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 15.0),
                            child: Text('your-diet'.i18n(),
                              style: Theme.of(context).textTheme.titleMedium,),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(15.0),
                            child: Center(
                              child:  Text(
                                recipe,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ),
                          if (isLoading)
                            TextButton(
                              onPressed: () {
                                var dietProgram = recipe;
                                saveDietProgram(dietProgram);
                              },
                              child: Text(
                                'save-program'.i18n(),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            )
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        } else {
          return const RedirectLoginPage();
        }
      },
    );
  }
}
