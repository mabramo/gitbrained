import 'package:flutter/material.dart';
import 'exceptions.dart';

void showErrorSnackBar(BuildContext context, Object error) {
  final message = error is GitbrainedException
      ? error.message
      : 'Something went wrong. Try again.';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}
