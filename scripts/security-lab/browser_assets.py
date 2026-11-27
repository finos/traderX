"""Bounded immutable public-asset registry for the generated Angular candidate."""
from html.parser import HTMLParser
from pathlib import Path
import re

MAX_FILE=16*1024*1024
MAX_TOTAL=64*1024*1024
MAX_FILES=1024
SPA_ROUTES=frozenset(('/', '/trade', '/account', '/admin', '/about', '/status'))
# Pinned AG Grid Alpine embeds its icon font in compiled CSS as a data URL.
# Font bytes need data:, while executable scripts and network connections stay same-origin.
CSP="default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self'; object-src 'none'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'"
MEDIA={'.png':'image/png','.jpg':'image/jpeg','.jpeg':'image/jpeg','.svg':'image/svg+xml',
       '.gif':'image/gif','.webp':'image/webp','.ico':'image/x-icon','.woff':'font/woff',
       '.woff2':'font/woff2','.ttf':'font/ttf','.otf':'font/otf'}


class IndexPolicy(HTMLParser):
    def __init__(self,files):
        super().__init__(convert_charrefs=True)
        self.files=files

    def reference(self,value):
        if not isinstance(value,str) or not value or value.startswith('//'):
            raise ValueError('Local generated asset required')
        path=value[2:] if value.startswith('./') else value.lstrip('/')
        if '/'+path not in self.files:raise ValueError('Referenced generated asset missing')

    def handle_starttag(self,tag,attrs):
        values=dict(attrs)
        if len(values)!=len(attrs):raise ValueError('Duplicate index attribute')
        if any(name.lower().startswith('on') for name,_ in attrs):
            raise ValueError('Inline event handler in generated index')
        if tag=='script':
            src=values.get('src','')
            if not re.fullmatch(r'(?:\./|/)?(?:main|polyfills|chunk)-[A-Za-z0-9_-]{6,64}\.js',src):
                raise ValueError('Only generated external scripts are allowed')
            self.reference(src)
        if tag=='link':self.reference(values.get('href'))
        if tag=='base' and values.get('href')!='/':
            raise ValueError('Root base href required')


def asset_type(relative):
    if relative=='index.html':return 'text/html; charset=utf-8'
    if relative=='favicon.ico':return MEDIA['.ico']
    if relative=='3rdpartylicenses.txt':return 'text/plain; charset=utf-8'
    if relative=='assets/state-ui.json':return 'application/json'
    if re.fullmatch(r'(?:main|polyfills|chunk)-[A-Za-z0-9_-]{6,64}\.js',relative):return 'text/javascript; charset=utf-8'
    if re.fullmatch(r'styles-[A-Za-z0-9_-]{6,64}\.css',relative):return 'text/css; charset=utf-8'
    if re.fullmatch(r'(?:assets/img|media)/[A-Za-z0-9_./-]+',relative):
        parts=Path(relative).parts
        if any(part.startswith('.') for part in parts):return None
        return MEDIA.get(Path(relative).suffix.lower())
    return None


class PublicAssets:
    def __init__(self,root):
        root=Path(root)
        if not root.is_absolute() or root.is_symlink() or not root.is_dir():
            raise ValueError('Absolute immutable asset directory required')
        self.files={};total=0;count=0
        for path in sorted(root.rglob('*')):
            count+=1
            if count>MAX_FILES:raise ValueError('Too many asset entries')
            if path.is_symlink():raise ValueError('Symlink asset refused')
            if not path.is_file():continue
            relative=path.relative_to(root).as_posix();kind=asset_type(relative)
            if kind is None:continue
            if path.stat().st_size>MAX_FILE:raise ValueError('Asset too large')
            data=path.read_bytes();total+=len(data)
            if len(data)>MAX_FILE or total>MAX_TOTAL:raise ValueError('Asset budget exceeded')
            self.files['/'+relative]=(data,kind)
        if '/index.html' not in self.files:raise ValueError('Generated index missing')
        html=self.files['/index.html'][0].decode('utf-8')
        parser=IndexPolicy(self.files);parser.feed(html);parser.close()

    def get(self,path):
        if not isinstance(path,str) or len(path)>512 or re.search(r'[^\x21-\x7e]|[%?#\\]',path):return None
        if not path.startswith('/') or path.startswith('//') or any(part in ('.','..') for part in path.split('/')):return None
        if path in SPA_ROUTES:return self.files['/index.html']
        return self.files.get(path)
