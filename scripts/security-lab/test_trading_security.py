import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from render_trading_security import render,controller,SERVICES

class TradingGenerationTests(unittest.TestCase):
    def test_both_services_reproduce_with_verified_input_and_file_hashes(self):
        with tempfile.TemporaryDirectory() as root:
            for service in SERVICES:
                first=Path(root)/(service+'-one');second=Path(root)/(service+'-two')
                render(first,service);render(second,service)
                self.assertEqual((first/'security-generation.json').read_bytes(),(second/'security-generation.json').read_bytes())
                manifest=json.loads((first/'security-generation.json').read_text())
                for name,digest in manifest['files'].items():self.assertEqual(hashlib.sha256((first/name).read_bytes()).hexdigest(),digest)
                source=next(first.glob('src/main/java/**/controller/'+('TradeOrderController' if service=='trade-service' else 'OrderController')+'.java')).read_text()
                with self.assertRaises(ValueError):controller(source,service)
    def test_unknown_service_refused_before_directory_creation(self):
        with tempfile.TemporaryDirectory() as root:
            target=Path(root)/'bad'
            with self.assertRaises(ValueError):render(target,'unknown')
            self.assertFalse(target.exists())
