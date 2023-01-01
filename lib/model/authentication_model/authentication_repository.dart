import 'package:notebook/model/authentication_model/user_entity.dart';

abstract class IAuthenticationRepository {
  Future<AuthenticatedUser> login({required final String login, required final String password});
  Future<AuthenticatedUser> logout();
}