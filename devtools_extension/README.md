# diesel_devtools_extension

The Flutter web app for the **diesel** DevTools tab. It talks to the connected app's
`ext.diesel.*` VM service extensions (registered by the `diesel_devtools` runtime) to list
instances, browse tables, page rows, and run SQL.

This app is intentionally **outside** the Dart pub workspace so it resolves against the Flutter SDK
independently (the runtime packages stay pure Dart).

## Develop the UI

Run against the simulated DevTools environment (no app connection needed for layout work):

```bash
flutter run -d chrome --dart-define=use_simulated_environment=true
```

For a live run, launch a target that registers a connection (e.g.
`dart run --observe packages/diesel_devtools/tool/inspector_demo.dart`), then open DevTools on its
VM service URI and use the diesel tab.

## Build & publish into the package

The compiled output is git-ignored; regenerate it into the `diesel_devtools` package with:

```bash
dart run devtools_extensions build_and_copy \
  --source=. --dest=../packages/diesel_devtools/extension/devtools
dart run devtools_extensions validate --package=../packages/diesel_devtools
```
