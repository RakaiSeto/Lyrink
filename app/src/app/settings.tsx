import { useState, useRef } from 'react';
import { Modal, Platform, Pressable, StyleSheet, TextInput, ScrollView, Alert, View, Text } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { BottomTabInset, MaxContentWidth, Spacing } from '@/constants/theme';
import { usePairingCodes } from '@/hooks/use-pairing-codes';

function PairingCodeItem({ code, onRemove }: { code: string; onRemove: () => void }) {
  const handleRemove = () => {
    Alert.alert('Remove Code', `Remove pairing code ${code}?`, [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Remove', style: 'destructive', onPress: onRemove },
    ]);
  };

  return (
    <ThemedView type="backgroundElement" style={styles.codeItem}>
      <ThemedText style={styles.codeText}>{code}</ThemedText>
      <Pressable style={styles.removeButton} onPress={handleRemove}>
        <ThemedText style={styles.removeButtonText}>Remove</ThemedText>
      </Pressable>
    </ThemedView>
  );
}

function OtpInput({ onComplete }: { onComplete: (code: string) => void }) {
  const [value, setValue] = useState('');
  const inputRef = useRef<any>(null);

  const handleChangeText = (text: string) => {
    const cleaned = text.replace(/\D/g, '').slice(0, 6);
    setValue(cleaned);
    if (cleaned.length === 6) {
      onComplete(cleaned);
    }
  };

  const focusInput = () => inputRef.current?.focus();

  return (
    <Pressable style={styles.otpContainer} onPress={focusInput}>
      <TextInput
        ref={inputRef}
        value={value}
        onChangeText={handleChangeText}
        keyboardType="numeric"
        maxLength={6}
        style={styles.hiddenInput}
        caretHidden
      />
      {[0, 1, 2, 3, 4, 5].map((i) => (
        <View key={i} style={[styles.otpBox, i === value.length && styles.otpBoxActive]}>
          {i < value.length ? (
            <Text style={styles.otpText}>{value[i]}</Text>
          ) : (
            <Text style={styles.otpPlaceholder}>-</Text>
          )}
        </View>
      ))}
    </Pressable>
  );
}

export default function SettingsScreen() {
  const { codes, loading, add, remove } = usePairingCodes();
  const [modalVisible, setModalVisible] = useState(false);

  const handleComplete = async (code: string) => {
    if (codes.includes(code)) {
      Alert.alert('Already Added', 'This pairing code is already stored.');
      return;
    }
    await add(code);
    setModalVisible(false);
  };

  const openModal = () => setModalVisible(true);
  const closeModal = () => setModalVisible(false);

  return (
    <ThemedView style={styles.container}>
      <SafeAreaView style={styles.safeArea}>
        <ThemedView type="backgroundElement" style={styles.section}>
          <ThemedText type="subtitle" style={styles.sectionTitle}>
            Widget Pairing Codes
          </ThemedText>
          <ThemedText type="small" style={styles.sectionDescription}>
            Masukkan kode 6 digit dari widget Lyrink untuk menyinkronkan.
          </ThemedText>
        </ThemedView>

        {codes.length > 0 ? (
          <ScrollView contentContainerStyle={styles.listContent}>
            {codes.map((code) => (
              <PairingCodeItem key={code} code={code} onRemove={() => remove(code)} />
            ))}
          </ScrollView>
        ) : (
          !loading && (
            <ThemedView style={styles.emptyState}>
              <ThemedText type="small" style={styles.emptyText}>
                Belum ada kode tersimpan.
              </ThemedText>
            </ThemedView>
          )
        )}

        <Pressable style={styles.addButton} onPress={openModal}>
          <ThemedText style={styles.addButtonText}>+ Add Pairing</ThemedText>
        </Pressable>
      </SafeAreaView>

      <Modal
        visible={modalVisible}
        transparent
        animationType="fade"
        onRequestClose={closeModal}
      >
        <Pressable style={styles.modalOverlay} onPress={closeModal}>
          <Pressable style={styles.modalCard} onPress={(e) => e.stopPropagation()}>
            <ThemedText type="subtitle" style={styles.modalTitle}>
              Add Pairing
            </ThemedText>
            <ThemedText type="small" style={styles.modalSubtitle}>
              Masukkan kode dari widget:
            </ThemedText>

            <OtpInput onComplete={handleComplete} />

            <Pressable style={styles.cancelButton} onPress={closeModal}>
              <ThemedText style={styles.cancelButtonText}>Cancel</ThemedText>
            </Pressable>
          </Pressable>
        </Pressable>
      </Modal>
    </ThemedView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  safeArea: {
    flex: 1,
    paddingHorizontal: Spacing.four,
    gap: Spacing.three,
    paddingBottom: BottomTabInset + Spacing.three,
    maxWidth: MaxContentWidth,
    alignSelf: 'center',
    width: '100%',
  },
  section: {
    paddingHorizontal: Spacing.three,
    paddingVertical: Spacing.three,
    borderRadius: Spacing.four,
    gap: Spacing.two,
  },
  sectionTitle: {
    textAlign: 'center',
  },
  sectionDescription: {
    textAlign: 'center',
    opacity: 0.6,
  },
  listContent: {
    gap: Spacing.two,
  },
  codeItem: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.three,
    paddingVertical: Spacing.two,
    borderRadius: Spacing.two,
  },
  codeText: {
    fontSize: 20,
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
    letterSpacing: 4,
    fontWeight: '700',
  },
  removeButton: {
    backgroundColor: '#FF3B3033',
    paddingHorizontal: Spacing.two,
    paddingVertical: Spacing.half,
    borderRadius: Spacing.one,
  },
  removeButtonText: {
    color: '#FF3B30',
    fontSize: 12,
    fontWeight: '600',
  },
  emptyState: {
    alignItems: 'center',
    paddingVertical: Spacing.five,
  },
  emptyText: {
    opacity: 0.4,
  },
  addButton: {
    backgroundColor: '#208AEF',
    paddingVertical: Spacing.two,
    borderRadius: Spacing.two,
    alignItems: 'center',
  },
  addButtonText: {
    color: '#FFFFFF',
    fontWeight: '700',
    fontSize: 16,
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.6)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalCard: {
    backgroundColor: '#1C1C1E',
    borderRadius: 16,
    padding: 24,
    width: '85%',
    gap: Spacing.three,
    alignItems: 'center',
  },
  modalTitle: {
    fontSize: 18,
  },
  modalSubtitle: {
    opacity: 0.6,
    fontSize: 14,
  },
  otpContainer: {
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 6,
    paddingVertical: Spacing.two,
  },
  hiddenInput: {
    position: 'absolute',
    opacity: 0,
    width: 1,
    height: 1,
  },
  otpBox: {
    width: 44,
    height: 52,
    borderRadius: 8,
    borderWidth: 2,
    borderColor: '#444',
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#2C2C2E',
  },
  otpBoxActive: {
    borderColor: '#208AEF',
  },
  otpText: {
    fontSize: 22,
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
    fontWeight: '700',
    color: '#FFFFFF',
  },
  otpPlaceholder: {
    fontSize: 22,
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
    color: '#444',
  },
  cancelButton: {
    paddingVertical: Spacing.two,
    paddingHorizontal: Spacing.four,
    borderRadius: Spacing.two,
    alignItems: 'center',
    width: '100%',
  },
  cancelButtonText: {
    color: '#8E8E93',
    fontSize: 16,
  },
});
