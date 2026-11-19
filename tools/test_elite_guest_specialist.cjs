// Usage: node tools/test_elite_guest_specialist.cjs <Godot executable> (or set GODOT_BIN).
const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '..');
const game = path.join(root, 'godot/game');
const script = path.join(game, 'scripts/_tmp_elite_guest_specialist.gd');
const scene = path.join(game, 'scenes/_tmp_elite_guest_specialist.tscn');
const log = path.join(game, '_tmp_elite_guest_specialist.log');
let result;
try {
  fs.copyFileSync(path.join(__dirname, 'elite_guest_specialist_check.gd'), script);
  fs.writeFileSync(scene, '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/_tmp_elite_guest_specialist.gd" id="1"]\n[node name="Check" type="Node"]\nscript = ExtResource("1")\n');
  result = spawnSync(process.argv[2] || process.env.GODOT_BIN || 'godot', ['--headless', '--path', game, '--log-file', log, 'res://scenes/_tmp_elite_guest_specialist.tscn'], {encoding:'utf8', timeout:40000});
  process.stdout.write(result.stdout || '');
  process.stderr.write(result.stderr || '');
  if (result.error) process.stderr.write(String(result.error));
} finally {
  for (const file of [script, scene, script+'.uid', log]) fs.rmSync(file, {force:true});
}
process.exit(result && result.status === 0 && result.stdout.includes('OK elite guest specialist') && !result.stderr.includes('SCRIPT ERROR') ? 0 : 1);
