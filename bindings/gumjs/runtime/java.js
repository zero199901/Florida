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

function hasJavaBridgeOverrideFile() {
  const paths = [
    '/data/local/tmp/frida-enable-java-bridge',
    '/data/local/tmp/.frida-enable-java-bridge'
  ];

  for (const path of paths) {
    try {
      File.readAllText(path);
      return true;
    } catch (e) {
    }
  }

  return false;
}

function makeAndroid16JavaBridgeStub() {
  const unavailable = () => {
    throw new Error('Android API 36 Java bridge is gated by this stability build; create /data/local/tmp/frida-enable-java-bridge to opt in');
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
