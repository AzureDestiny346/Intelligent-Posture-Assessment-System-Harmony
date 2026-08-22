const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const emu = 'D:/IDE/devecostudio-windows-6.0.0.878/DevEco Studio/tools/emulator/Emulator.exe';
const deployedDir = 'D:/DevEcoEmulator/deployed/Mate 70 Pro';

console.log('Launching emulator...');
console.log('Emulator:', emu);
console.log('Image:', deployedDir);

const child = spawn(emu, ['-image', deployedDir], {
  detached: true,
  stdio: 'ignore',
  windowsHide: false
});

child.unref();
console.log('Launched with PID:', child.pid);
console.log('Wait ~30s for boot...');
