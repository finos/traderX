import unittest

from prepare_runtime import parse_image


class ImageReferenceTests(unittest.TestCase):
    def test_tag_is_not_registry_port(self):
        self.assertEqual(parse_image('nginx:alpine-slim'),
                         ('registry-1.docker.io', 'library/nginx', 'alpine-slim'))

    def test_tag_and_digest(self):
        digest = 'sha256:' + 'a' * 64
        self.assertEqual(parse_image('nginx:alpine-slim@' + digest),
                         ('registry-1.docker.io', 'library/nginx', digest))

    def test_qualified_and_default_references(self):
        for image, expected in [
            ('ghcr.io/finos/traderx-c3/account-service:abc',
             ('ghcr.io', 'finos/traderx-c3/account-service', 'abc')),
            ('grafana/grafana:12.4.15', ('registry-1.docker.io', 'grafana/grafana', '12.4.15')),
            ('busybox', ('registry-1.docker.io', 'library/busybox', 'latest')),
            ('localhost:5000/example:v1', ('localhost:5000', 'example', 'v1')),
        ]:
            self.assertEqual(parse_image(image), expected)
