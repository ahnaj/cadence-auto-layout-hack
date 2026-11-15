#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Thin, standard-library orchestration for the native SKILL engine."""
import argparse
import datetime
import hashlib
import json
import math
import os
from pathlib import Path
import re
import secrets
import shutil
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]


def skill(value):
    if value is None or value is False:
        return "nil"
    if value is True:
        return "t"
    if isinstance(value, str):
        if any(ord(c) < 32 or ord(c) > 126 for c in value):
            raise ValueError("Use printable ASCII configuration strings")
        return json.dumps(value)
    if isinstance(value, (float, int)):
        if not math.isfinite(value):
            raise ValueError("Nonfinite configuration number")
        return str(value)
    if isinstance(value, dict):
        return "(" + " ".join("(" + skill(k) + " " + skill(v) + ")" for k, v in sorted(value.items())) + ")"
    if isinstance(value, list):
        return "(" + " ".join(skill(v) for v in value) + ")"
    raise ValueError("Unsupported configuration value")


def expand(value):
    if isinstance(value, str):
        return os.path.expanduser(os.path.expandvars(value))
    if isinstance(value, dict):
        return {k: expand(v) for k, v in value.items()}
    if isinstance(value, list):
        return [expand(v) for v in value]
    return value


def read_config(path):
    data = json.loads(Path(path).read_text())
    if not isinstance(data, dict):
        raise ValueError("Configuration must be a JSON object")
    adapter = data.pop("adapter_file", None)
    if adapter:
        adapter_path = Path(path).resolve().parent / adapter
        base = json.loads(adapter_path.read_text())
        base.update(data)
        data = base
    return expand(data)


def validate(config, physical=True):
    for key in ("technology_library", "devices", "routing_layers", "routing_vias",
                "poly_layer", "well_layer", "gate_contact", "substrate_tie", "well_tie"):
        if not config.get(key):
            raise ValueError("Missing adapter setting: " + key)
    if set(d.get("kind") for d in config["devices"]) != {"pmos", "nmos"}:
        raise ValueError("Configure both NMOS and PMOS")
    for device in config["devices"]:
        for key in ("source_lib", "source_cell", "width_param", "length_param",
                    "layout_lib", "layout_cell", "layout_width_param",
                    "layout_length_param", "active_layer"):
            if not device.get(key):
                raise ValueError("Missing device mapping: " + key)
    if physical:
        for key in ("rail_width", "layout_margin", "well_margin", "tie_reserve", "diffusion_break"):
            val = config.get(key)
            if isinstance(val, bool) or not isinstance(val, (float, int)) or val <= 0:
                raise ValueError("Set positive " + key + " from your installed technology")
        for key in ("drc_rules", "extraction_rules", "lvs_rules"):
            if not Path(config.get(key, "")).is_file():
                raise ValueError("Missing installed rule deck: " + key)
    skill(config)


