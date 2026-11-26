"""Generate the operator-only people API candidate from pinned C3."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile
from render_account_security import ROOT, PROFILE, replace_once

OVERLAY=ROOT/'specs/019-traderx-security-lab/generation/people-security'


def render(target):
    target=Path(target).resolve()
    baseline=json.loads((PROFILE/'baseline.lock.json').read_text())
    data=subprocess.run(['git','archive',baseline['generated_commit'],'people-service'],cwd=ROOT,capture_output=True,check=True,timeout=30).stdout
    target.mkdir(parents=True,exist_ok=False)
    with tarfile.open(fileobj=io.BytesIO(data)) as archive:
        for member in archive.getmembers():
            if member.isfile():
                relative=Path(member.name).relative_to('people-service')
                if '..' in relative.parts:raise ValueError('Invalid pinned member')
                destination=target/relative;destination.parent.mkdir(parents=True,exist_ok=True)
                destination.write_bytes(archive.extractfile(member).read());destination.chmod(member.mode & 0o777)
    project=target/'PeopleService.WebApi'
    (project/'Program.cs').write_bytes((OVERLAY/'Program.cs').read_bytes())
    (project/'Security').mkdir()
    (project/'Security/DirectoryTrust.cs').write_bytes((OVERLAY/'DirectoryTrust.cs').read_bytes())
    path=project/'PeopleService.WebApi.csproj'
    path.write_text(replace_once(path.read_text(),'<PackageReference Include="Swashbuckle.AspNetCore" Version="8.1.4" />',
        '<PackageReference Include="Microsoft.AspNetCore.Authentication.JwtBearer" Version="9.0.23" />'))
    path=project/'Controllers/PeopleController.cs';source=path.read_text()
    source=source.replace('_logger.LogWarning("GetPerson not found for logonId={LogonId}, employeeId={EmployeeId}", logonId, employeeId);','_logger.LogWarning("Directory lookup not found");')
    source=source.replace('_logger.LogWarning("GetMatchingPeople no matches for searchText={SearchText}", searchText);','_logger.LogWarning("Directory search not found");')
    source=source.replace('_logger.LogWarning("ValidatePerson failed for logonId={LogonId}, employeeId={EmployeeId}", logonId, employeeId);','_logger.LogWarning("Directory validation not found");')
    marker='''        if (string.IsNullOrWhiteSpace(logonId) && string.IsNullOrWhiteSpace(employeeId))'''
    if source.count(marker)!=2:raise ValueError('Pinned directory route changed')
    source=source.replace(marker,'''        if (logonId?.Length > 128 || employeeId?.Length > 128 || (logonId != null && employeeId != null))
            return BadRequest("Invalid lookup");
'''+marker)
    source=replace_once(source,'        if (searchText.Length < 3)','        if (searchText.Length < 3 || searchText.Length > 128)')
    source=replace_once(source,'''        if (take <= 0)
        {
            take = 10;
        }''','''        if (take < 1 || take > 25) return BadRequest("Invalid result limit");''')
    path.write_text(source)
    inputs=[Path(__file__).resolve(),ROOT/'scripts/security-lab/render_account_security.py',PROFILE/'baseline.lock.json',*sorted(OVERLAY.glob('*.cs'))]
    manifest={'scope':'Operator-only people API; no ordinary directory grants or deployed cutover',
        'generated_commit':baseline['generated_commit'],'source_commit':baseline['canonical_source_commit'],
        'inputs':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs},
        'files':{str(p.relative_to(target)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(target.rglob('*')) if p.is_file()}}
    (target/'security-generation.json').write_text(json.dumps(manifest,indent=2)+'\n')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output-dir',required=True,type=Path)
    render(parser.parse_args().output_dir)
