from pathlib import Path
import json
import os
import re
import unittest
from lupa.lua51 import LuaRuntime

ROOT=Path(__file__).resolve().parents[1]
LUA=ROOT/'Contents/mods/ZomputSurvivorSignal/42/media/lua'

class Tests(unittest.TestCase):
    def test_server_regressions(self):
        lua=LuaRuntime()
        lua.globals().arg=lua.table_from({1:str(LUA).replace('\\','/')})
        lua.execute((ROOT/'tests/server_spec.lua').read_text())

    def test_syntax(self):
        lua=LuaRuntime()
        for path in LUA.rglob('*.lua'):
            lua.execute('assert(loadstring(...))',path.read_text(encoding='utf-8'))

    def test_client_history(self):
        lua=LuaRuntime()
        lua.globals().arg=lua.table_from({1:str(LUA).replace('\\','/')})
        lua.execute((ROOT/'tests/client_spec.lua').read_text(encoding='utf-8'))

    def test_translations(self):
        for name in ('IG_UI.json','ItemName.json','Sandbox.json'):
            en,ko=[json.loads((LUA/'shared/Translate'/locale/name).read_text(encoding='utf-8')) for locale in ('EN','KO')]
            self.assertEqual(en.keys(),ko.keys())
            for key in en:
                self.assertEqual(re.findall(r'%[1-4]',en[key]),re.findall(r'%[1-4]',ko[key]))

if __name__=='__main__': unittest.main()
