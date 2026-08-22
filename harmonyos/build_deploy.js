/**
 * 构建 + 部署一键脚本
 * 用法: node build_deploy.js
 *
 * 环境要求:
 * - Mate 70 Pro 模拟器已启动（通过 DevEco Studio Device Manager）
 * - HDC 能检测到设备
 */

const { execSync } = require('child_process');
const path = require('path');

// === 配置 ===
const DEVECO_HOME = 'D:\\IDE\\devecostudio-windows-6.0.0.878\\DevEco Studio';
const SDK_DIR = `${DEVECO_HOME}\\sdk`;
const HVIGORW = `${DEVECO_HOME}\\tools\\hvigor\\bin\\hvigorw.bat`;
const HDC = `${SDK_DIR}\\default\\openharmony\\toolchains\\hdc.exe`;
const PROJECT_DIR = path.resolve(__dirname, 'harmonyos');
const HAP = path.resolve(PROJECT_DIR, 'entry/build/default/outputs/default/entry-default-unsigned.hap');
const BUNDLE = 'com.titaifenxi.app';

function run(cmd, desc) {
  try {
    const out = execSync(cmd, { timeout: 120000, shell: 'cmd.exe' });
    console.log(`[${desc}] OK`);
    return out.toString();
  } catch (e) {
    const msg = (e.stdout?.toString() || e.stderr?.toString() || e.message).trim();
    console.log(`[${desc}] ${msg.substring(0, 800)}`);
    return msg;
  }
}

function checkDevice() {
  const out = run(`"${HDC}" list targets`, '检测设备');
  if (!out || out.includes('Empty')) {
    console.log('\n❌ 未检测到模拟器，请先通过 DevEco Studio Device Manager 启动 Mate 70 Pro');
    return false;
  }
  console.log(`  设备: ${out.trim()}`);
  return true;
}

// === 主流程 ===
console.log('========================================');
console.log('  智能体态分析 - 构建部署');
console.log('========================================\n');

// 1. 检查设备
if (!checkDevice()) process.exit(1);

// 2. 构建
console.log('\n--- 1/4: 构建 HAP ---');
const buildCmd = `SET "DEVECO_SDK_HOME=${DEVECO_HOME}" && SET "OHOS_SDK_HOME=${SDK_DIR}" && "${HVIGORW}" assembleHap --no-daemon --mode module -p product=default -p module=entry`;
const buildOut = run(`cd /d "${PROJECT_DIR}" && ${buildCmd}`, '构建');
if (buildOut.includes('BUILD SUCCESSFUL')) {
  console.log('  ✅ 构建成功');
} else if (buildOut.includes('BUILD FAILED')) {
  console.log('  ❌ 构建失败');
  process.exit(1);
} else {
  // 可能输出太多，检查文件是否存在
  const fs = require('fs');
  if (fs.existsSync(HAP)) {
    console.log('  ✅ HAP 已生成');
  } else {
    console.log('  ❌ HAP 未生成，可能构建失败');
    process.exit(1);
  }
}

// 3. 卸载旧版
console.log('\n--- 2/4: 卸载旧版 ---');
run(`"${HDC}" uninstall ${BUNDLE}`, '卸载');

// 4. 安装
console.log('\n--- 3/4: 安装 HAP ---');
const installOut = run(`"${HDC}" install "${HAP}"`, '安装');
if (installOut.includes('install bundle successfully')) {
  console.log('  ✅ 安装成功');
} else if (installOut.includes('error:')) {
  console.log('  ❌ 安装失败');
  process.exit(1);
}

// 5. 启动
console.log('\n--- 4/4: 启动应用 ---');
run(`"${HDC}" shell "aa start -a EntryAbility -b ${BUNDLE}"`, '启动');

console.log('\n========================================');
console.log('  ✅ 部署完成！应用应在模拟器中启动');
console.log('========================================');
