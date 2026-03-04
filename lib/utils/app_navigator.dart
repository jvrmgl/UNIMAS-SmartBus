import 'package:flutter/material.dart';

/// A global navigator key used to push routes from outside of the widget tree
/// (e.g. inside [NotificationService] when a push notification is tapped).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Global messenger key for showing SnackBars safely from async flows
/// without depending on transient/deactivated build contexts.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
	GlobalKey<ScaffoldMessengerState>();
