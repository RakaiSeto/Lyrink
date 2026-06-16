const { withGradleProperties } = require('expo/config-plugins');

const PROPERTIES = [
  { key: 'reactNativeArchitectures', value: 'arm64-v8a' },
  { key: 'org.gradle.jvmargs', value: '-Xmx4096m -XX:MaxMetaspaceSize=1024m' },
  { key: 'org.gradle.parallel', value: 'false' },
];

module.exports = function withGradlePropertiesCustom(config) {
  return withGradleProperties(config, (config) => {
    for (const { key, value } of PROPERTIES) {
      const existing = config.modResults.findIndex(
        (item) => item.type === 'property' && item.key === key
      );

      if (existing !== -1) {
        config.modResults.splice(existing, 1);
      }

      config.modResults.push({ type: 'property', key, value });
    }

    return config;
  });
};
