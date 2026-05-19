# Florida

Follow [FRIDA](https://github.com/frida/frida) upstream to automatic patch and build an anti-detection version of frida-server for android.

跟随 FRIDA 上游自动修补程序，并为 Android 构建反检测版本的 frida-server。

**Hint: Don't fork this repository**

## Download

[Latest Release](https://github.com/Ylarod/Florida/releases/latest)

## Tooling

- `tools/post-process-florida.py`
  - 统一对最终产物执行后处理
  - 默认调用 patched `frida-core/src/anti-anti-frida.py`
  - 主要用于手工排查；CI 默认走 patched `frida-core/tools/post-process.py`
- `tools/verify-patch.py`
  - 校验 `release-assets/` 中产物是否仍包含关键 Frida 特征串
- `tools/scan-frida-signatures.py`
  - 对目录或单文件做特征串扫描，便于定位残留

### Verify

```bash
python3 tools/verify-patch.py release-assets
python3 tools/verify-patch.py release-assets --strict
```

### Scan

```bash
python3 tools/scan-frida-signatures.py release-assets --rules core
python3 tools/scan-frida-signatures.py release-assets --rules strict
```

## References

- [https://github.com/hluwa/Patchs](https://github.com/hluwa/Patchs)
- [https://github.com/feicong/strong-frida](https://github.com/feicong/strong-frida)
- [https://github.com/qtfreet00/AntiFrida](https://github.com/qtfreet00/AntiFrida)
- [https://t.zsxq.com/miIunQN](https://t.zsxq.com/miIunQN)
- [https://github.com/darvincisec/DetectFrida](https://github.com/darvincisec/DetectFrida)
- [https://github.com/b-mueller/frida-detection-demo](https://github.com/b-mueller/frida-detection-demo)

## Thanks

- [@hluwa](https://github.com/hluwa)
- [@feicong](https://github.com/feicong)
- [@r0ysue](https://github.com/r0ysue)
- [@hellodword](https://github.com/hellodword)
- [@qtfreet00](https://github.com/qtfreet00)
