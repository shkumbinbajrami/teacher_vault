import 'package:teacher_vault/core/utils/postgrest_error_message.dart';

String userErrorMessage(Object error) {
  if (error is StateError) return error.message;
  return postgrestErrorMessage(error);
}