def execute(command, cwd, output, timeout):
    process = subprocess.Popen(command, cwd=str(cwd), stdin=subprocess.DEVNULL,
                               stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
    try:
        return process.wait(timeout=timeout)
    except (subprocess.TimeoutExpired, KeyboardInterrupt) as exc:
        # Cancel only this batch process group, including its wrapper children.
        os.killpg(process.pid, signal.SIGTERM)
        time.sleep(2)
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait()
        if isinstance(exc, KeyboardInterrupt):
            raise
        return 124


def native(config, cds, run, code, timeout):
    exe = shutil.which(config.get("virtuoso", "virtuoso"))
    if not exe:
        raise ValueError("Virtuoso unavailable; source your licensed Cadence environment")
    if not Path(cds).is_file():
        raise ValueError("cds.lib does not exist")
    run.mkdir(parents=True, exist_ok=False)
    engine = run / "engine"
    shutil.copytree(str(ROOT / "skill"), str(engine / "skill"))
    script = run / "run.il"
    startup = config.get("startup_file")
    if startup and not Path(startup).is_file():
        raise ValueError("Configured Cadence startup file does not exist")
    script.write_text(
        ("load(" + skill(startup) + ")\n" if startup else "") +
        "ALroot=" + skill(str(engine)) + "\nload(strcat(ALroot \"/skill/load.il\"))\n"
        + "ALconfig='" + skill(config) + "\n"
        + "if(errset(progn(" + code + ") t) then exit(0) else exit(1))\n")
    command = [exe, "-nograph", "-cdslib", str(Path(cds).resolve()),
               "-log", str(run / "virtuoso.log"), "-restore", str(script)]
    started = time.time()
    with (run / "console.log").open("w") as output:
        status = execute(command, Path(cds).resolve().parent, output, timeout)
    (run / "execution.json").write_text(json.dumps({
        "returncode": status, "elapsed_seconds": time.time() - started,
        "python": sys.version, "command": command,
        "engine_sha256": {str(p.relative_to(engine)): hashlib.sha256(p.read_bytes()).hexdigest()
                          for p in (engine / "skill").glob("*.il")}}, indent=2))
    return status, (run / "console.log").read_text(errors="replace")


def parse_verification(console, lvs, returncode):
    counts = re.findall(r"^AL_DRC markers=(\d+)\s*$", console, re.M)
    size = re.search(r"^\s*size errors\s+(\d+)\s+(\d+)\s*$", lvs, re.M)
    matched = "The net-lists match." in lvs and size and not any(int(n) for n in size.groups())
    errors = "*Error*" in console or bool(re.search(r"^\s*(FATAL|ERROR)\b", lvs, re.M))
    return {
        "drc": ("passed" if int(counts[-1]) == 0 else "failed") if counts and returncode == 0 and not errors else "unavailable",
        "drc_violations": int(counts[-1]) if counts else None,
        "extraction": "completed" if "AL_EXTRACT " in console and returncode == 0 and not errors else "unavailable",
        "lvs": "passed" if matched and returncode == 0 and not errors else ("failed" if lvs else "unavailable"),
    }


def describe(run, status, console):
    lvs_path = run / "lvs/si.out"
    lvs = lvs_path.read_text(errors="replace") if lvs_path.is_file() else ""
    result = parse_verification(console, lvs, status)
    result["generation"] = "generated" if "AL_GENERATED" in console and status == 0 else "failed"
    if re.search(r"\*Error\*.*(?:unsupported|not yet supported)", console, re.I):
        result["generation"] = "unsupported"
    dims = re.search(r"AL_CANDIDATE width=([\d.e+-]+) height=([\d.e+-]+) area=([\d.e+-]+)", console)
    measured = re.search(r"AL_MEASURED width=([\d.e+-]+) height=([\d.e+-]+) area=([\d.e+-]+)", console)
    dims = measured or dims
    if dims:
        result.update(zip(("width_um", "height_um", "area_um2"), map(float, dims.groups())))
    result["logs"] = str(run)
    result["log_sha256"] = hashlib.sha256(console.encode()).hexdigest()
    return result


def unique_root(base):
    stamp = datetime.datetime.utcnow().strftime("%Y%m%dT%H%M%S%f")
    path = Path(base).resolve() / stamp
    path.mkdir(parents=True, exist_ok=False)
    return path


def doctor(args, config):
    validate(config, physical=False)
    checks = {"virtuoso": shutil.which(config.get("virtuoso", "virtuoso")),
              "cds_lib": Path(args.cds_lib).is_file(),
              "CDK_DIR": os.environ.get("CDK_DIR"),
              "decks": {k: Path(config.get(k, "")).is_file()
                        for k in ("drc_rules", "extraction_rules", "lvs_rules")}}
    print(json.dumps(checks, indent=2))
    if not checks["virtuoso"] or not checks["cds_lib"] or not all(checks["decks"].values()):
        return 1
    run = unique_root(args.work_dir) / "doctor"
    code = """unless(ddGetObj(alCfg("technology_library")) error("Technology library not registered"))
foreach(d alCfg("devices")
 unless(ddGetObj(alVal(d "source_lib") alVal(d "source_cell") "symbol") error("Source device missing"))
 unless(ddGetObj(alVal(d "layout_lib") alVal(d "layout_cell") "layout") error("Physical PCell missing")))
printf("AL_DOCTOR_OK\\n")
"""
    status, log = native(config, args.cds_lib, run, code, args.timeout)
    print("Native checks:", "passed" if status == 0 and "AL_DOCTOR_OK" in log else "failed", run)
    return status or (0 if "AL_DOCTOR_OK" in log else 1)


MAX_SEED = 2147483646


def check_seed(value):
    if value is not None and (type(value) is not int or not 0 <= value <= MAX_SEED):
        raise ValueError("Seeds must be integers between 0 and " + str(MAX_SEED))
    return value


def candidate_seeds(base, placement, index):
    check_seed(base)
    check_seed(placement)
    return (index if placement is None else placement,
            0 if base == 0 else 1 + (base - 1 + index) % MAX_SEED)


def fingerprint(path):
    if not path.is_file():
        return None
    records = sorted(path.read_text().splitlines())
    return hashlib.sha256(("\n".join(records) + "\n").encode()).hexdigest()


def routing_cost(log):
    match = re.search(r"AL_ROUTE_COST wire_um=([0-9.]+) vias=(\d+) bends=(\d+)", log)
    if not match:
        return {}
    return {"routed_wire_um": float(match.group(1)),
            "routed_vias": int(match.group(2)), "routed_bends": int(match.group(3))}


def candidate_rank(result):
    return (result["area_um2"], result.get("routed_wire_um", float("inf")),
            result.get("routed_vias", float("inf")),
            result.get("routed_bends", float("inf")))


def generate(args, config):
    validate(config, physical=not args.dry_run)
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", args.output_lib):
        raise ValueError("Output library name must be an ASCII identifier")
    if args.source_lib == args.output_lib:
        raise ValueError("Source and output libraries must differ")
    if args.iterations < 1 or args.iterations > 64:
        raise ValueError("iterations must be between 1 and 64")
    base_seed = check_seed(getattr(args, "seed", None))
    if base_seed is None:
        base_seed = secrets.randbelow(MAX_SEED) + 1
    fixed_placement = check_seed(getattr(args, "placement_seed", None))
    root = unique_root(args.work_dir)
    cds = root / "cds.lib"
    cds.write_text("INCLUDE " + json.dumps(str(Path(args.cds_lib).resolve())) + "\n")
    results = []
    for index in range(1 if args.dry_run else args.iterations):
        outlib = args.output_lib if args.iterations == 1 else args.output_lib + "_c%02d" % index
        placement_seed, routing_seed = candidate_seeds(base_seed, fixed_placement, index)
        output = root / outlib
        height = args.height
        if args.optimize == "area" and config.get("candidate_heights"):
            height = config["candidate_heights"][index % len(config["candidate_heights"])]
        if height is not None and (not isinstance(height, (float, int)) or height <= 0):
            raise ValueError("Height must be positive")
        run = root / ("candidate_%02d" % index)
        code = "alGenerate(%s %s %s %s %s %d %s %s)\n" % (
            skill(args.source_lib), skill(args.cell), skill(args.view), skill(outlib),
            skill(str(output)), placement_seed, skill(height), skill(args.dry_run))
        if not args.dry_run:
            code += "alVerify(%s %s %s %s %s %s)\n" % (
                skill(outlib), skill(args.cell), skill(args.source_lib), skill(args.cell),
                skill(args.view), skill(str(run)))
        run_config = dict(config, routing_seed=routing_seed,
                          geometry_manifest=str(run / "geometry.txt"),
                          routing_manifest=str(run / "routing.txt"))
        status, log = native(run_config, cds, run, code, args.timeout)
        result = describe(run, status, log)
        result.update(routing_cost(log))
        result.update({"library": outlib, "cell": args.cell, "source_lib": args.source_lib,
                       "source_view": args.view, "candidate": index, "cds_lib": str(cds),
                       "base_seed": base_seed, "placement_seed": placement_seed, "routing_seed": routing_seed,
                       "geometry_sha256": fingerprint(run / "geometry.txt"),
                       "routing_sha256": fingerprint(run / "routing.txt")})
        if args.dry_run:
            if status == 0 and "AL_DRY_RUN" in log:
                result["generation"] = "dry_run"
        (run / "result.json").write_text(json.dumps(result, indent=2))
        results.append(result)
        print(json.dumps(result, indent=2))
    passed = [r for r in results if r["generation"] == "generated" and
              r["drc"] == "passed" and r["lvs"] == "passed" and r["extraction"] == "completed"]
    summary = {"candidates": results, "best_verified": min(passed, key=candidate_rank) if passed else None}
    summary["base_seed"] = base_seed
    summary["equal_area_verified"] = [r for r in passed
        if r["area_um2"] == summary["best_verified"]["area_um2"]] if passed else []
    (root / "summary.json").write_text(json.dumps(summary, indent=2))
    print("Results:", root / "summary.json")
    if args.dry_run:
        return 0 if results[0]["generation"] == "dry_run" else 1
    return 0 if passed else 1


def verify(args, config):
    validate(config)
    if args.lib == args.source_lib:
        raise ValueError("Verification CLI refuses source/output library aliasing")
    run = unique_root(args.work_dir) / "verification"
    code = "alVerify(%s %s %s %s %s %s)" % tuple(skill(x) for x in (
        args.lib, args.cell, args.source_lib, args.source_cell or args.cell, args.view, str(run)))
    status, log = native(config, args.cds_lib, run, code, args.timeout)
    result = describe(run, status, log)
    result["generation"] = "not_run"
    (run / "result.json").write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))
    return 0 if result["drc"] == result["lvs"] == "passed" else 1


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", default=str(ROOT / ".local/config.json"))
    parser.add_argument("--cds-lib", default="cds.lib")
    parser.add_argument("--work-dir", default=str(ROOT / ".local/runs"))
    parser.add_argument("--timeout", type=int, default=1200)
    commands = parser.add_subparsers(dest="command")
    commands.add_parser("doctor")
    gen = commands.add_parser("generate")
    gen.add_argument("--source-lib", required=True)
    gen.add_argument("--cell", required=True)
    gen.add_argument("--view", default="schematic")
    gen.add_argument("--output-lib", required=True)
    gen.add_argument("--height", type=float)
    gen.add_argument("--optimize", choices=("area", "fixed"), default="area")
    gen.add_argument("--iterations", type=int, default=1)
    gen.add_argument("--dry-run", action="store_true")
    gen.add_argument("--seed", type=int, help="Reproducible routing seed; omitted chooses a random seed; 0 uses legacy traversal")
    gen.add_argument("--placement-seed", type=int, help="Keep placement fixed across routing candidates")
    ver = commands.add_parser("verify")
    ver.add_argument("--lib", required=True)
    ver.add_argument("--cell", required=True)
    ver.add_argument("--source-lib", required=True)
    ver.add_argument("--source-cell")
    ver.add_argument("--view", default="schematic")
    rep = commands.add_parser("report")
    rep.add_argument("path", help="summary.json or result.json")
    bench = commands.add_parser("benchmark")
    bench.add_argument("manifest", help="JSON list of source library/cell/output library objects")
    args = parser.parse_args(argv)
    if not args.command:
        parser.print_help()
        return 2
    try:
        if args.command == "report":
            print(json.dumps(json.loads(Path(args.path).read_text()), indent=2))
            return 0
        config = read_config(args.config)
        if args.command == "doctor":
            return doctor(args, config)
        if args.command == "generate":
            if args.optimize == "fixed" and args.height is None:
                raise ValueError("--optimize fixed requires --height")
            return generate(args, config)
        if args.command == "verify":
            return verify(args, config)
        entries = json.loads(Path(args.manifest).read_text())
        codes = []
        for item in entries:
            run_args = argparse.Namespace(**vars(args))
            for key, val in dict(view="schematic", height=None, optimize="area", iterations=1, dry_run=False).items():
                setattr(run_args, key, val)
            for key in ("source_lib", "cell", "output_lib"):
                setattr(run_args, key, item[key])
            run_args.seed = item.get("seed")
            run_args.placement_seed = item.get("placement_seed")
            codes.append(generate(run_args, config))
        return int(any(codes))
    except (ValueError, OSError, KeyError) as exc:
        print("autolayout: " + str(exc), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
