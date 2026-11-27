"""Opt-in position/history authorization candidate from immutable C3; no runtime cutover."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile
from render_account_security import ROOT, PROFILE, replace_once

OVERLAY=PROFILE/'generation/read-security'
PACKAGE='finos.traderx.positionservice'


def controller(source,trade=False):
    name='Trade' if trade else 'Position'
    service=name.lower()+'Service'
    source=replace_once(source,'import java.util.List;','import java.util.List;\nimport '+PACKAGE+'.security.TradingAccess;\nimport org.springframework.security.access.AccessDeniedException;')
    source=replace_once(source,'  private final '+name+'Service '+service+';', '  private final TradingAccess access;\n  private final '+name+'Service '+service+';')
    source=replace_once(source,f'public {name}Controller({name}Service {service})',f'public {name}Controller({name}Service {service}, TradingAccess access)')
    source=replace_once(source,f'    this.{service} = {service};',f'    this.access = access;\n    this.{service} = {service};')
    getter='get'+name+'sByAccountID'
    source=replace_once(source,f'    return ResponseEntity.ok({service}.{getter}(accountId));',f'''    access.requireAccount(accountId);
    return ResponseEntity.ok({service}.{getter}(accountId).stream()
        .filter(item -> Integer.valueOf(accountId).equals(item.getAccountId())).toList());''')
    source=replace_once(source,f'    return ResponseEntity.ok({service}.getAll{name}s());',f'''    var accounts = access.accounts();
    return ResponseEntity.ok(accounts.stream().sorted().flatMap(account ->
        {service}.{getter}(account).stream().filter(item -> account.equals(item.getAccountId()))).toList());''')
    source=replace_once(source,'  @ExceptionHandler(Exception.class)', '''  @ExceptionHandler(AccessDeniedException.class)
  public ResponseEntity<String> forbidden(AccessDeniedException ignored) {
    return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Forbidden");
  }

  @ExceptionHandler(Exception.class)''')
    return replace_once(source,'body(e.getMessage())','body("Read unavailable")')


def security():
    source=(PROFILE/'generation/account-security/AccountSecurity.java').read_text()
    source=source.replace('finos.traderx.accountservice',PACKAGE).replace('AccountSecurity','ReadSecurity')
    source=source.replace('accountChain(HttpSecurity http)','readChain(HttpSecurity http, TradingAccess access)')
    source=replace_once(source,'.authorizeHttpRequests(auth -> auth', '.authorizeHttpRequests(auth -> auth\n            .dispatcherTypeMatchers(jakarta.servlet.DispatcherType.ERROR).permitAll()')
    return replace_once(source,'''            .requestMatchers(HttpMethod.GET, "/account/", "/account/*", "/accountuser/", "/accountuser/*").authenticated()''', '''            .requestMatchers(HttpMethod.GET, "/positions/", "/positions/*", "/trades/", "/trades/*").authenticated()
            .requestMatchers(HttpMethod.GET, "/health/ready", "/health/alive", "/metrics", "/actuator/prometheus")
                .access((authentication, context) -> new org.springframework.security.authorization.AuthorizationDecision(access.isOperator()))''')


def render(target):
    target=Path(target).resolve()
    baseline=json.loads((PROFILE/'baseline.lock.json').read_text())
    data=subprocess.run(['git','archive',baseline['generated_commit'],'position-service'],cwd=ROOT,capture_output=True,check=True,timeout=30).stdout
    target.mkdir(parents=True,exist_ok=False)
    with tarfile.open(fileobj=io.BytesIO(data)) as archive:
        for member in archive.getmembers():
            if member.isfile():
                relative=Path(member.name).relative_to('position-service')
                if '..' in relative.parts:raise ValueError('Invalid pinned archive member')
                dest=target/relative;dest.parent.mkdir(parents=True,exist_ok=True)
                dest.write_bytes(archive.extractfile(member).read());dest.chmod(member.mode & 0o777)
    package=target/'src/main/java'/PACKAGE.replace('.','/')
    for name in ('Position','Trade'):
        path=package/'controller'/(name+'Controller.java');path.write_text(controller(path.read_text(),name=='Trade'))
    (package/'config/CorsConfig.java').unlink()
    dest=package/'security';dest.mkdir()
    (dest/'ReadSecurity.java').write_text(security())
    access=PROFILE/'generation/trading-security/TradingAccess.java'
    (dest/'TradingAccess.java').write_text(access.read_text().replace('__PACKAGE__',PACKAGE))
    tests=target/'src/test/java'/PACKAGE.replace('.','/')/'security';tests.mkdir(parents=True)
    support=PROFILE/'generation/trading-security/tests/SecurityTestSupport.java'
    for source in [support,*sorted(OVERLAY.glob('*.java'))]:
        (tests/source.name).write_text(source.read_text().replace('__PACKAGE__',PACKAGE))
    build=target/'build.gradle';build.write_text(replace_once(build.read_text(),'dependencies {',"dependencies {\n  implementation 'org.springframework.boot:spring-boot-starter-oauth2-resource-server'\n  testImplementation 'org.springframework.security:spring-security-test'\n  testRuntimeOnly 'com.h2database:h2:2.4.240'"))
    inputs=[Path(__file__).resolve(),ROOT/'scripts/security-lab/render_account_security.py',PROFILE/'baseline.lock.json',PROFILE/'generation/account-security/AccountSecurity.java',access,support,*sorted(OVERLAY.glob('*.java'))]
    manifest={'scope':'Position/history API candidate; people and deployed UI integration pending','service':'position-service','generated_commit':baseline['generated_commit'],'source_commit':baseline['canonical_source_commit'],
      'inputs':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs},
      'files':{str(p.relative_to(target)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(target.rglob('*')) if p.is_file()}}
    (target/'security-generation.json').write_text(json.dumps(manifest,indent=2)+'\n')

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output-dir',type=Path,required=True);args=parser.parse_args();render(args.output_dir)
