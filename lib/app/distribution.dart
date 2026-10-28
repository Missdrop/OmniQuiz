// Compile-time distribution settings keep Store updates separate from standalone installers.

/// Enabled only by the Microsoft Store packaging script.
const microsoftStoreBuild = bool.fromEnvironment('OMNIQUIZ_STORE');
const microsoftStoreId = '9N1LK3V015SR';
