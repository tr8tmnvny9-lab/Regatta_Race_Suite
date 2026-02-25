import React, { useEffect, useState } from 'react';
import { StatusBar } from 'expo-status-bar';
import { StyleSheet, Text, View, SafeAreaView } from 'react-native';
import { RegattaEngine, RaceState } from '@regatta/core';

export default function App() {
  const [engine, setEngine] = useState<RegattaEngine | null>(null);
  const [state, setState] = useState<Partial<RaceState>>({});
  const [connected, setConnected] = useState(false);

  useEffect(() => {
    // Determine the IP of the machine running the backend. For iOS Simulator, localhost is fine.
    // For a real device, this needs to be the LAN IP (e.g., 192.168.1.X)
    const backendUrl = 'http://localhost:3001';

    console.log(`[Tracker] Initializing RegattaEngine connecting to ${backendUrl}`);
    const regattaEngine = new RegattaEngine(backendUrl, 'tracker-test-1');

    regattaEngine.onStateChange((newState) => {
      setState(newState);
      setConnected(regattaEngine.connected);
    });

    setEngine(regattaEngine);
    regattaEngine.connect();

    return () => {
      regattaEngine.disconnect();
    };
  }, []);

  // Format time (e.g., 5:00)
  const formatTime = (seconds?: number) => {
    if (seconds === undefined || seconds < 0) return '--:--';
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return `${m}:${s.toString().padStart(2, '0')}`;
  };

  const statusColor = state.status === 'RACING' ? '#22c55e' :
    state.status === 'PRE_START' ? '#f59e0b' : '#3b82f6';

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar style="light" />

      {/* Header */}
      <View style={styles.header}>
        <View style={styles.connectionBadge}>
          <View style={[styles.statusDot, { backgroundColor: connected ? '#22c55e' : '#ef4444' }]} />
          <Text style={styles.connectionText}>{connected ? 'LIVE' : 'OFFLINE'}</Text>
        </View>
        <Text style={styles.raceStatus}>
          {state.status ? state.status.replace('_', ' ') : 'WAITING'}
        </Text>
      </View>

      {/* Main HUD */}
      <View style={styles.hudContainer}>
        {/* Sequence Timer */}
        <View style={styles.instrumentCard}>
          <Text style={styles.instrumentLabel}>TIME TO START</Text>
          <Text style={[styles.timerValue, { color: statusColor }]}>
            {state.status === 'RACING' ? 'RACING' : formatTime(state.sequenceTimeRemaining ?? -1)}
          </Text>
          <Text style={styles.instrumentSubLabel}>
            Flags: {state.prepFlag || 'None'}
          </Text>
        </View>

        {/* Telemetry Row */}
        <View style={styles.telemetryRow}>
          <View style={[styles.instrumentCard, { flex: 1, marginRight: 8 }]}>
            <Text style={styles.instrumentLabel}>SOG</Text>
            <View style={{ flexDirection: 'row', alignItems: 'baseline' }}>
              <Text style={styles.telemetryValue}>0.0</Text>
              <Text style={styles.telemetryUnit}>kt</Text>
            </View>
          </View>

          <View style={[styles.instrumentCard, { flex: 1, marginLeft: 8 }]}>
            <Text style={styles.instrumentLabel}>COG</Text>
            <View style={{ flexDirection: 'row', alignItems: 'baseline' }}>
              <Text style={styles.telemetryValue}>000</Text>
              <Text style={styles.telemetryUnit}>°</Text>
            </View>
          </View>
        </View>
      </View>

    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingTop: 10,
    paddingBottom: 20,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(255,255,255,0.1)',
  },
  connectionBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(255,255,255,0.1)',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 20,
  },
  statusDot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    marginRight: 6,
  },
  connectionText: {
    color: '#fff',
    fontSize: 10,
    fontWeight: '800',
    letterSpacing: 2,
  },
  raceStatus: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '800',
    letterSpacing: 2,
    textTransform: 'uppercase',
  },
  hudContainer: {
    flex: 1,
    padding: 20,
    paddingTop: 40,
  },
  instrumentCard: {
    backgroundColor: '#111',
    borderRadius: 24,
    padding: 24,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.05)',
  },
  telemetryRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  instrumentLabel: {
    color: '#666',
    fontSize: 12,
    fontWeight: '800',
    letterSpacing: 2,
    marginBottom: 8,
  },
  timerValue: {
    fontSize: 72,
    fontWeight: '900',
    letterSpacing: -2,
  },
  instrumentSubLabel: {
    color: '#444',
    fontSize: 14,
    fontWeight: '600',
    marginTop: 8,
  },
  telemetryValue: {
    color: '#fff',
    fontSize: 48,
    fontWeight: '900',
    letterSpacing: -1,
  },
  telemetryUnit: {
    color: '#666',
    fontSize: 16,
    fontWeight: '600',
    marginLeft: 4,
    paddingBottom: 6,
  },
});
