import 'package:flutter/material.dart';
import '../models/document.dart';
import '../screens/home/home_screen.dart';
import '../screens/add_document/add_document_screen.dart';
import '../screens/view_document/view_document_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/lock/lock_screen.dart';

class AppRouter {
  static const home = '/';
  static const addDocument = '/add-document';
  static const viewDocument = '/view-document';
  static const search = '/search';
  static const settings = '/settings';
  static const lock = '/lock';

  static Route<dynamic> generateRoute(RouteSettings s) {
    switch (s.name) {
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case addDocument:
        return MaterialPageRoute(
          builder: (_) =>
              AddDocumentScreen(existingDocument: s.arguments as Document?),
        );
      case viewDocument:
        return MaterialPageRoute(
          builder: (_) =>
              ViewDocumentScreen(document: s.arguments as Document),
        );
      case search:
        return MaterialPageRoute(builder: (_) => const SearchScreen());
      case settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case lock:
        return MaterialPageRoute(builder: (_) => const LockScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Page not found')),
          ),
        );
    }
  }
}
