// Bridging declaration for expo-router v56 packaging bug:
// build/index.d.ts re-exports from 'expo-router/src/exports' but the
// src/ directory is not shipped, so tsc can't resolve ThemeProvider/DarkTheme/DefaultTheme.
// This declaration makes them available from the correct resolution path.
declare module 'expo-router' {
  export { ThemeProvider } from 'expo-router/build/react-navigation/core/theming/ThemeProvider';
  export { DarkTheme } from 'expo-router/build/react-navigation/native/theming/DarkTheme';
  export { DefaultTheme } from 'expo-router/build/react-navigation/native/theming/DefaultTheme';
  export { useTheme } from 'expo-router/build/react-navigation/core/theming/useTheme';
}
