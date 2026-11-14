# SPDX-License-Identifier: MIT
import importlib.util
import math
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("autolayout", Path(__file__).resolve().parents[1] / "scripts/autolayout.py")
al = importlib.util.module_from_spec(spec)
spec.loader.exec_module(al)


class OrchestrationTests(unittest.TestCase):
    def test_skill_escaping(self):
        self.assertEqual(al.skill('a"b\\c'), '"a\\"b\\\\c"')
        self.assertEqual(al.skill({"x": [1, None, True]}), '(("x" (1 nil t)))')
        for val in ("in\njected", "\u2603", float("nan")):
            with self.assertRaises(ValueError):
                al.skill(val)

    def test_verification_requires_native_completion_and_sizes(self):
        # Parser fixtures, never benchmark evidence.
        console = "AL_DRC markers=0\nAL_EXTRACT instances=2 terminals=4\n"
        lvs = "The net-lists match.\n        size errors 0 0\n"
        result = al.parse_verification(console, lvs, 0)
        self.assertEqual(result["drc"], "passed")
        self.assertEqual(result["lvs"], "passed")
        self.assertNotEqual(al.parse_verification(console, lvs, 1)["lvs"], "passed")
        self.assertNotEqual(al.parse_verification(console, "The net-lists match.", 0)["lvs"], "passed")
        self.assertEqual(al.parse_verification(console, lvs.replace("errors 0", "errors 1"), 0)["lvs"], "failed")
        self.assertEqual(al.parse_verification(console.replace("markers=0", "markers=3"), lvs, 0)["drc"], "failed")

    def test_missing_evidence_is_unavailable(self):
        self.assertEqual(al.parse_verification("", "", 0)["drc"], "unavailable")
        self.assertEqual(al.parse_verification("", "", 0)["lvs"], "unavailable")

    def test_tool_error_invalidates_pass(self):
        result = al.parse_verification("AL_DRC markers=0\n*Error* native failure", "The net-lists match.\nsize errors 0 0", 0)
        self.assertNotEqual(result["drc"], "passed")
        self.assertNotEqual(result["lvs"], "passed")

    def test_expansion_and_relative_adapter(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "adapter.json").write_text('{"x":1, "technology_library":"T"}')
            (root / "local.json").write_text('{"adapter_file":"adapter.json","x":2}')
            self.assertEqual(al.read_config(root / "local.json"), {"x": 2, "technology_library": "T"})

    def test_unique_runs_never_reuse_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertNotEqual(al.unique_root(directory), al.unique_root(directory))

    def test_no_pdks_or_database_files_in_public_tree(self):
        root = Path(__file__).resolve().parents[1]
        for path in root.rglob("*"):
            if ".local" in path.parts or ".git" in path.parts:
                continue
            self.assertNotIn(path.suffix, (".oa", ".rul", ".cdslck", ".pem"))

    def test_source_alias_and_path_escape_are_rejected(self):
        import argparse
        config = al.read_config(Path(__file__).resolve().parents[1] / "config/tech/ncsu_tsmc03.example.json")
        for name in ("SOURCE", "../outside"):
            args = argparse.Namespace(source_lib="SOURCE", output_lib=name, dry_run=True)
            with self.assertRaises(ValueError):
                al.generate(args, config)

    def test_actual_measurement_overrides_candidate_estimate(self):
        with tempfile.TemporaryDirectory() as directory:
            result = al.describe(Path(directory), 0,
                "AL_GENERATED\nAL_CANDIDATE width=1 height=1 area=1\nAL_MEASURED width=2 height=3 area=6\n")
            self.assertEqual(result["area_um2"], 6)
            unsupported = al.describe(Path(directory), 1, "*Error* Hierarchy is not yet supported")
            self.assertEqual(unsupported["generation"], "unsupported")

    @unittest.skipUnless(__import__("os").name == "posix", "Linux batch execution")
    def test_batch_timeout_terminates_process_group(self):
        import sys
        with tempfile.TemporaryDirectory() as directory:
            with (Path(directory) / "console.log").open("w") as output:
                status = al.execute([sys.executable, "-c", "import time; time.sleep(30)"],
                                    directory, output, 0.1)
            self.assertEqual(status, 124)

    def test_documentation_links_resolve(self):
        import re
        root = Path(__file__).resolve().parents[1]
        for path in [root / "README.md"] + list((root / "docs").glob("*.md")):
            for target in re.findall(r"\]\(([^)]+)\)", path.read_text()):
                target = target.split("#", 1)[0]
                if target and not target.startswith(("https:", "http:", "mailto:")):
                    self.assertTrue((path.parent / target).is_file(), str(path) + ": " + target)

    def test_seed_validation_and_candidate_sequence(self):
        for value in (-1, al.MAX_SEED + 1, True, 2.5):
            with self.assertRaises(ValueError):
                al.check_seed(value)
        self.assertEqual(al.candidate_seeds(17, 0, 2), (0, 19))
        self.assertEqual(al.candidate_seeds(0, None, 2), (2, 0))
        self.assertEqual(al.candidate_seeds(al.MAX_SEED, 5, 1), (5, 1))

    def test_fingerprint_is_order_independent_and_detects_changes(self):
        with tempfile.TemporaryDirectory() as directory:
            p = Path(directory) / "routing.txt"
            p.write_text("FIG B 1 2\nFIG A 3 4\n")
            first = al.fingerprint(p)
            p.write_text("FIG A 3 4\nFIG B 1 2\n")
            self.assertEqual(first, al.fingerprint(p))
            p.write_text("FIG A 3 5\nFIG B 1 2\n")
            self.assertNotEqual(first, al.fingerprint(p))


if __name__ == "__main__":
    unittest.main()
