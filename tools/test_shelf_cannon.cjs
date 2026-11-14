// Usage: node tools/test_shelf_cannon.cjs <Godot executable> (or set GODOT_BIN).
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const root = path.resolve(__dirname, '..');
const game = path.join(root, 'godot', 'game');
const script = path.join(game, 'scripts', '_tmp_shelf_cannon.gd');
const scene = path.join(game, 'scenes', '_tmp_shelf_cannon.tscn');
const log = path.join(game, '_tmp_shelf_cannon.log');
let result;
try {
  fs.copyFileSync(path.join(__dirname, 'shelf_cannon_check.gd'), script);
  fs.writeFileSync(scene, '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/_tmp_shelf_cannon.gd" id="1"]\n[node name="Check" type="Node"]\nscript = ExtResource("1")\n');
  result = spawnSync(process.argv[2] || process.env.GODOT_BIN || 'godot', ['--headless', '--path', game, '--log-file', log, 'res://scenes/_tmp_shelf_cannon.tscn'], {encoding: 'utf8', timeout: 40000});
  process.stdout.write(result.stdout || '');
  process.stderr.write(result.stderr || '');
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Godot exited with status ${result.status}; see ${log}`);
  const output = `${result.stdout || ''}\n${result.stderr || ''}\n${fs.existsSync(log) ? fs.readFileSync(log, 'utf8') : ''}`;
  if (!output.includes('OK shelf cannon')) throw new Error(`Test marker missing; see ${log}`);
} finally {
  for (const file of [script, scene, log]) {
    try { fs.unlinkSync(file); } catch {}
  }
}
