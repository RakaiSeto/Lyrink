const { getDefaultConfig } = require('expo/metro-config');

/** @type {import('expo/metro-config').MetroConfig} */
const config = getDefaultConfig(__dirname);

// Exclude android build artifacts inside node_modules to stay under inotify limit
config.watchFolders = [__dirname];
config.resolver.blockList = [
  /node_modules\/.*\/android\/build\/.*/,
];

module.exports = config;