import Java from 'frida-java-bridge';

// Private adapter for the inspected Meta AI 289.0.0.25.162 / 968902270 build.
import { HEADSET, GLASSES } from './config.template.js';
const VERSION = '289.0.0.25.162';
const STOP = 'io.github.metaearbud.background.STOP_BACKGROUND';
let app, adapter, profile, listener, receiver, stopReceiver, store, wake;
let manager, scope, settings, key, prefs, repo;
let stopped = false, busy = false, desired = null, timer, poll, retries = 0, lastVerified = 0;
function field(o, name) {
  const f = o.getClass().getDeclaredField(name); f.setAccessible(true); return f.get(o);
}
function log(message) {
  console.log(new Date().toISOString() + ' ' + message);
  try { Java.use('android.util.Log').i('MetaEarbudBackground', message); } catch (_) {}
  if (store) store.edit().putString('status', message).putLong('updated_ms', Date.now()).apply();
}
function safe(fn) { Java.perform(() => { try { if (!stopped) fn(); } catch(e) { busy = false; release(); log('ERROR background operation failed'); } }); }
function release() { if (wake && wake.isHeld()) wake.release(); }
function stop() {
  if (stopped) return;
  stopped = true;
  clearTimeout(timer); clearInterval(poll);
  try { if (receiver) app.unregisterReceiver(receiver); } catch (_) {}
  try { if (stopReceiver) app.unregisterReceiver(stopReceiver); } catch (_) {}
  try { if (profile) adapter.closeProfileProxy(2, profile); } catch (_) {}
  release(); log('STOPPED');
}
// The agent is eternalized for this Meta process. STOP unregisters all listeners;
// it is not unloaded while Android might still hold Java callback references.

function acquireManager() {
  if (manager && scope && Java.cast(field(scope, 'A02'), Java.use('java.util.concurrent.atomic.AtomicBoolean')).get()) return true;
  manager = null;
  const candidates = [];
  Java.choose('X.6Du', { onMatch(o) { candidates.push(Java.retain(o)); }, onComplete() {} });
  for (const s of candidates) {
    try {
      if (!Java.cast(field(s, 'A02'), Java.use('java.util.concurrent.atomic.AtomicBoolean')).get()) continue;
      const providerObject = field(s, 'A00');
      const provider = Java.cast(providerObject, Java.use(providerObject.getClass().getName().toString()));
      const device = provider.getDeviceRecord();
      if (field(device, 'A06').toString().toUpperCase() !== GLASSES) continue;
      scope = s;
      manager = Java.retain(Java.use('X.6aH').A00(s));
      prefs = Java.cast(field(field(manager, 'A00'), 'A00'), Java.use('X.06k'));
      repo = Java.use('X.Gme').$new(GLASSES);
      log('GLASSES_READY'); return true;
    } catch(e) { log('SCOPE_ERROR'); }
  }
  return false;
}
function connectedNow() {
  if (!profile) return null;
  const devices = profile.getConnectedDevices();
  for (let i = 0; i < devices.size(); i++) {
    const d = Java.cast(devices.get(i), Java.use('android.bluetooth.BluetoothDevice'));
    if (d.getAddress().toString().toUpperCase() === HEADSET) return true;
  }
  return false;
}
function request(value) {
  if (value === null || stopped) return;
  if (desired !== value) { desired = value; retries = 0; lastVerified = 0; log('HEADSET_CONNECTED=' + value); }
  if (!busy) {
    clearTimeout(timer);
    timer = setTimeout(() => safe(apply), 2500);
  }
}
function apply() {
  if (busy || desired === null || retries >= 3) return;
  const value = connectedNow();
  if (value === null) return;
  if (value !== desired) { request(value); return; }
  if (!desired && !store.getBoolean('owned', false)) return;
  if (desired && lastVerified && Date.now() - lastVerified < 3600000) return;
  if (!acquireManager()) { log('WAITING_FOR_GLASSES'); return; }
  busy = true;
  wake.acquire(20000);
  const now = Math.floor(Date.now()/1000);
  const pauseBefore = settings.A04(key, GLASSES).toString() || '1';
  const batteryBefore = prefs.getBoolean('battery_saver_mode_enabled', false);
  if (desired && !store.getBoolean('owned', false)) {
    // Commit the restore point before any device writes, including across process restarts.
    const saved = store.edit().putString('previous_pause', pauseBefore).putBoolean('previous_battery', batteryBefore).putBoolean('owned', true).commit();
    if (!saved) { busy = false; release(); log('RESTORE_POINT_WRITE_FAILED'); return; }
  }
  const goal = desired;
  const batteryGoal = goal ? true : store.getBoolean('previous_battery', false);
  const previousPause = store.getString('previous_pause', '1').toString();
  const pauseGoal = goal ? String(Math.max(now + 28800, Number(previousPause) || 1)) : (Number(previousPause) > now ? previousPause : '1');
  // The repository performs a real device settings sync on this background thread.
  const pauseOk = pauseBefore === pauseGoal || repo.A00(pauseGoal);
  if (batteryBefore !== batteryGoal) {
    // A0C enables, A0B restores the settings saved by Meta's own battery saver implementation.
    if (batteryGoal) manager.A0C(null, 'earbud_automation', false);
    else manager.A0B(null, 'earbud_automation', false);
  }
  log('APPLY connected=' + goal + ' pauseSync=' + pauseOk);
  setTimeout(() => safe(() => {
    const batteryAfter = prefs.getBoolean('battery_saver_mode_enabled', false);
    const pauseAfter = settings.A04(key, GLASSES).toString();
    const ok = pauseOk && batteryAfter === batteryGoal && pauseAfter === pauseGoal;
    busy = false; release();
    if (ok) {
      if (!goal) store.edit().putBoolean('owned', false).commit();
      lastVerified = goal ? Date.now() : 0;
      retries = 0;
      const power = Java.cast(app.getSystemService('power'), Java.use('android.os.PowerManager'));
      log('VERIFIED connected=' + goal + ' battery=' + batteryAfter + ' pause=' + (Number(pauseAfter) > Math.floor(Date.now()/1000)) + ' screenOn=' + power.isInteractive());
    } else { retries++; log('VERIFY_FAILED attempt=' + retries); }
    if (desired !== goal || !ok) {
      timer = setTimeout(() => safe(apply), 5000);
    }
  }), 6500);
}

