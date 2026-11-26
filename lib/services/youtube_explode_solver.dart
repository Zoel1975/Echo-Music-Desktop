import 'dart:convert';
import 'dart:io';

import 'package:youtube_explode_dart/src/reverse_engineering/challenges/ejs/base_ejs_solver.dart';
import 'package:youtube_explode_dart/src/reverse_engineering/challenges/ejs/ejs.dart';

/// Executes the signature/n-param JavaScript extracted from YouTube's player
/// using Node.js. youtube_explode_dart ships only a Deno solver; Node is far
/// more common on desktop and is already present on most developer machines.
/// When Node is missing the resolver simply falls back to the InnerTube path.
class NodeEJSSolver extends BaseEJSSolver {
  String? _modules;

  static Future<NodeEJSSolver> create() async {
    final solver = NodeEJSSolver();
    solver._modules = await EJSBuilder.getJSModules();
    return solver;
  }

  static bool get isNodeAvailable {
    try {
      final result = Process.runSync('node', ['--version'], runInShell: true);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String> executeJavaScript(String jsCode) async {
    final modules = _modules ?? await EJSBuilder.getJSModules();
    final dir = await Directory.systemTemp.createTemp('echo_ejs_');
    final script = File('${dir.path}/run.js');
    final output = File('${dir.path}/out.txt');
    await script.writeAsString(
      '$modules\n'
      'const __r = $jsCode;\n'
      'require("fs").writeFileSync(${jsonEncode(output.path)}, String(__r));\n',
    );
    try {
      final result = await Process.run('node', [script.path], runInShell: true);
      if (result.exitCode != 0) {
        throw Exception('node failed: ${result.stderr}');
      }
      return await output.readAsString();
    } finally {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _modules = null;
  }
}
