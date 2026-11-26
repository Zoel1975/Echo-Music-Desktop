import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'file_storage.dart';
import 'settings_manager.dart';

/// A Python command plus the launcher arguments it needs (`py -3` on Windows).
class PythonCommand {
  const PythonCommand(this.executable, [this.prefix = const []]);

  final String executable;
  final List<String> prefix;

  List<String> withArgs(List<String> args) => [...prefix, ...args];
}

/// Finds a usable Python for stem separation, installs the three required
/// packages when missing, and downloads a portable CPython when the machine
/// has no Python at all. Nothing happens until separation is requested.
class StemPythonSetup extends ChangeNotifier {
  StemPythonSetup._();

  static final StemPythonSetup instance = StemPythonSetup._();

  static const String portableVersion = '3.11.10+20241016';
  static const String portableUrl =
      'https://github.com/astral-sh/python-build-standalone/releases/download/'
      '20241016/cpython-3.11.10%2B20241016-x86_64-pc-windows-msvc-'
      'install_only.tar.gz';

  PythonCommand? _resolved;
  bool _busy = false;
  double _progress = 0.0;
  String _status = '';

  bool get busy => _busy;
  double get progress => _progress;
  String get status => _status;

  Directory get cacheDir {
    try {
      if (GetIt.I.isRegistered<FileStorage>()) {
        return Directory(p.join(GetIt.I<FileStorage>().storagePaths.musicPath,
            'Stems', 'python'));
      }
    } catch (_) {}
    return Directory(p.join(Directory.systemTemp.path, 'echo_stems', 'python'));
  }

  String get portablePythonPath =>
      p.join(cacheDir.path, 'python', 'python.exe');

  void _set(String status, double progress) {
    _status = status;
    _progress = progress;
    notifyListeners();
  }

  /// Returns a Python that can import numpy, onnxruntime and soundfile.
  Future<PythonCommand> ensure() async {
    final resolved = _resolved;
    if (resolved != null && await _hasPackages(resolved)) return resolved;

    _busy = true;
    _set('Looking for Python…', 0.0);
    try {
      PythonCommand? found = await _detect();
      if (found != null && !await _hasPackages(found)) {
        _set('Installing numpy, onnxruntime and soundfile…', 0.1);
        final ok = await _installPackages(found);
        if (!ok) found = null;
      }
      if (found == null && Platform.isWindows) {
        found = await _installPortable();
      }
      if (found == null) {
        throw const StemPythonException(
          'Python 3 with numpy, onnxruntime and soundfile is required. '
          'Install Python 3 or set the executable in Settings → Player.',
        );
      }
      _resolved = found;
      _set('Python ready', 1.0);
      return found;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<PythonCommand?> _detect() async {
    if (GetIt.I.isRegistered<SettingsManager>()) {
      final configured = GetIt.I<SettingsManager>()
          .extra<String>('stemPython', '')
          .trim();
      if (configured.isNotEmpty &&
          await _probe(PythonCommand(configured)) != null) {
        return PythonCommand(configured);
      }
    }
    final env = Platform.environment['ECHO_PYTHON'];
    if (env != null && env.isNotEmpty) {
      final command = PythonCommand(env);
      if (await _probe(command) != null) return command;
    }
    for (final name in ['python', 'python3']) {
      final command = PythonCommand(name);
      final executable = await _probe(command);
      if (executable != null) {
        return PythonCommand(executable);
      }
    }
    if (Platform.isWindows) {
      final launcher = PythonCommand('py', const ['-3']);
      final executable = await _probe(launcher);
      if (executable != null) return launcher;
      final local = Platform.environment['LOCALAPPDATA'];
      if (local != null) {
        final root = Directory(p.join(local, 'Programs', 'Python'));
        if (root.existsSync()) {
          for (final entry in root.listSync()) {
            final exe = p.join(entry.path, 'python.exe');
            if (entry is Directory && File(exe).existsSync()) {
              return PythonCommand(exe);
            }
          }
        }
      }
      final portable = File(portablePythonPath);
      if (portable.existsSync()) return PythonCommand(portable.path);
    }
    return null;
  }

  /// Runs a tiny expression and returns the resolved executable, or null.
  Future<String?> _probe(PythonCommand command) async {
    try {
      final result = await Process.run(
        command.executable,
        command.withArgs([
          '-c',
          'import sys; print(sys.executable)',
        ]),
        runInShell: false,
      );
      if (result.exitCode != 0) return null;
      return result.stdout.toString().trim().split('\n').last.trim();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _hasPackages(PythonCommand command) async {
    try {
      final result = await Process.run(
        command.executable,
        command.withArgs([
          '-c',
          'import numpy, onnxruntime, soundfile',
        ]),
        runInShell: false,
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _installPackages(PythonCommand command) async {
    try {
      final result = await Process.run(
        command.executable,
        command.withArgs([
          '-m', 'pip', 'install', '--quiet', '--disable-pip-version-check',
          'numpy', 'onnxruntime', 'soundfile',
        ]),
        runInShell: false,
      );
      return result.exitCode == 0 && await _hasPackages(command);
    } catch (_) {
      return false;
    }
  }

  Future<PythonCommand?> _installPortable() async {
    _set('Downloading portable Python…', 0.0);
    final dir = cacheDir;
    await dir.create(recursive: true);
    final archive = File(p.join(dir.path, 'python.tar.gz'));
    final request = http.Request('GET', Uri.parse(portableUrl));
    final response = await http.Client().send(request);
    if (response.statusCode != 200) return null;
    final total = response.contentLength ?? 30 * 1024 * 1024;
    var received = 0;
    final sink = archive.openWrite();
    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      _set('Downloading portable Python…', (received / total).clamp(0.0, 0.8));
    }
    await sink.close();

    _set('Extracting Python…', 0.85);
    final extracted = await Process.run('tar', [
      '-xzf', archive.path, '-C', dir.path,
    ]);
    if (extracted.exitCode != 0) return null;
    final exe = File(portablePythonPath);
    if (!exe.existsSync()) return null;
    final command = PythonCommand(exe.path);
    _set('Installing numpy, onnxruntime and soundfile…', 0.9);
    if (!await _installPackages(command)) return null;
    return command;
  }
}

class StemPythonException implements Exception {
  const StemPythonException(this.message);
  final String message;
  @override
  String toString() => 'StemPythonException: $message';
}
