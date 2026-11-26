#!/usr/bin/env python3
"""Opt-in account-service overlay derived from the immutable C3 snapshot."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile
from account_dev import ROOT, PROFILE

OVERLAY=PROFILE/'generation/account-security'


def replace_once(text, before, after):
    if text.count(before)!=1: raise ValueError('Inherited source contract changed: '+before[:70])
    return text.replace(before,after)


def secure_controller(text, membership=False):
    text=replace_once(text,'@CrossOrigin("*")\n','')
    text=text.replace('import org.springframework.web.bind.annotation.CrossOrigin;\n','')
    text=text.replace('import java.util.List;','import java.util.List;\nimport finos.traderx.accountservice.security.AccountAccess;\nimport org.springframework.security.access.AccessDeniedException;')
    classname='AccountUserController' if membership else 'AccountController'
    text=replace_once(text,'public class '+classname+' {','public class '+classname+' {\n\n  private final AccountAccess accountAccess;')
    if membership:
        text=replace_once(text,'PeopleValidationService peopleValidationService\n','PeopleValidationService peopleValidationService,\n      AccountAccess accountAccess\n')
        text=replace_once(text,'this.accountUserService = accountUserService;','this.accountAccess = accountAccess;\n    this.accountUserService = accountUserService;')
        method='getAccountUserById'; service='accountUserService'; getter='getAllAccountUsers'; entity='AccountUser'; idgetter='getAccountId'
    else:
        text=replace_once(text,'public AccountController(AccountService accountService)', 'public AccountController(AccountService accountService, AccountAccess accountAccess)')
        text=replace_once(text,'this.accountService = accountService;','this.accountAccess = accountAccess;\n    this.accountService = accountService;')
        method='getAccountById'; service='accountService'; getter='getAllAccount'; entity='Account'; idgetter='getId'
    text=replace_once(text,f'    return ResponseEntity.ok({service}.{method}(id));',f'    accountAccess.requireAccount(id);\n    return ResponseEntity.ok({service}.{method}(id));')
    text=replace_once(text,f'    return ResponseEntity.ok({service}.{getter}());',f'    var allowed = accountAccess.accounts();\n    return ResponseEntity.ok({service}.{getter}().stream().filter(item -> allowed.contains(item.{idgetter}())).toList());')
    text=replace_once(text,'  @ExceptionHandler(Exception.class)', '''  @ExceptionHandler(AccessDeniedException.class)
  public ResponseEntity<String> forbidden(AccessDeniedException ignored) {
    return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Forbidden");
  }

  @ExceptionHandler(Exception.class)''')
    return text



def read_only_controller(text,membership=False):
    """Remove inaccessible legacy writes and their people-validation dependency."""
    start='  @PostMapping("/")';end='  @GetMapping("/")'
    if text.count(start)!=1 or text.count(end)!=1 or text.count('  @PutMapping("/")')!=1:
        raise ValueError('Inherited account write boundary changed')
    a,b=text.index(start),text.index(end)
    if a>=b or '  @PutMapping("/")' not in text[a:b]:raise ValueError('Inherited write ordering changed')
    text=text[:a]+text[b:]
    for name in ('PostMapping','PutMapping','RequestBody'):
        text=replace_once(text,'import org.springframework.web.bind.annotation.'+name+';\n','')
    if membership:
        for before in ('import finos.traderx.accountservice.service.PeopleValidationService;\n',
                       '  private final PeopleValidationService peopleValidationService;\n',
                       '      PeopleValidationService peopleValidationService,\n',
                       '    this.peopleValidationService = peopleValidationService;\n'):
            text=replace_once(text,before,'')
    return text


def render(target):
    baseline=json.loads((PROFILE/'baseline.lock.json').read_text())
    commit=baseline['generated_commit']
    data=subprocess.run(['git','archive',commit,'account-service'],cwd=ROOT,check=True,capture_output=True,timeout=30).stdout
    target.mkdir(parents=True,exist_ok=False)
    with tarfile.open(fileobj=io.BytesIO(data)) as archive:
        for member in archive.getmembers():
            if member.isfile():
                relative=Path(member.name).relative_to('account-service')
                if '..' in relative.parts: raise ValueError('Invalid archive member')
                destination=target/relative; destination.parent.mkdir(parents=True,exist_ok=True)
                destination.write_bytes(archive.extractfile(member).read()); destination.chmod(member.mode & 0o777)
    package=target/'src/main/java/finos/traderx/accountservice'
    for name in ('AccountController','AccountUserController'):
        path=package/'controller'/f'{name}.java'; path.write_text(read_only_controller(secure_controller(path.read_text(),name=='AccountUserController'),name=='AccountUserController'))
    (package/'config/CorsConfig.java').unlink()
    (package/'service/PeopleValidationService.java').unlink()
    properties=target/'src/main/resources/application.properties'
    properties.write_text(replace_once(properties.read_text(),'people.service.url=${PEOPLE_SERVICE_URL:http://${PEOPLE_SERVICE_HOST:localhost}:18089}\n',''))
    security=package/'security'; security.mkdir()
    for name in ('AccountAccess.java','AccountSecurity.java'): (security/name).write_bytes((OVERLAY/name).read_bytes())
    tests=target/'src/test/java/finos/traderx/accountservice/security'; tests.mkdir(parents=True,exist_ok=True)
    (tests/'AccountAccessTest.java').write_bytes((OVERLAY/'AccountAccessTest.java').read_bytes())
    build=target/'build.gradle'; build.write_text(replace_once(build.read_text(),"dependencies {", "dependencies {\n  implementation 'org.springframework.boot:spring-boot-starter-oauth2-resource-server'"))
    inputs={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [Path(__file__).resolve(),*OVERLAY.glob('*.java')]}
    files={str(p.relative_to(target)):hashlib.sha256(p.read_bytes()).hexdigest() for p in target.rglob('*') if p.is_file()}
    (target/'security-generation.json').write_text(json.dumps({'generated_commit':commit,'source_commit':baseline['canonical_source_commit'],'inputs':inputs,'files':files},indent=2)+'\n')


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output-dir',type=Path,required=True);args=parser.parse_args()
    render(args.output_dir.resolve());print('Rendered opt-in account security candidate.')

if __name__=='__main__':main()
