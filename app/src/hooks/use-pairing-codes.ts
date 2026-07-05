import { useEffect, useState, useCallback } from 'react';
import { Platform } from 'react-native';

import {
  addPairingCode as addCode,
  removePairingCode as removeCode,
  getPairingCodes as getCodes,
} from '../../modules/expo-media-listener/src/index';

export function usePairingCodes() {
  const [codes, setCodes] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);

  const refresh = useCallback(async () => {
    if (Platform.OS !== 'android') {
      setCodes([]);
      setLoading(false);
      return;
    }
    setLoading(true);
    const stored = await getCodes();
    setCodes(stored);
    setLoading(false);
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  const add = useCallback(async (code: string) => {
    if (Platform.OS !== 'android') return;
    await addCode(code);
    await refresh();
  }, [refresh]);

  const remove = useCallback(async (code: string) => {
    if (Platform.OS !== 'android') return;
    await removeCode(code);
    await refresh();
  }, [refresh]);

  return { codes, loading, add, remove, refresh };
}
