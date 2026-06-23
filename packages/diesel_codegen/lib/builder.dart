import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/queryable_generator.dart';

/// build_runner entry point (wired in `build.yaml`). Emits a shared part so the
/// generated mappers live in `<file>.g.dart` alongside the user's classes.
Builder queryableBuilder(BuilderOptions options) =>
    SharedPartBuilder([const QueryableGenerator()], 'diesel');
