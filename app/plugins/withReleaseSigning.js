const { withAppBuildGradle } = require('expo/config-plugins');

const RELEASE_SIGNING_CONFIG = `
        release {
            def ksPath = System.getenv("KEYSTORE_PATH")
            if (ksPath) {
                storeFile file(ksPath)
                storePassword System.getenv("KEYSTORE_PASSWORD") ?: ''
                keyAlias System.getenv("KEY_ALIAS") ?: ''
                keyPassword System.getenv("KEY_PASSWORD") ?: ''
            } else {
                storeFile file('debug.keystore')
                storePassword 'android'
                keyAlias 'androiddebugkey'
                keyPassword 'android'
            }
        }`;

module.exports = function withReleaseSigning(config) {
  return withAppBuildGradle(config, (config) => {
    let contents = config.modResults.contents;

    // Add release signing config after the debug block
    const debugBlockEnd = contents.indexOf('debug {') !== -1
      ? contents.indexOf('}', contents.indexOf('debug {')) + 1
      : null;

    if (debugBlockEnd && !contents.includes('release {')) {
      contents =
        contents.slice(0, debugBlockEnd) +
        '\n' +
        RELEASE_SIGNING_CONFIG +
        contents.slice(debugBlockEnd);
    }

    // Point release buildType to release signing config
    contents = contents.replace(
      /buildTypes\s*\{[\s\S]*?release\s*\{[\s\S]*?signingConfig\s+signingConfigs\.debug/,
      (match) => match.replace('signingConfigs.debug', 'signingConfigs.release')
    );

    config.modResults.contents = contents;
    return config;
  });
};
