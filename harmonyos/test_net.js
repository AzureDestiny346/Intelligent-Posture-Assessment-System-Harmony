const { execSync } = require('child_process');
const hdc = 'D:\\IDE\\devecostudio-windows-6.0.0.878\\DevEco Studio\\sdk\\default\\openharmony\\toolchains\\hdc.exe';

try {
  const out = execSync(`"${hdc}" shell "ls /system/bin/ | grep -E 'telnet|nc|soc|socket|busy|sh|bash|wget|curl|http|ping'"`, { timeout: 5000 });
  console.log('Network tools:', out.toString());
} catch(e) {
  console.log('No specific network tools found');
}

// Try ping
try {
  const out = execSync(`"${hdc}" shell "ping -c 1 -W 2 10.0.2.2 2>&1"`, { timeout: 8000 });
  console.log('Ping result:', out.toString());
} catch(e) {
  console.log('Ping failed:', e.message.slice(0, 200));
}

// Check firewall rules on emulator
try {
  const out = execSync(`"${hdc}" shell "cat /proc/sys/net/ipv4/ip_forward 2>/dev/null; cat /proc/net/tcp 2>/dev/null | head -5"`, { timeout: 5000 });
  console.log('Net config:', out.toString());
} catch(e) {
  console.log('Net config check failed');
}
