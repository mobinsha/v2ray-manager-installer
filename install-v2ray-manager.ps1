# =============================
# V2Ray Manager Installer – Windows
# =============================
$ErrorActionPreference = "Stop"

$BASE = "C:\v2ray-manager"
$V2RAY_DIR = "$BASE\v2ray"
$CONFIG_DIR = "$BASE\configs"
$PUBLIC_DIR = "$BASE\public"

Write-Host "=== V2Ray Manager Installer (Node.js / Windows) ==="

# --- Install Node.js if missing ---
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Node.js..."
    $nodeUrl = "https://nodejs.org/dist/v20.11.1/node-v20.11.1-x64.msi"
    $nodeInstaller = "$env:TEMP\node.msi"
    Invoke-WebRequest $nodeUrl -OutFile $nodeInstaller
    Start-Process msiexec.exe -ArgumentList "/i $nodeInstaller /quiet /norestart" -Wait
}

# --- Create directories ---
Write-Host "Creating folders..."
New-Item -ItemType Directory -Force -Path $V2RAY_DIR, $CONFIG_DIR, $PUBLIC_DIR | Out-Null
Set-Location $BASE

# --- Download V2Ray ---
Write-Host "Downloading V2Ray..."
$v2rayZip = "$env:TEMP\v2ray.zip"
Invoke-WebRequest "https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-windows-64.zip" -OutFile $v2rayZip
Expand-Archive $v2rayZip -DestinationPath $V2RAY_DIR -Force

# --- package.json ---
@"
{
  "name": "v2ray-manager",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  }
}
"@ | Out-File "$BASE\package.json" -Encoding utf8

# --- server.js ---
@"
const express = require('express');
const fs = require('fs');
const { spawn } = require('child_process');
const { v4: uuidv4 } = require('uuid');

const app = express();
const PORT = 3000;

const V2RAY = './v2ray/v2ray.exe';
const CONFIGS = './configs';
let processRef = null;

app.use(express.json());
app.use(express.static('public'));

app.post('/config/vmess', (req, res) => {
  const { port } = req.body;
  const uuid = uuidv4();
  const config = {
    inbounds: [{
      port: Number(port),
      protocol: 'vmess',
      settings: { clients: [{ id: uuid, alterId: 0 }] }
    }],
    outbounds: [{ protocol: 'freedom' }]
  };
  fs.writeFileSync(`${CONFIGS}/vmess-${port}.json`, JSON.stringify(config, null, 2));
  res.json({ port, uuid });
});

app.get('/configs', (req, res) => {
  res.json(fs.readdirSync(CONFIGS));
});

app.post('/start', (req, res) => {
  if (processRef) return res.json({ error: 'Already running' });
  processRef = spawn(V2RAY, ['-config', `${CONFIGS}/${req.body.config}`]);
  res.json({ success: true });
});

app.post('/stop', (req, res) => {
  if (processRef) processRef.kill();
  processRef = null;
  res.json({ success: true });
});

app.listen(PORT, () => console.log('Panel: http://localhost:' + PORT));
"@ | Out-File "$BASE\server.js" -Encoding utf8

# --- index.html ---
@"
<!DOCTYPE html>
<html lang='fa' dir='rtl'>
<head>
<meta charset='UTF-8'>
<title>V2Ray Manager</title>
</head>
<body>

<h2>ساخت کانفیگ VMESS</h2>
<input id='port' placeholder='پورت'>
<button onclick='create()'>ساخت</button>

<hr>

<h2>لیست کانفیگ‌ها</h2>
<ul id='list'></ul>
<button onclick='load()'>بارگذاری</button>

<script>
async function create() {
  const port = document.getElementById('port').value;
  const res = await fetch('/config/vmess',{
    method:'POST',
    headers:{'Content-Type':'application/json'},
    body:JSON.stringify({ port })
  });
  alert(JSON.stringify(await res.json()));
}
async function load() {
  const res = await fetch('/configs');
  document.getElementById('list').innerHTML =
    (await res.json()).map(x=>'<li>'+x+'</li>').join('');
}
</script>

</body>
</html>
"@ | Out-File "$PUBLIC_DIR\index.html" -Encoding utf8

# --- Install npm packages ---
Write-Host "Installing npm packages..."
npm install express uuid

# --- Start server ---
Write-Host "Starting server..."
Start-Process node -ArgumentList "server.js"

Write-Host "DONE ✅"
Write-Host "Open: http://localhost:3000"
