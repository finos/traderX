"""Explicit browser-to-API routes; no caller-controlled destination or credentials."""
from dataclasses import dataclass
import json
import re
import ssl
import urllib.error
import urllib.parse
import urllib.request

MAX_BODY = 16 * 1024
MAX_RESPONSE = 2 * 1024 * 1024


class BoundaryError(ValueError):
    def __init__(self, status, message):
        super().__init__(message)
        self.status = status


@dataclass(frozen=True)
class Route:
    service: str
    path: str


def route(method, target):
    # Do not normalize ambiguous paths before checking the allowlist.
    if not isinstance(target, str) or len(target) > 1024 or re.search(r'[^\x21-\x7e]|[%#\\]', target):
        raise BoundaryError(400, 'Invalid API path')
    patterns = {
        'GET': (
            ('account-service', r'/account(?:user)?/(?:[1-9][0-9]*)?'),
            ('position-service', r'/(?:positions|trades)/(?:[1-9][0-9]*)?'),
            ('order-matcher', r'/orders(?:\?accountId=[1-9][0-9]*|/[A-Za-z0-9-]{1,128})?'),
        ),
        'POST': (
            ('order-matcher', r'/orders(?:/[A-Za-z0-9-]{1,128}/cancel)?'),
            ('trade-service', r'/trade/'),
        ),
    }
    for service, pattern in patterns.get(method, ()):
        prefix = '/api/' + service
        if target.startswith(prefix) and re.fullmatch(pattern, target[len(prefix):]):
            path = target[len(prefix):]
            # These are operator routes, not order identifiers.
            if service == 'order-matcher' and path in ('/orders/open-count',):
                break
            return Route(service, path)
    raise BoundaryError(404, 'API route not available')


def json_body(body, content_type):
    if len(body) > MAX_BODY:
        raise BoundaryError(413, 'Request too large')
    if content_type.lower().split(';')[0].strip() != 'application/json':
        raise BoundaryError(415, 'JSON required')
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError('Duplicate key')
            result[key] = value
        return result
    def invalid_constant(_):
        raise ValueError('Non-finite JSON')
    try:
        value = json.loads(body, object_pairs_hook=unique, parse_constant=invalid_constant)
        if not isinstance(value, dict):
            raise ValueError('Object required')
    except (ValueError, UnicodeError, RecursionError):
        raise BoundaryError(400, 'Invalid JSON object') from None
    # Preserve decimal number spelling; APIs validate the business payload.
    return body


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class ApiProxy:
    def __init__(self, backends, context=None, *, loopback_fixture=False):
        self.backends = dict(backends)
        for service, origin in self.backends.items():
            if service not in {'account-service', 'position-service', 'order-matcher', 'trade-service'}:
                raise ValueError('Unapproved backend service')
            parsed = urllib.parse.urlsplit(origin)
            if (not parsed.hostname or parsed.username or parsed.password or parsed.path or
                    parsed.query or parsed.fragment or not parsed.port):
                raise ValueError('Explicit backend origin and port required')
            if parsed.scheme != 'https' and not (loopback_fixture and parsed.scheme == 'http' and parsed.hostname == '127.0.0.1'):
                raise ValueError('Verified backend TLS required')
        context = context or ssl.create_default_context()
        if not context.check_hostname or context.verify_mode != ssl.CERT_REQUIRED:
            raise ValueError('Verified backend TLS required')
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}),
            urllib.request.HTTPSHandler(context=context), NoRedirect())

    def call(self, method, target, token, body=None):
        selected = route(method, target)
        if selected.service not in self.backends:
            raise BoundaryError(503, 'API not configured')
        # No request headers other than these fixed, server-owned values cross.
        headers = {'Authorization': 'Bearer ' + token, 'Accept': 'application/json'}
        if body is not None:
            headers['Content-Type'] = 'application/json'
        request = urllib.request.Request(self.backends[selected.service] + selected.path,
            data=body, method=method, headers=headers)
        try:
            try:
                response = self.opener.open(request, timeout=10)
            except urllib.error.HTTPError as error:
                response = error
            with response:
                status = response.code
                # Never copy upstream cookies, redirects or error details.
                if status in (400, 401, 403, 404, 409, 422, 429):
                    return status, {'error': 'API request rejected'}
                if status not in (200, 201, 204):
                    raise BoundaryError(502, 'API response unavailable')
                raw = response.read(MAX_RESPONSE + 1)
                if len(raw) > MAX_RESPONSE:
                    raise BoundaryError(502, 'API response too large')
                if status == 204:
                    return 204, None
                if response.headers.get_content_type() != 'application/json':
                    raise BoundaryError(502, 'Invalid API response')
                return status, json.loads(raw)
        except BoundaryError:
            raise
        except (OSError, ValueError, RecursionError):
            raise BoundaryError(502, 'API unavailable') from None
