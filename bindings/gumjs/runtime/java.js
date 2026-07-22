const android16JavaBridgeDefaultDenylist = [
  'com.chunqiunativecheck'
];

if (shouldLoadJavaBridge()) {
  Frida._java = require('frida-java-bridge');
} else {
  Frida._java = makeAndroid16JavaBridgeStub();
}

function shouldLoadJavaBridge() {
  if (Process.platform !== 'linux')
    return true;

  const apiLevel = getAndroidApiLevel();
  if (apiLevel === null || apiLevel < 36)
    return true;

  const processName = getProcessName();

  if (getEnvFlag('FRIDA_DISABLE_JAVA_BRIDGE') || hasJavaBridgeProcessControlFile('deny', processName))
    return false;

  if (getEnvFlag('FRIDA_FORCE_JAVA_BRIDGE') || hasJavaBridgeProcessControlFile('force', processName))
    return true;

  if (android16JavaBridgeDefaultDenylist.indexOf(processName) !== -1)
    return false;

  if (hasJavaBridgeProcessControlFile('allow', processName))
    return true;

  return hasJavaBridgeOverrideFile();
}

function getAndroidApiLevel() {
  try {
    const systemPropertyGet = new NativeFunction(
      Module.getExportByName('libc.so', '__system_property_get'),
      'int', ['pointer', 'pointer']);
    const key = Memory.allocUtf8String('ro.build.version.sdk');
    const value = Memory.alloc(92);
    const length = systemPropertyGet(key, value);
    if (length <= 0)
      return null;
    return parseInt(value.readUtf8String(length), 10);
  } catch (e) {
    return null;
  }
}

function getProcessName() {
  try {
    const cmdline = File.readAllText('/proc/self/cmdline');
    const nulOffset = cmdline.indexOf('\u0000');
    const name = (nulOffset === -1) ? cmdline : cmdline.substring(0, nulOffset);
    if (name.length !== 0)
      return basename(name);
  } catch (e) {
  }

  try {
    const status = File.readAllText('/proc/self/status');
    const match = /^Name:\s*(.+)$/m.exec(status);
    if (match !== null)
      return match[1].trim();
  } catch (e) {
  }

  return '';
}

function basename(path) {
  const slashOffset = path.lastIndexOf('/');
  return (slashOffset === -1) ? path : path.substring(slashOffset + 1);
}

function getEnvFlag(name) {
  try {
    const getenv = new NativeFunction(Module.getExportByName('libc.so', 'getenv'), 'pointer', ['pointer']);
    const value = getenv(Memory.allocUtf8String(name));
    if (value.isNull())
      return false;
    const text = value.readUtf8String();
    return text === '1' || text === 'true' || text === 'yes' || text === 'on';
  } catch (e) {
    return false;
  }
}

function hasJavaBridgeProcessControlFile(mode, processName) {
  if (processName.length === 0)
    return false;

  return hasReadableFile('/data/local/tmp/frida-java-bridge-' + mode + '.d/' + processName) ||
      hasReadableFile('/data/local/tmp/.frida-java-bridge-' + mode + '.d/' + processName);
}

function hasJavaBridgeOverrideFile() {
  const paths = [
    '/data/local/tmp/frida-enable-java-bridge',
    '/data/local/tmp/.frida-enable-java-bridge'
  ];

  for (const path of paths) {
    if (hasReadableFile(path))
      return true;
  }

  return false;
}

function hasReadableFile(path) {
  try {
    File.readAllText(path);
    return true;
  } catch (e) {
    return false;
  }
}

function makeAndroid16JavaBridgeStub() {
  const unavailable = () => {
    throw new Error('Android API 36 Java bridge is gated by this stability build; use native-only hooks or per-process Java bridge opt-in');
  };

  return Object.freeze({
    available: false,
    perform: unavailable,
    performNow: unavailable,
    scheduleOnMainThread: unavailable,
    enumerateLoadedClasses: unavailable,
    enumerateLoadedClassesSync: unavailable,
    enumerateClassLoaders: unavailable,
    enumerateClassLoadersSync: unavailable,
    use: unavailable,
    openClassFile: unavailable,
    choose: unavailable,
    retain: unavailable,
    cast: unavailable,
    array: unavailable,
    registerClass: unavailable,
    deoptimizeEverything: unavailable,
    deoptimizeBootImage: unavailable,
    deoptimizeMethod: unavailable,
    backtrace: unavailable
  });
}
