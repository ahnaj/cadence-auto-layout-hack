# SPDX-License-Identifier: MIT
from pathlib import Path
import unittest


class SkillSyntaxTests(unittest.TestCase):
    def test_balanced_skill_delimiters(self):
        root = Path(__file__).resolve().parents[1]
        for directory in ("skill", "tests", "examples"):
            for path in (root / directory).glob("*.il"):
                stack = []
                string = comment = escape = False
                for c in path.read_text():
                    if c == "\n":
                        comment = False
                    if comment:
                        continue
                    if string:
                        if escape:
                            escape = False
                        elif c == "\\":
                            escape = True
                        elif c == '"':
                            string = False
                        continue
                    if c == ";":
                        comment = True
                    elif c == '"':
                        string = True
                    elif c in "([":
                        stack.append(c)
                    elif c in ")]":
                        self.assertTrue(stack, str(path))
                        self.assertEqual(stack.pop(), "(" if c == ")" else "[", str(path))
                self.assertFalse(string, str(path))
                self.assertEqual(stack, [], str(path))
