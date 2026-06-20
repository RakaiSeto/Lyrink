import { requireNativeModule } from 'expo-modules-core';
import type { ModuleDefinition } from './types';

const ExpoMediaListener: ModuleDefinition = requireNativeModule('ExpoMediaListener');
export default ExpoMediaListener;
