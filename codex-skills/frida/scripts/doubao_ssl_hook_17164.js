'use strict';

/*
 * Doubao (com.larus.nova) TLS verification monitor/override for Frida 17.16.4.
 *
 * Example:
 *   frida -H 127.0.0.1:28191 -f com.larus.nova -l doubao_ssl_hook_17164.js
 *
 * Start with -f so module-load hooks are installed before Cronet/BoringSSL.
 * Cronet verifier returns are recorded only because this export does not
 * expose a simple boolean result.
 */

const TAG = '[dy39-ssl]';
const TARGET_MODULES = ['libttboringssl.so', 'libttcrypto.so', 'libsscronet.so'];
const hookedTargets = new Set();
const hookedCallbacks = new Set();
let dlopenHookInstalled = false;

function log(message) {
  console.log(`${TAG} ${message}`);
}

function getExport(module, name) {
  try {
    return module.getExportByName(name);
  } catch (_) {
    try {
      return Module.getExportByName(module.name, name);
    } catch (__) {
      return null;
    }
  }
}

function hookExport(module, name, callbacks) {
  const target = getExport(module, name);
  if (target === null) return;

  const key = target.toString();
  if (hookedTargets.has(key)) {
    log(`skip alias ${module.name}!${name} @ ${target}`);
    return;
  }

  hookedTargets.add(key);
  log(`hook ${module.name}!${name} @ ${target}`);
  Interceptor.attach(target, callbacks);
}

function hookVerifyCallback(callback) {
  if (callback.isNull()) return;

  const key = callback.toString();
  if (hookedCallbacks.has(key)) return;

  hookedCallbacks.add(key);
  log(`hook verify callback @ ${callback}`);
  Interceptor.attach(callback, {
    onLeave(retval) {
      const before = retval.toInt32();
      if (before !== 0) {
        retval.replace(0);
        log(`verify callback ret=${before} -> 0`);
      } else {
        log('verify callback ret=0 (already ok)');
      }
    },
  });
}

function hookSslModule(module) {
  hookExport(module, 'SSL_CTX_set_custom_verify', {
    onEnter(args) {
      log(`${module.name} SSL_CTX_set_custom_verify mode=${args[1]} cb=${args[2]}`);
      hookVerifyCallback(args[2]);
    },
  });
  hookExport(module, 'SSL_set_custom_verify', {
    onEnter(args) {
      log(`${module.name} SSL_set_custom_verify mode=${args[1]} cb=${args[2]}`);
      hookVerifyCallback(args[2]);
    },
  });
  hookExport(module, 'X509_verify_cert', {
    onLeave(retval) {
      const before = retval.toInt32();
      if (before !== 1) {
        retval.replace(1);
        log(`${module.name} X509_verify_cert ${before} -> 1`);
      } else {
        log(`${module.name} X509_verify_cert ret=1 (already valid)`);
      }
    },
  });
}

function hookModule(name) {
  const module = Process.findModuleByName(name);
  if (module === null) return;

  hookSslModule(module);
  if (name === 'libsscronet.so') {
    hookExport(module, 'Cronet_CertVerify_DoVerifyV2', {
      onEnter() {
        log(`${module.name} Cronet_CertVerify_DoVerifyV2 enter`);
      },
      onLeave(retval) {
        log(`${module.name} Cronet_CertVerify_DoVerifyV2 ret=${retval}`);
      },
    });
  }
}

function hookModuleLoads() {
  if (dlopenHookInstalled) return;

  let dlopen = null;
  try {
    dlopen = Module.findGlobalExportByName('android_dlopen_ext') ||
      Module.findGlobalExportByName('dlopen');
  } catch (_) {
    try {
      dlopen = Module.getExportByName(null, 'dlopen');
    } catch (__) {
      dlopen = null;
    }
  }

  if (dlopen === null) {
    log('dlopen export not found; only currently loaded modules were hooked');
    return;
  }

  dlopenHookInstalled = true;
  Interceptor.attach(dlopen, {
    onEnter(args) {
      this.path = args[0].isNull() ? '' : args[0].readCString();
    },
    onLeave() {
      for (const name of TARGET_MODULES) {
        if (this.path.indexOf(name) !== -1) hookModule(name);
      }
    },
  });
}

for (const name of TARGET_MODULES) hookModule(name);
hookModuleLoads();
log('install done');
