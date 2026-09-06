#!/usr/bin/env python3
"""Verify the AudienceLab iOS agent-verifiable integration contract (GEE-510).

Runs without Xcode or network. Writes machine-checkable evidence to
verification/evidence/latest.json. Exit 0 on pass, 1 on failure.
Never prints or records raw API key material.
"""

from __future__ import annotations

import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
CONTRACT_PATH = ROOT / "contracts" / "ios-sdk.integration.v1.json"
SCHEMA_PATH = ROOT / "contracts" / "ios-sdk.integration.v1.schema.json"
EVIDENCE_DIR = ROOT / "verification" / "evidence"
EVIDENCE_PATH = EVIDENCE_DIR / "latest.json"
PRIVACY_MANIFEST = ROOT / "Sources" / "AudienceLabSDK" / "Resources" / "PrivacyInfo.xcprivacy"
SDK_SWIFT = ROOT / "Sources" / "AudienceLabSDK" / "AudienceLabSDK.swift"
SDK_CONFIG = ROOT / "Sources" / "AudienceLabSDK" / "Configuration" / "SDKConfig.swift"
PODSPEC = ROOT / "AudienceLabSDK.podspec"
PACKAGE_SWIFT = ROOT / "Package.swift"

SECRETISH = re.compile(
    r"(?i)(geeklab-api-key\s*[:=]\s*['\"](?!YOUR_|<.*>|\$\{)[^'\"]{8,}['\"])"
    r"|(api[_-]?key\s*[:=]\s*['\"](?!YOUR_|<.*>|\$\{|apiKey)[A-Za-z0-9_\-]{16,}['\"])"
)


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def check(results: list[dict[str, Any]], check_id: str, ok: bool, detail: str) -> None:
    results.append(
        {
            "id": check_id,
            "status": "pass" if ok else "fail",
            "detail": detail,
        }
    )


def require_keys(obj: dict[str, Any], keys: list[str], path: str = "$") -> list[str]:
    missing = []
    for key in keys:
        if key not in obj:
            missing.append(f"{path}.{key}")
    return missing


def extract_podspec_version(text: str) -> str | None:
    match = re.search(r's\.version\s*=\s*"([^"]+)"', text)
    return match.group(1) if match else None


def extract_sdkconfig_version(text: str) -> str | None:
    match = re.search(r'sdkVersionValue\s*=\s*"([^"]+)"', text)
    return match.group(1) if match else None


def package_includes_privacy_resource(text: str) -> bool:
    return "PrivacyInfo.xcprivacy" in text and "resources" in text


def podspec_includes_privacy_resource(text: str) -> bool:
    return "PrivacyInfo.xcprivacy" in text


