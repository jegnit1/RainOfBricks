@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo [1/5] Exporting items.json...
python -m sqlite_utils query RainOfBricks_ItemDB.db "SELECT * FROM view_items" --json-cols > items.json

echo [2/5] Exporting player_base.json...
python -m sqlite_utils query RainOfBricks_ItemDB.db "SELECT key, value FROM view_player_base" > data\player_base.json

echo [3/5] Exporting wall_blocks.json...
python -m sqlite_utils query RainOfBricks_ItemDB.db "SELECT * FROM view_wall_blocks" --json-cols > data\wall_blocks.json

echo [4/5] Exporting robots.json...
python -m sqlite_utils query RainOfBricks_ItemDB.db "SELECT * FROM view_robots" > data\robots_raw.json
python -c "import json; d=json.load(open('data/robots_raw.json')); [r.update({'can_enter_tunnel': r['can_enter_tunnel']=='true'}) for r in d]; json.dump({'robots': d}, open('data/robots.json','w',encoding='utf-8'), ensure_ascii=False, indent=2)"
del data\robots_raw.json

echo [5/5] Exporting stages.json...
python -m sqlite_utils query RainOfBricks_ItemDB.db "SELECT * FROM view_stages" > data\stages_raw.json
python -c "import json; d=json.load(open('data/stages_raw.json')); json.dump({'stages': d}, open('data/stages.json','w',encoding='utf-8'), ensure_ascii=False, indent=2)"
del data\stages_raw.json

echo.
echo === Export Complete! ===
pause
