import 'dart:ffi';
import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';

/// Loads SQLite for host-side tests.
///
/// Some Linux distros (e.g. Fedora without `sqlite-devel`) ship only the
/// versioned `libsqlite3.so.0`, not the unversioned `libsqlite3.so` the
/// `sqlite3` package looks for by default. Fall back to the versioned name.
void _openSqlite() {
  open.overrideFor(OperatingSystem.linux, () {
    try {
      return DynamicLibrary.open('libsqlite3.so');
    } on ArgumentError {
      return DynamicLibrary.open('libsqlite3.so.0');
    }
  });
}

/// Points `sqflite` at an FFI-backed factory so `AppDatabase.instance`
/// works in `flutter test`. Call from `setUpAll`.
void setUpTestDatabase() {
  if (Platform.isLinux) {
    _openSqlite();
    databaseFactory = createDatabaseFactoryFfi(ffiInit: _openSqlite);
  } else {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