def main() -> int:
    results: list[dict[str, Any]] = []
    contract: dict[str, Any] | None = None

    # 1) Contract parses
    try:
        contract = json.loads(read_text(CONTRACT_PATH))
        check(results, "contract_parses", True, f"Parsed {CONTRACT_PATH.relative_to(ROOT)}")
    except Exception as exc:  # noqa: BLE001 - harness must surface any parse failure
        check(results, "contract_parses", False, f"Failed to parse contract: {exc}")
        return finish(results, contract)

    # 2) Schema file present + contract required shape
    schema_ok = SCHEMA_PATH.is_file()
    check(
        results,
        "contract_schema_present",
        schema_ok,
        f"Schema {'found' if schema_ok else 'missing'}: {SCHEMA_PATH.relative_to(ROOT)}",
    )

    required_top = [
        "contract_id",
        "contract_version",
        "schema_ref",
        "issue_refs",
        "platform",
        "status",
        "sdk",
        "install_steps",
        "public_api",
        "credentials",
        "required_signals",
        "privacy_and_consent",
        "diagnostics",
        "rollback",
        "verification",
        "out_of_scope",
        "human_docs",
    ]
    missing = require_keys(contract, required_top)
    shape_ok = (
        not missing
        and contract.get("contract_id") == "audiencelab.ios_sdk.integration"
        and contract.get("platform") == "native_ios"
        and isinstance(contract.get("install_steps"), list)
        and len(contract.get("install_steps") or []) >= 1
    )
    check(
        results,
        "contract_schema_shape",
        shape_ok,
        "Contract top-level shape valid" if shape_ok else f"Shape issues: missing={missing}",
    )

    # 3) Version consistency
    pod_version = extract_podspec_version(read_text(PODSPEC)) if PODSPEC.is_file() else None
    config_version = extract_sdkconfig_version(read_text(SDK_CONFIG)) if SDK_CONFIG.is_file() else None
    contract_version = (contract.get("sdk") or {}).get("version")
    versions = {
        "contract.sdk.version": contract_version,
        "podspec": pod_version,
        "SDKConfig.sdkVersionValue": config_version,
    }
    present = [v for v in versions.values() if v]
    version_ok = bool(present) and len(set(present)) == 1 and contract_version is not None
    check(
        results,
        "version_consistency",
        version_ok,
        f"Versions aligned at {contract_version}" if version_ok else f"Mismatch: {versions}",
    )

    tag = (contract.get("sdk") or {}).get("version_tag")
    tag_ok = isinstance(tag, str) and tag == f"v{contract_version}"
    check(results, "version_tag_matches", tag_ok, f"version_tag={tag}")

    # 4) Public API symbols present
    api_source = read_text(SDK_SWIFT) if SDK_SWIFT.is_file() else ""
    required_symbols = [
        "public static func initialize(apiKey:",
        "public static func getCreativeToken()",
        "public static func sendAdEvent(",
        "public static func sendPurchaseEvent(",
        "public static func sendCustomEvent(",
        "public static func setSDKEnabled(",
        "public static func setMetricsCollectionEnabled(",
        "public static func setDebugEnabled(",
        "public static func reset()",
        "public static func getSDKVersion()",
        "public static func checkDataCollectionStatus(",
        "public static func verifyCreativeToken(",
        "public static func setAdvertisingId(",
    ]
    missing_symbols = [s for s in required_symbols if s not in api_source]
    check(
        results,
        "public_api_symbols_present",
        not missing_symbols and SDK_SWIFT.is_file(),
        "All required public API anchors found"
        if not missing_symbols
        else f"Missing symbols: {missing_symbols}",
    )

    # 5) Privacy manifest + packaging
    privacy_ok = PRIVACY_MANIFEST.is_file() and "NSPrivacyAccessedAPICategoryUserDefaults" in read_text(
        PRIVACY_MANIFEST
    )
    check(
        results,
        "privacy_manifest_present",
        privacy_ok,
        f"Privacy manifest {'ok' if privacy_ok else 'missing or incomplete'}",
    )

    package_text = read_text(PACKAGE_SWIFT) if PACKAGE_SWIFT.is_file() else ""
    podspec_text = read_text(PODSPEC) if PODSPEC.is_file() else ""
    packaging_ok = package_includes_privacy_resource(package_text) and podspec_includes_privacy_resource(
        podspec_text
    )
    check(
        results,
        "privacy_manifest_packaging",
        packaging_ok,
        "Package.swift and podspec reference PrivacyInfo.xcprivacy"
        if packaging_ok
        else "Package.swift and/or podspec missing PrivacyInfo.xcprivacy resource wiring",
    )

    # 6) Docs present
    human_docs = contract.get("human_docs") or []
    missing_docs = [d for d in human_docs if not (ROOT / d).is_file()]
    agent_doc = ROOT / "docs" / "AGENT_VERIFIABLE_INTEGRATION.md"
    docs_ok = not missing_docs and agent_doc.is_file()
    check(
        results,
        "docs_present",
        docs_ok,
        "Human docs present" if docs_ok else f"Missing docs: {missing_docs}",
    )

    # 7) Credential rules explicit
    creds = contract.get("credentials") or {}
    handoff = creds.get("handoff") or {}
    never_persist = set(handoff.get("never_persist_in") or [])
    cred_ok = (
        handoff.get("mode") in {"one_time_or_direct", "one_time", "direct"}
        and "mcp_transcripts" in never_persist
        and "ordinary_logs" in never_persist
        and "git" in never_persist
        and (creds.get("injection") or {}).get("runtime_only") is True
    )
    check(
        results,
        "credential_rules_explicit",
        cred_ok,
        "Credential one-time handoff and secret hygiene rules present"
        if cred_ok
        else "Credential handoff rules incomplete",
    )

    # 8) Rollback explicit
    rollback = contract.get("rollback") or {}
    steps = rollback.get("steps") or []
    rollback_ids = {s.get("id") for s in steps if isinstance(s, dict)}
    rollback_ok = rollback.get("required") is True and {
        "disable_sdk",
        "reset_local_state",
        "remove_package",
        "revoke_credential",
    }.issubset(rollback_ids)
    check(
        results,
        "rollback_rules_explicit",
        rollback_ok,
        "Rollback steps explicit" if rollback_ok else f"Rollback incomplete: {sorted(rollback_ids)}",
    )

    # 9) Secret hygiene across contract + docs
    scan_targets = [
        CONTRACT_PATH,
        agent_doc,
        ROOT / "docs" / "INTEGRATION.md",
        ROOT / "README.md",
    ]
    offenders: list[str] = []
    for path in scan_targets:
        if not path.is_file():
            continue
        text = read_text(path)
        if SECRETISH.search(text):
            offenders.append(str(path.relative_to(ROOT)))
    check(
        results,
        "no_secret_literals_in_contract_docs",
        not offenders,
        "No secret-like literals found" if not offenders else f"Suspicious literals in: {offenders}",
    )

    # 10) Out of scope store submit declared
    out_of_scope = contract.get("out_of_scope") or []
    store_declared = any(
        isinstance(item, dict)
        and item.get("id") in {"app_store_connect_submit", "store_submit"}
        for item in out_of_scope
    )
    check(
        results,
        "out_of_scope_store_submit_declared",
        store_declared,
        "App Store Connect submit declared out of scope"
        if store_declared
        else "Missing out_of_scope store submit declaration",
    )

    # 11) Required signals section
    signals = contract.get("required_signals") or {}
    signals_ok = (
        isinstance(signals.get("automatic"), list)
        and len(signals.get("automatic") or []) >= 1
        and isinstance(signals.get("integrator_emitted"), dict)
        and isinstance(signals.get("first_signal_checks"), list)
        and len(signals.get("first_signal_checks") or []) >= 1
    )
    check(
        results,
        "required_signals_defined",
        signals_ok,
        "Required signals defined" if signals_ok else "Required signals incomplete",
    )

    # 12) Issue refs include GEE-510
    refs = set(contract.get("issue_refs") or [])
    check(results, "issue_refs_gee510", "GEE-510" in refs, f"issue_refs={sorted(refs)}")

    return finish(results, contract)


def finish(results: list[dict[str, Any]], contract: dict[str, Any] | None) -> int:
    passed = all(item["status"] == "pass" for item in results) and bool(results)
    evidence = {
        "contract_id": (contract or {}).get("contract_id", "audiencelab.ios_sdk.integration"),
        "contract_version": (contract or {}).get("contract_version"),
        "sdk_version": ((contract or {}).get("sdk") or {}).get("version"),
        "generated_at": utc_now(),
        "harness": "scripts/verify_ios_integration_contract.py",
        "passed": passed,
        "checks": results,
        "notes": [
            "Evidence intentionally omits secrets and network calls.",
            "Store submission automation is out of scope for GEE-510.",
        ],
    }

    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    EVIDENCE_PATH.write_text(json.dumps(evidence, indent=2, sort_keys=False) + "\n", encoding="utf-8")

    failed = [c for c in results if c["status"] != "pass"]
    print(f"AudienceLab iOS integration contract verification: {'PASS' if passed else 'FAIL'}")
    print(f"Evidence: {EVIDENCE_PATH.relative_to(ROOT)}")
    for item in results:
        print(f"  [{item['status'].upper()}] {item['id']}: {item['detail']}")
    if failed:
        print(f"{len(failed)} check(s) failed", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
