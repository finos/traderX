"""Reviewed local connection settings for the security integration fixtures."""
import os
from pathlib import Path
import platform


def isolated_linux():
    value = os.environ.get('TRADERX_LAB_ISOLATED_LINUX', '')
    if value not in ('', '1'):
        raise ValueError('Invalid isolated Linux selection')
    if value == '1' and platform.system() != 'Linux':
        raise ValueError('Isolated Linux selection requires Linux')
    return value == '1'


def docker(runtime):
    if isolated_linux():
        host = os.environ.get('TRADERX_LAB_DOCKER_HOST', 'unix:///var/run/docker.sock')
        if host != 'unix:///var/run/docker.sock':
            raise ValueError('Isolated Linux requires the local Docker socket')
    else:
        if os.environ.get('TRADERX_LAB_DOCKER_HOST'):
            raise ValueError('Docker host override requires isolated Linux')
        host = 'unix://' + str(Path.home()/'.docker/run/docker.sock')
    return ['docker', '--config', str(Path(runtime)/'docker-client'), '--host', host]


def java():
    home = os.environ.get('JAVA_HOME')
    if home:
        executable = Path(home)/'bin/java'
    elif platform.system() == 'Darwin':
        executable = Path('/Library/Java/JavaVirtualMachines/zulu-21.jdk/Contents/Home/bin/java')
    else:
        raise ValueError('Set JAVA_HOME to the Java 21 installation')
    if not executable.is_file() or not os.access(executable, os.X_OK):
        raise ValueError('JAVA_HOME does not contain an executable java')
    return str(executable)
