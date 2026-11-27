#!/usr/bin/env python3
"""Validate the State 019 CCC assessment map using only local repository files."""
import argparse
import json
from pathlib import Path, PurePosixPath
import re
import sys
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parents[2]
MAP = ROOT / "specs/019-traderx-security-lab/system/ccc-assessment-map.json"
CONTROL_ID = re.compile(r"^CCC\.(?:LB|K8S|RDMS)\.CN\d{2}$")
REQUIREMENT_ID = re.compile(r"^CCC\.(?:LB|K8S|RDMS)\.CN\d{2}\.AR\d{2}$")
COMMIT = re.compile(r"^[0-9a-f]{40}$")
RESULTS = {"verified-within-scope", "partial", "not-assessed", "planned"}
STATUSES = {
    "component-candidate",
    "deployed-local-cluster",
    "local-fixture",
    "managed-cloud-approximation",
    "not-assessed",
    "planned",
}
EVIDENCE_STATUSES = {
    "component-candidate",
    "deployed-local-cluster",
    "local-fixture",
    "managed-cloud-approximation",
}


def _require(condition, message):
    if not condition:
        raise ValueError(message)


def _check_path(value, root, label):
    _require(isinstance(value, str) and value, f"{label} must be a non-empty path")
    path = PurePosixPath(value)
    _require(not path.is_absolute(), f"{label} must be repository-relative: {value}")
    _require("\\" not in value and ".." not in path.parts, f"{label} escapes repository: {value}")
    try:
        resolved = (root / Path(*path.parts)).resolve(strict=True)
    except OSError as exc:
        raise ValueError(f"{label} does not exist: {value}") from exc
    try:
        resolved.relative_to(root)
    except ValueError as exc:
        raise ValueError(f"{label} resolves outside repository: {value}") from exc
    _require(resolved.is_file(), f"{label} must reference a file: {value}")


def _check_source_url(value, label):
    _require(isinstance(value, str) and value, f"{label} is required")
    parsed = urlparse(value)
    parts = parsed.path.strip("/").split("/")
    _require(
        parsed.scheme == "https"
        and parsed.netloc == "github.com"
        and parts[:3] == ["finos", "common-cloud-controls", "blob"]
        and len(parts) >= 8
        and COMMIT.fullmatch(parts[3]) is not None
        and parts[4] == "catalogs",
        f"{label} must be an immutable FINOS CCC catalog URL",
    )
    _require(not parsed.query and not parsed.fragment, f"{label} must not contain query or fragment data")
    return parts[5:]


def validate_mapping(document, root=ROOT):
    root = Path(root).resolve(strict=True)
    _require(isinstance(document, dict), "map must be a JSON object")
    _require(document.get("schema_version") == 1, "unsupported schema_version")
    controls = document.get("controls")
    _require(isinstance(controls, list) and controls, "controls must be a non-empty array")

    seen_controls = set()
    seen_requirements = set()
    for control in controls:
        _require(isinstance(control, dict), "each control must be an object")
        control_id = control.get("id")
        _require(
            isinstance(control_id, str) and CONTROL_ID.fullmatch(control_id),
            f"invalid control id: {control_id!r}",
        )
        _require(control_id not in seen_controls, f"duplicate control id: {control_id}")
        seen_controls.add(control_id)

        _require(isinstance(control.get("title"), str) and control["title"].strip(), f"{control_id}: title is required")
        _require(isinstance(control.get("catalog_version"), str) and control["catalog_version"].strip(), f"{control_id}: catalog_version is required")
        source_path = _check_source_url(control.get("catalog_source_url"), f"{control_id}: catalog_source_url")
        family = control_id.split(".")[1]
        expected_catalog = {
            "LB": ["networking", "loadbalancer", "controls.yaml"],
            "K8S": ["orchestration", "k8s", "controls.yaml"],
            "RDMS": ["database", "relational", "controls.yaml"],
        }[family]
        _require(source_path == expected_catalog, f"{control_id}: catalog source does not match control family")

        for field in ("implementation_paths", "evidence_paths"):
            paths = control.get(field)
            _require(isinstance(paths, list), f"{control_id}: {field} must be an array")
            if field == "implementation_paths":
                _require(paths, f"{control_id}: implementation_paths must not be empty")
            for path in paths:
                _check_path(path, root, f"{control_id}: {field}")
        _require(
            isinstance(control.get("test_command"), str) and control["test_command"].strip(),
            f"{control_id}: test_command is required",
        )

        requirements = control.get("requirements")
        _require(
            isinstance(requirements, list) and requirements,
            f"{control_id}: requirements must be a non-empty array",
        )
        for requirement in requirements:
            _require(isinstance(requirement, dict), f"{control_id}: requirement must be an object")
            requirement_id = requirement.get("id")
            _require(
                isinstance(requirement_id, str)
                and REQUIREMENT_ID.fullmatch(requirement_id)
                and requirement_id.startswith(control_id + ".AR"),
                f"{control_id}: invalid assessment requirement id {requirement_id!r}",
            )
            _require(requirement_id not in seen_requirements, f"duplicate assessment requirement id: {requirement_id}")
            seen_requirements.add(requirement_id)
            for field in ("requirement", "scope", "limitation"):
                _require(
                    isinstance(requirement.get(field), str) and requirement[field].strip(),
                    f"{requirement_id}: {field} is required",
                )
            result = requirement.get("result")
            status = requirement.get("status")
            _require(isinstance(result, str) and result in RESULTS, f"{requirement_id}: invalid result {result!r}")
            _require(isinstance(status, str) and status in STATUSES, f"{requirement_id}: invalid status {status!r}")
            if result == "planned":
                _require(status == "planned", f"{requirement_id}: planned result requires planned status")
            elif result == "not-assessed":
                _require(status == "not-assessed", f"{requirement_id}: not-assessed result requires not-assessed status")
            else:
                _require(status in EVIDENCE_STATUSES, f"{requirement_id}: observed result requires an evidence scope status")
                _require(control["evidence_paths"], f"{requirement_id}: observed result requires committed evidence paths")

    return len(seen_controls), len(seen_requirements)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=MAP, help="assessment JSON path (default: State 019 map)")
    parser.add_argument("--root", type=Path, default=ROOT, help="repository root used to resolve local paths")
    args = parser.parse_args(argv)
    try:
        document = json.loads(args.input.read_text(encoding="utf-8"))
        control_count, requirement_count = validate_mapping(document, args.root)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"CCC assessment validation failed: {exc}", file=sys.stderr)
        return 1
    print(f"CCC assessment map valid: {control_count} controls, {requirement_count} requirements (offline path/status checks only).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
