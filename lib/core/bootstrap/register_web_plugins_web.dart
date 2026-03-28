import 'package:file_picker/_internal/file_picker_web.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Web: `FilePicker.platform` is set by the generated registrant. Some release
/// and hosting setups skip that step; registering here avoids
/// `LateInitializationError` on `FilePicker.platform`.
void registerWebPluginsEarly() {
  FilePickerWeb.registerWith(webPluginRegistrar);
}
