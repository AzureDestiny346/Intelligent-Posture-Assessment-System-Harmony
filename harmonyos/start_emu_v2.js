const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const emu = 'D:/IDE/devecostudio-windows-6.0.0.878/DevEco Studio/tools/emulator/Emulator.exe';
const emuDir = 'D:/IDE/devecostudio-windows-6.0.0.878/DevEco Studio/tools/emulator';
const imageDir = 'D:/DevEcoEmulator/deployed/Mate 70 Pro';

console.log('Starting emulator from:', emuDir);
console.log('Image:', imageDir);

const child = spawn(emu, ['-image', imageDir], {
  cwd: emuDir,
  detached: true,
  stdio: 'ignore',
  windowsHide: false,
  env: {
    ...process.env,
    PATH: emuDir + ';' + (process.env.PATH || '')
  }
});

child.unref();
console.log('PID:', child.pid);
console.log('Waiting for boot...');
