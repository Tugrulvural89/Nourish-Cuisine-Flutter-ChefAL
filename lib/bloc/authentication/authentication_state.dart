//authentication_state.dart

abstract class AuthenticationState {}

class InitialState extends AuthenticationState {}

class Authenticated extends AuthenticationState {
  final String userId;

  Authenticated(this.userId);
}

class Unauthenticated extends AuthenticationState {}
