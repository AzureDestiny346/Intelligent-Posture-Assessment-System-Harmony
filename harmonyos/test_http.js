const { execSync } = require('child_process');

const hdc = 'D:\\IDE\\devecostudio-windows-6.0.0.878\\DevEco Studio\\sdk\\default\\openharmony\\toolchains\\hdc.exe';

// Use a simple HTTP request via /proc/net or socket test
// Actually let's use the app's bundled wget alternative
try {
  // Test if we can make a raw TCP connection to 10.0.2.2:5000
  const script = `
import socket
import sys
try:
  s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
  s.settimeout(3)
  s.connect(('10.0.2.2', 5000))
  s.send(b'GET /health HTTP/1.0\\r\\nHost: 10.0.2.2\\r\\n\\r\\n')
  print(s.recv(4096).decode())
  s.close()
except Exception as e:
  print(f'FAIL: {e}')
`;
  const b64 = Buffer.from(script).toString('base64');
  const out = execSync(`"${hdc}" shell "echo ${b64} | base64 -d | python3"`, { timeout: 10000 });
  console.log('Result:', out.toString());
} catch (e) {
  console.error('Error:', e.message);
  // try python instead of python3
  try {
    const script = `
import socket
try:
  s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
  s.settimeout(3)
  s.connect(('10.0.2.2', 5000))
  s.send(b'GET /health HTTP/1.0\\r\\nHost: 10.0.2.2\\r\\n\\r\\n')
  print(s.recv(4096).decode())
  s.close()
except Exception as ex:
  print(f'FAIL: {ex}')
`;
    const b64 = Buffer.from(script).toString('base64');
    const out2 = execSync(`"${hdc}" shell "echo ${b64} | base64 -d | python"`, { timeout: 10000 });
    console.log('Result via python:', out2.toString());
  } catch(e2) {
    console.error('Both failed:', e2.message);
  }
}
