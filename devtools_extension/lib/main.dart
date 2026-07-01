import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

import 'src/inspector_screen.dart';

void main() => runApp(const DieselInspectorExtension());

/// Root of the diesel DevTools extension. [DevToolsExtension] supplies the app
/// shell (theme, connection state, VM service manager); we render the inspector
/// as its child.
class DieselInspectorExtension extends StatelessWidget {
  const DieselInspectorExtension({super.key});

  @override
  Widget build(BuildContext context) =>
      const DevToolsExtension(child: InspectorScreen());
}