Java.perform(() => {
  try {
    app = Java.use('android.app.ActivityThread').currentApplication();
    const info = app.getPackageManager().getPackageInfo('com.facebook.stella', 0);
    if (info.versionName.value.toString() !== VERSION || info.getLongVersionCode().toString() !== '968902270') { console.log('UNSUPPORTED_VERSION'); return; }
    store = app.getSharedPreferences('meta_earbud_background', 0);
    settings = Java.use('com.facebook.wearable.glasses.assistant.settings.SmartGlassesAssistantSettings');
    key = Java.use('X.3H1').A1j.value;
    wake = Java.cast(app.getSystemService('power'), Java.use('android.os.PowerManager')).newWakeLock(1, 'MetaEarbud:apply');
    wake.setReferenceCounted(false);
    adapter = Java.use('android.bluetooth.BluetoothAdapter').getDefaultAdapter();
    const suffix = String(Date.now());
    const Receiver = Java.registerClass({
      name: 'io.github.metaearbud.background.BluetoothReceiver' + suffix,
      superClass: Java.use('android.content.BroadcastReceiver'),
      methods: { onReceive: { returnType: 'void', argumentTypes: ['android.content.Context', 'android.content.Intent'], implementation(context, intent) {
        const d = intent.getParcelableExtra.overload('java.lang.String').call(intent, 'android.bluetooth.device.extra.DEVICE');
        if (!d) return;
        const device = Java.cast(d, Java.use('android.bluetooth.BluetoothDevice'));
        if (device.getAddress().toString().toUpperCase() !== HEADSET) return;
        const state = intent.getIntExtra('android.bluetooth.profile.extra.STATE', -1);
        if (state === 0 || state === 2) {
          wake.acquire(20000);
          request(state === 2);
        }
      } } }
    });
    receiver = Receiver.$new();
    app.registerReceiver.overload('android.content.BroadcastReceiver', 'android.content.IntentFilter', 'int')
      .call(app, receiver, Java.use('android.content.IntentFilter').$new('android.bluetooth.a2dp.profile.action.CONNECTION_STATE_CHANGED'), 2);
    const StopReceiver = Java.registerClass({
      name: 'io.github.metaearbud.background.StopReceiver' + suffix,
      superClass: Java.use('android.content.BroadcastReceiver'),
      methods: { onReceive: { returnType: 'void', argumentTypes: ['android.content.Context', 'android.content.Intent'], implementation(context, intent) { stop(); } } }
    });
    stopReceiver = StopReceiver.$new();
    app.registerReceiver.overload('android.content.BroadcastReceiver', 'android.content.IntentFilter', 'java.lang.String', 'android.os.Handler', 'int')
      .call(app, stopReceiver, Java.use('android.content.IntentFilter').$new(STOP), 'com.facebook.stella.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION', null, 2);
    const Listener = Java.registerClass({
      name: 'io.github.metaearbud.background.ProfileListener' + suffix,
      implements: [Java.use('android.bluetooth.BluetoothProfile$ServiceListener')],
      methods: {
        onServiceConnected: { returnType: 'void', argumentTypes: ['int', 'android.bluetooth.BluetoothProfile'], implementation(id, proxy) { profile = Java.retain(proxy); request(connectedNow()); } },
        onServiceDisconnected: { returnType: 'void', argumentTypes: ['int'], implementation(id) { profile = null; } }
      }
    });
    listener = Listener.$new();
    adapter.getProfileProxy(app, listener, 2);
    poll = setInterval(() => safe(() => {
      if (!profile) adapter.getProfileProxy(app, listener, 2);
      else request(connectedNow());
    }), 30000);
    log('STARTED background adapter 1.0.2');
  } catch(e) { console.log('INIT_ERROR'); stop(); }
});
