# Ports and filenames

## Defaults

```text
Phone IP: 192.168.3.158
ADB endpoint: 192.168.3.158:5555
Remote binary: /data/local/tmp/app_process64
Remote log: /data/local/tmp/app_process64.log
Legacy override binary: /data/local/tmp/fs
Legacy override log: /data/local/tmp/fs.log
Control port: 28191
Cluster port: 28192
Local forwarded client endpoint: 127.0.0.1:28191
```

## Preferred names

Use system-style names for phone-visible process/file names by default:

```text
/data/local/tmp/app_process64
/data/local/tmp/app_process64.log
libbase-32.so
libbase-64.so
libbase-arm.so
libbase-arm64.so
```

Keep these substrings out of process/file/thread-visible names:

```text
frida gum gdbus gmain linjector agent
```

## Ports to avoid

```text
27042 27043 23946 12345 1234 31337
```

Hex encodings often seen in `/proc/net/tcp{,6}`:

```text
27042 = 69A2
27043 = 69A3
23946 = 5D8A
12345 = 3039
1234  = 04D2
31337 = 7A69
28191 = 6E1F
28192 = 6E20
```


## Legacy override

Use the old short name only for comparison runs:

```bash
SERIAL=<usb_serial> \
REMOTE_BIN=/data/local/tmp/fs \
REMOTE_LOG=/data/local/tmp/fs.log \
REMOTE_NAME=fs \
/Users/tbs/.codex/skills/frida/scripts/deploy_run_16719_phone.sh
```

## Client command pattern

```bash
adb connect 192.168.3.158:5555
adb forward tcp:28191 tcp:28191
$HOME/.local/bin/frida-ps -H 127.0.0.1:28191
```

For USB:

```bash
SERIAL=<usb_serial> /Users/tbs/.codex/skills/frida/scripts/deploy_run_16719_phone.sh
```
