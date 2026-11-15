from pathlib import Path
import json
import os
from lupa.lua53 import LuaRuntime

root = Path(__file__).resolve().parents[1]
os.chdir(root)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(f'package.path = {json.dumps((root / "driver/src/?.lua").as_posix() + ";")} .. package.path')
lua.execute((root / 'tests/test_driver.lua').read_text())
