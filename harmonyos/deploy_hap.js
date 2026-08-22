const { execSync } = require('child_process');
const path = require('path');

const hdc = 'D:\\IDE\\devecostudio-windows-6.0.0.878\\DevEco Studio\\sdk\\default\\openharmony\\toolchains\\hdc.exe';
const hap = path.resolve(__dirname, 'harmonyos/entry/build/default/outputs/default/entry-default-unsigned.hap');

function run(cmd, desc) {
  try {
    const out = execSync(cmd, { timeout: 20000, shell: 'cmd.exe' });
    console.log(`[${desc}] OK:`, out.toString().trim() || '(empty)');
  } catch (e) {
    console.log(`[${desc}] ERR:`, (e.stdout?.toString() || e.stderr?.toString() || e.message).trim().substring(0, 500));
  }
}

run(`"${hdc}" uninstall com.titaifenxi.app`, '卸载');
run(`"${hdc}" install "${hap}"`, '安装');
run(`"${hdc}" shell "aa start -a EntryAbility -b com.titaifenxi.app"`, '启动');
