#!/usr/bin/env python3
"""Regression contract for the approved, exact-artifact Java CPE disposition."""
import copy
import hashlib
import json
import os
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
NS = {'s': 'https://jeremylong.github.io/DependencyCheck/dependency-suppression.1.3.xsd'}
EXPECTED = {
    'a71c43562e4d55c75997ccaa0c0513e5f881b703': {'CVE-2026-54285'},
    '02b40108f65cbbbc142c1abf9f4a0599c968434a': {'CVE-2026-54285', 'CVE-2026-39882', 'CVE-2026-40894', 'CVE-2026-44967', 'CVE-2026-41178'},
    'c6f9a930842c93c08fd87349db3defcbc228e925': {'CVE-2026-54285', 'CVE-2026-24051', 'CVE-2026-39882', 'CVE-2026-39883', 'CVE-2026-41178', 'CVE-2026-29181'},
    '325c56fe5bb79cf288162d2d8d5f70b53fe1f507': {'CVE-2026-0994'},
}


def validate(rules):
    assert len(rules) == 4
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
        self.metadata = json.loads((ROOT / 'catalog/security/java-cpe-ecosystem-disposition.json').read_text())
        self.rules = list(ET.parse(ROOT / 'catalog/security/java-cpe-ecosystem-disposition.xml').getroot())

    def test_approved_exact_scope_installed(self):
        validate(self.rules)
        d = self.metadata
        self.assertEqual((d['status'], d['approved'], d['active']), ('approved', True, True))
        self.assertEqual(d['approval']['decision'], 'Approve the exact scoped disposition')
        self.assertEqual(d['approval']['reference'], 'https://github.com/finos/traderX/pull/489#issuecomment-6794024705')
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

    @unittest.skipUnless(os.environ.get('TRADERX_JAVA_CPE_RAW_REPORT'), 'optional retained raw report not supplied')
    def test_retained_raw_report_exact_pairs(self):
        from html.parser import HTMLParser
        raw = Path(os.environ['TRADERX_JAVA_CPE_RAW_REPORT']).read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(), self.metadata['rawReport']['sha256'])
        pairs = set()
        class ReportParser(HTMLParser):
            def handle_starttag(self, tag, attrs):
                attrs = dict(attrs)
                if attrs.get('data-sha1') in EXPECTED and attrs.get('data-id-to-suppress', '').startswith('CVE-'):
                    pairs.add((attrs['data-sha1'], attrs['data-id-to-suppress']))
        ReportParser().feed(raw.decode())
        self.assertEqual(pairs, {(sha1, cve) for sha1, cves in EXPECTED.items() for cve in cves})


if __name__ == '__main__':
    unittest.main()
