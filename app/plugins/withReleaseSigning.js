const { withAppBuildGradle } = require('expo/config-plugins');

const RELEASE_SIGNING = `        release {
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

    // Find signingConfigs block boundaries by brace counting
    const scStart = contents.indexOf('signingConfigs {');
    if (scStart === -1) return config;

    let depth = 0;
    let scEnd = -1;
    for (let i = contents.indexOf('{', scStart); i < contents.length; i++) {
      if (contents[i] === '{') depth++;
      if (contents[i] === '}') depth--;
      if (depth === 0) { scEnd = i + 1; break; }
    }
    if (scEnd === -1) return config;

    // Only inject if release signing config doesn't exist within signingConfigs block
    const signingConfigsBlock = contents.substring(scStart, scEnd);
    if (!signingConfigsBlock.includes('release {')) {
      const debugStart = signingConfigsBlock.indexOf('debug {');
      if (debugStart !== -1) {
        let dDepth = 0;
        let debugEnd = -1;
        for (let i = signingConfigsBlock.indexOf('{', debugStart); i < signingConfigsBlock.length; i++) {
          if (signingConfigsBlock[i] === '{') dDepth++;
          if (signingConfigsBlock[i] === '}') dDepth--;
          if (dDepth === 0) { debugEnd = i + 1; break; }
        }
        if (debugEnd !== -1) {
          const absoluteInsertPos = scStart + debugEnd;
          contents = contents.slice(0, absoluteInsertPos) +
            '\n' + RELEASE_SIGNING + '\n' +
            contents.slice(absoluteInsertPos);
        }
      }
    }

    // Replace signingConfigs.debug -> signingConfigs.release in buildTypes.release
    contents = contents.replace(
      /buildTypes\s*\{[\s\S]*?release\s*\{[^}]*signingConfig\s+signingConfigs\.debug/,
      (match) => match.replace('signingConfigs.debug', 'signingConfigs.release')
    );

    config.modResults.contents = contents;
    return config;
  });
};
