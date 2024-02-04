//authentication_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'authentication_state.dart';

class AuthenticationBloc extends Cubit<AuthenticationState> {
  AuthenticationBloc() : super(InitialState());

  void logIn(String userId) {
    emit(Authenticated(userId));
  }

  void logOut() {
    emit(Unauthenticated());
  }
}
