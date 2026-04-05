@echo off
cd /d "%~dp0"
python -m sqlite_utils query RainOfBricks_ItemDB.db "SELECT * FROM view_items" --json-cols > items.json
echo.
echo items.json 내보내기 완료!
pause
