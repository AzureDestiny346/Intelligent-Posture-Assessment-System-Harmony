const { execSync, spawn } = require('child_process');

// Use Node's path.resolve to handle the path correctly
const emu = 'D:/IDE/devecostudio-windows-6.0.0.878/DevEco Studio/tools/emulator/Emulator.exe';

console.log('Emulator path:', emu);
console.log('File exists test:');

const fs = require('fs');
console.log('Exists:', fs.existsSync(emu));

// Also check the deployed emulator config
const listsJson = 'D:/DevEcoEmulator/deployed/lists.json';
console.log('Lists JSON exists:', fs.existsSync(listsJson));
if (fs.existsSync(listsJson)) {
  try {
    const data = JSON.parse(fs.readFileSync(listsJson, 'utf8'));
    console.log(JSON.stringify(data, null, 2).substring(0, 300));
  } catch(e) {
    console.log('Parse error:', e.message);
    console.log('Raw:', fs.readFileSync(listsJson, 'utf8').substring(0, 500));
  }
}
