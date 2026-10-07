import 'package:flutter/foundation.dart';

bool get supportsFirebaseAuthentication => switch (defaultTargetPlatform) {
  TargetPlatform.android || TargetPlatform.iOS => true,
  _ => false,
};
