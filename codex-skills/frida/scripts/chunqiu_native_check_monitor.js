// Spring-and-Autumn Native Check / com.chunqiunativecheck native monitor.
// Use with the local Florida 16.7.19 server:
//   PID=$(adb -s 5c8093e4 shell pidof com.chunqiunativecheck | tr -d '\r' | awk '{print $1}')
//   $HOME/.local/bin/frida -H 127.0.0.1:28191 -p "$PID" -l /Users/tbs/.codex/skills/frida/scripts/chunqiu_native_check_monitor.js -q --runtime=qjs --timeout 20

const keywords = [
  'frida', 'gum', 'gdbus', 'linjector', '27042', '27049', '28191', 're.frida',
  'zygisk', 'magisk', 'kitsune', 'ksu', 'xposed', 'substrate', 'riru', 'lsposed',
  'su', '/proc', 'maps', 'fd', 'task', 'status', 'tracerpid', 'memfd'
];
const seen = new Set();

function once(key, line) {
  if (seen.has(key))
    return;
  seen.add(key);
  console.log(line);
}

function readString(p, max = 512) {
  try {
    if (p.isNull())
      return '';
    return p.readUtf8String(max) || '';
  } catch (_) {
    return '';
  }
}

function hasKeyword(s) {
  const lower = (s || '').toLowerCase();
  return keywords.some(k => lower.indexOf(k) >= 0);
}

function moduleOffset(addr) {
  try {
    const m = Process.findModuleByAddress(addr);
    return m !== null ? `${m.name}+${addr.sub(m.base)}` : 'unknown';
  } catch (_) {
    return 'unknown';
  }
}

function hookExport(moduleName, exportName, makeCallbacks) {
  try {
    const p = Module.findExportByName(moduleName, exportName);
    if (p === null)
      return;
    Interceptor.attach(p, makeCallbacks(p));
    console.log(`[hook] ${moduleName || '*'}!${exportName} @ ${p}`);
  } catch (e) {
    console.log(`[hook-skip] ${exportName} ${e}`);
  }
}

console.log(`[monitor] start pid=${Process.id} arch=${Process.arch} java=${Java.available}`);
Process.enumerateModules().forEach(m => {
  if (m.name.indexOf('chunqiu') >= 0 || m.path.indexOf('/data/app/') >= 0)
    console.log(`[app-module] ${m.name} base=${m.base} size=${m.size} path=${m.path}`);
});

['open', 'open64'].forEach(name => hookExport('libc.so', name, () => ({
  onEnter(args) {
    const path = readString(args[0]);
    if (hasKeyword(path))
      once(`${name}:${path}`, `[${name}] ${path}`);
  }
})));

['openat', 'openat64', 'faccessat'].forEach(name => hookExport('libc.so', name, () => ({
  onEnter(args) {
    const path = readString(args[1]);
    if (hasKeyword(path))
      once(`${name}:${path}`, `[${name}] ${path}`);
  }
})));

['access', 'stat', 'stat64', 'lstat', 'lstat64'].forEach(name => hookExport('libc.so', name, () => ({
  onEnter(args) {
    const path = readString(args[0]);
    if (hasKeyword(path))
      once(`${name}:${path}`, `[${name}] ${path}`);
  }
})));

hookExport('libc.so', 'readlink', () => ({
  onEnter(args) {
    const path = readString(args[0]);
    if (hasKeyword(path))
      once(`readlink:${path}`, `[readlink] ${path}`);
  }
}));

hookExport('libc.so', 'readlinkat', () => ({
  onEnter(args) {
    const path = readString(args[1]);
    if (hasKeyword(path))
      once(`readlinkat:${path}`, `[readlinkat] ${path}`);
  }
}));

hookExport('libc.so', 'ptrace', () => ({
  onEnter(args) {
    console.log(`[ptrace] request=${args[0]} pid=${args[1]} caller=${moduleOffset(this.returnAddress)}`);
  }
}));

hookExport('libdl.so', 'android_dlopen_ext', () => ({
  onEnter(args) {
    const path = readString(args[0]);
    if (hasKeyword(path) || path.indexOf('.so') >= 0)
      console.log(`[dlopen_ext] ${path}`);
  }
}));

hookExport('libdl.so', 'dlopen', () => ({
  onEnter(args) {
    const path = readString(args[0]);
    if (hasKeyword(path) || path.indexOf('.so') >= 0)
      console.log(`[dlopen] ${path}`);
  }
}));

['strstr', 'strcasestr'].forEach(name => hookExport('libc.so', name, () => ({
  onEnter(args) {
    const haystack = readString(args[0], 256);
    const needle = readString(args[1], 128);
    if (hasKeyword(haystack) || hasKeyword(needle))
      once(`${name}:${haystack}:${needle}`, `[${name}] hay=${JSON.stringify(haystack)} needle=${JSON.stringify(needle)}`);
  }
})));

hookExport('libc.so', 'pthread_create', () => ({
  onEnter(args) {
    console.log(`[pthread_create] start=${args[2]} ${moduleOffset(args[2])}`);
  }
}));

const chunqiu = Process.findModuleByName('libchunqiunative.so');
if (chunqiu !== null) {
  const exports = [
    ['Java_com_chunqiunativecheck_Z_a', 0x744b0c],
    ['Java_com_chunqiunativecheck_Z_b', 0x744fa4]
  ];
  exports.forEach(([name, offset]) => {
    const target = Module.findExportByName('libchunqiunative.so', name) || chunqiu.base.add(offset);
    Interceptor.attach(target, {
      onEnter(args) {
        console.log(`[${name}] enter caller=${moduleOffset(this.returnAddress)} args=${args[0]},${args[1]},${args[2]},${args[3]}`);
      },
      onLeave(ret) {
        console.log(`[${name}] ret=${ret} s=${readString(ret, 256)}`);
      }
    });
  });
  console.log('[hook] libchunqiunative.so exports Z.a/Z.b');
}

setTimeout(() => console.log('[monitor] done'), 20000);
