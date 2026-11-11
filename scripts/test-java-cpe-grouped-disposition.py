#!/usr/bin/env python3
"""Regression contract for the approved, exact-artifact Java CPE disposition."""
import copy
import json
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
NS = {'s': 'https://jeremylong.github.io/DependencyCheck/dependency-suppression.1.3.xsd'}
EXPECTED = {
    '457309ce1ed276bd9b1f4029c97c22721f58f346': {'CVE-2026-54285'},
    'a979f45396c5332f43b9198ebf3eb52f5451e83f': {'CVE-2026-54285'},
    'a3e7c14152b6b6c62e0c64f991791fa0c5cbf02d': {'CVE-2026-54285'},
    'c464ca72cbf4af1961ab366a1074534ca0fdc6cf': {'CVE-2026-54285'},
    'cb70230f3dfed778047865de58880572446e6464': {'CVE-2026-54285'},
    'b26d3a697e4d42fa12e61e5e9c6dfacb46250766': {'CVE-2026-54285'},
    '3057a2a4776bb095342599524e82a92cfef676b9': {'CVE-2026-54285'},
    '02c4f1eddd4ba35a82d27d6c784e3d4fbb3c8a3a': {'CVE-2026-54285'},
    'c43e69b259fe060b67520e4f011fa776a2dcca58': {'CVE-2026-54285'},
    'f20fc03f7ea80cd062520f6cda3b1a61a107860f': {'CVE-2026-54285'},
    '0b4c62673fb2f2385b691d6600a194f98fbc8625': {'CVE-2026-54285'},
    '2db32c617c5d37c9ee69d58009edcc9a12ba6a24': {'CVE-2026-54285'},
    'b0334b4edb3d14e181f9f4fdc40a0dd5a6bcbffd': {'CVE-2026-54285'},
}


def validate(rules):
    assert len(rules) == 13
    found = {}
    for rule in rules:
        assert rule.attrib == {'until': '2026-12-11Z'}
        assert all(e.tag.split('}')[-1] in {'notes', 'sha1', 'cve'} and not e.attrib for e in rule)
        assert len(rule.findall('s:sha1', NS)) == 1
        sha1 = rule.findtext('s:sha1', namespaces=NS)
        assert sha1 not in found
        found[sha1] = {e.text for e in rule.findall('s:cve', NS)}
        assert len(found[sha1]) == len(rule.findall('s:cve', NS))
    assert found == EXPECTED


class DispositionTests(unittest.TestCase):
    def setUp(self):
        self.metadata = json.loads((ROOT / 'catalog/security/java-cpe-grouped-otel.json').read_text())
        self.rules = list(ET.parse(ROOT / 'catalog/security/java-cpe-grouped-otel.xml').getroot())

    def test_approved_exact_scope_installed(self):
        validate(self.rules)
        d = self.metadata
        self.assertEqual((d['status'], d['approved'], d['active']), ('approved', True, True))
        self.assertEqual(d['approval']['decision'], 'Ok approve the additional 13 exact hashes for that CVE.')
        self.assertEqual(d['approval']['reference'], 'https://github.com/finos/traderX/pull/489#issuecomment-6794836886')
        self.assertEqual(d['expires'], '2026-12-11T00:00:00Z')
        self.assertEqual({a['sha1']: set(a['cves']) for a in d['artifacts']}, EXPECTED)
        canonical = ET.parse(ROOT / d['canonicalSuppressionFile']).getroot()
        installed = [r for r in canonical if r.findtext('s:sha1', namespaces=NS) in EXPECTED]
        validate(installed)
        self.assertEqual([ET.tostring(r).strip() for r in installed], [ET.tostring(r).strip() for r in self.rules])

    def test_changed_hash_rejected(self):
        rules = copy.deepcopy(self.rules)
        rules[0].find('s:sha1', NS).text = '0' * 40
        with self.assertRaises(AssertionError):
            validate(rules)

    def test_added_cve_rejected(self):
        rules = copy.deepcopy(self.rules)
        ET.SubElement(rules[0], '{' + NS['s'] + '}cve').text = 'CVE-2099-99999'
        with self.assertRaises(AssertionError):
            validate(rules)

    def test_extended_or_missing_expiry_rejected(self):
        for expiry in ('2027-12-11Z', None):
            rules = copy.deepcopy(self.rules)
            rules[0].attrib = {} if expiry is None else {'until': expiry}
            with self.assertRaises(AssertionError):
                validate(rules)

    def test_broad_selector_rejected(self):
        rules = copy.deepcopy(self.rules)
        ET.SubElement(rules[0], '{' + NS['s'] + '}cpe').text = 'cpe:/a:opentelemetry:opentelemetry'
        with self.assertRaises(AssertionError):
            validate(rules)

    def test_report_retention_and_gate_unchanged(self):
        source = (ROOT / 'pipeline/install-generated-ci-assets.sh').read_text()
        start = source.rfind('      - name: Dependency check\n', 0, source.index('--suppression .github/gradle-cve-ignore-list.xml'))
        block = source[start:]
        block = block[:block.index('\nEOF')]
        self.assertIn('--suppression .github/gradle-cve-ignore-list.xml', block)
        self.assertIn('--failOnCVSS 5', block)
        self.assertIn('if: ${{ always() }}', block)
        self.assertIn('actions/upload-artifact@', block)
        self.assertIn('gradle-cve-ignore-list.xml node-cve-ignore-list.xml dotnet-cve-ignore-list.xml', source)

    def test_full_published_jar_scan_evidence(self):
        proof = self.metadata['fullScanVerification']
        self.assertEqual((proof['status'], proof['exitCode'], proof['unsuppressedFindings']), ('passed', 0, 0))
        self.assertEqual(proof['threshold'], '--failOnCVSS 5')
        self.assertEqual(len(self.metadata['rawReports']), 11)
        self.assertEqual(self.metadata['negativeVerification']['wrongHashesRejected'], 13)
        self.assertEqual(self.metadata['negativeVerification']['expiredRulesRejected'], 13)
        for artifact in self.metadata['artifacts']:
            self.assertEqual(artifact['version'], '1.55.0')
            self.assertEqual(artifact['groupId'], 'io.opentelemetry')
            self.assertEqual(len(artifact['sha256']), 64)


if __name__ == '__main__':
    unittest.main()
