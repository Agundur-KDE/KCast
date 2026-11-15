#!/usr/bin/env python3
"""Test released PyChromecast RPMs on Leap before submitting sources to OBS."""
import argparse
import datetime
import email
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tarfile
import tempfile
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

from packaging.requirements import Requirement
from packaging.utils import canonicalize_name
from packaging.version import Version

PROJECT = 'home:Agundur'
PACKAGE = 'python-PyChromecast'
DEPENDENCIES = {'casttube', 'protobuf', 'zeroconf', 'requests'}


def run(*args, **kwargs):
    kwargs.setdefault('timeout', 1200)
    return subprocess.run(args, check=True, text=True, **kwargs)


def candidate_release(data, installed):
    version = Version(data['info']['version'])
    if version.is_prerelease or version.is_devrelease or version <= Version(installed):
        return None
    sources = [u for u in data['urls'] if u['packagetype'] == 'sdist' and not u.get('yanked')]
    if len(sources) != 1:
        return None
    return str(version), sources[0]


def update_spec(spec, version, directory, url, requires):
    if not re.fullmatch(r'\d+(?:\.\d+)+', version):
        raise ValueError('Only numeric stable releases are supported')
    if directory not in (f'pychromecast-{version}', f'PyChromecast-{version}'):
        raise ValueError('Unexpected source archive directory')
    host = urllib.parse.urlparse(url)
    if host.scheme != 'https' or host.netloc != 'files.pythonhosted.org':
        raise ValueError('Source must come from PyPI file storage')
    lines = []
    for value in requires:
        dep = Requirement(value)
        name = canonicalize_name(dep.name)
        constraints = list(dep.specifier)
        if (name not in DEPENDENCIES or dep.marker or dep.extras or dep.url
                or len(constraints) > 1 or (constraints and constraints[0].operator != '>=')):
            raise ValueError(f'Dependency needs packaging review: {value}')
        constraint = f' >= {constraints[0].version}' if constraints else ''
        lines.append(f'Requires:       python-{name}{constraint}')
    spec, n = re.subn(r'^Version:.*$', f'Version:        {version}', spec, flags=re.M)
    if n != 1:
        raise ValueError('Expected one Version field')
    spec, n = re.subn(r'^Source:.*$', 'Source:         ' + url.replace(version, '%{version}'), spec, flags=re.M)
    if n != 1:
        raise ValueError('Expected one Source field')
    spec, n = re.subn(r'^%setup .*$', '%setup -q -n ' + directory.replace(version, '%{version}'), spec, flags=re.M)
    if n != 1:
        raise ValueError('Expected one source extraction command')
    old = re.findall(r'^Requires:.*$', spec, re.M)
    if any(not re.match(r'Requires:\s+python-(?:casttube|protobuf|zeroconf|requests)(?:\s|$)', line) for line in old):
        raise ValueError('Existing RPM has additional requirements; review first')
    spec = re.sub(r'^Requires:.*\n', '', spec, flags=re.M)
    anchor = 'BuildArch:' if 'BuildArch:' in spec else '%prep'
    return spec.replace(anchor, '\n'.join(lines) + '\n' + anchor, 1)


def prepare_sources(directory, release, archive, data):
    url = urllib.parse.urlparse(archive['url'])
    if url.scheme != 'https' or url.netloc != 'files.pythonhosted.org':
        raise ValueError('Untrusted archive location')
    filename = archive['filename']
    if Path(filename).name != filename or not filename.endswith('.tar.gz'):
        raise ValueError('Unexpected archive filename')
    with urllib.request.urlopen(archive['url'], timeout=60) as response:
        content = response.read(30 * 1024 * 1024 + 1)
    if len(content) > 30 * 1024 * 1024 or hashlib.sha256(content).hexdigest() != archive['digests']['sha256']:
        raise ValueError('Archive size or SHA-256 verification failed')
    target = directory / filename
    target.write_bytes(content)
    with tarfile.open(target) as source:
        metadata = [m for m in source.getmembers() if m.name.endswith('/PKG-INFO') and m.name.count('/') == 1]
        if len(metadata) != 1 or metadata[0].size > 1024 * 1024:
            raise ValueError('Missing or ambiguous source package metadata')
        info = email.message_from_bytes(source.extractfile(metadata[0]).read())
        if canonicalize_name(info['Name']) != 'pychromecast' or Version(info['Version']) != Version(release):
            raise ValueError('Archive metadata does not match release')
        requires = info.get_all('Requires-Dist', [])
        if sorted(requires) != sorted(data['info']['requires_dist'] or []):
            raise ValueError('PyPI and archive dependency metadata differ')
        top = metadata[0].name.split('/')[0]
    specfile = directory / 'python-PyChromecast.spec'
    specfile.write_text(update_spec(specfile.read_text(), release, top, archive['url'], requires))
    changes = directory / 'python-PyChromecast.changes'
    date = datetime.datetime.now(datetime.timezone.utc).strftime('%a %b %d %H:%M:%S UTC %Y')
    changes.write_text(f'-------------------------------------------------------------------\n{date} - Agundur RPM automation\n\n- Update to upstream release {release}; synchronize runtime dependencies.\n- Leap RPM build and catt CLI/API smoke checks passed before submission.\n\n' + changes.read_text())
    return target


def validate(directory):
    """Build/install the actual RPM, using only Leap/OBS RPM dependencies."""
    script = r'''
set -eu
zypper --non-interactive ar -f https://download.opensuse.org/repositories/home:/Agundur/16.0/home:Agundur.repo
zypper --non-interactive --gpg-auto-import-keys refresh
zypper --non-interactive install --no-recommends rpm-build python-rpm-macros fdupes python313-pip python313-setuptools python313-wheel catt
mkdir -p /tmp/rpmbuild/SOURCES
cp /candidate/*.tar.gz /tmp/rpmbuild/SOURCES/
rpmspec --parse --define 'pythons python313' /candidate/python-PyChromecast.spec > /tmp/spec.parsed
rpmbuild -bb --define '_topdir /tmp/rpmbuild' --define 'pythons python313' /candidate/python-PyChromecast.spec
# Only the locally built candidate is unsigned; all earlier repository installs
# use normal signature verification. RPM also checks its runtime requirements.
rpm -Uvh /tmp/rpmbuild/RPMS/noarch/python313-PyChromecast-*.rpm
python3.13 -m pip check
catt --version
catt --help
python3.13 -c 'from pychromecast import Chromecast, get_listed_chromecasts; from pychromecast.controllers.media import MediaController; from pychromecast.controllers.youtube import YouTubeController; from catt.controllers import CastController; print("catt and PyChromecast API imports: OK")'
rpm -q python313-PyChromecast catt
'''
    run('docker', 'run', '--rm', '-v', f'{directory}:/candidate:ro', 'opensuse/leap:16.0', 'sh', '-c', script)


def submit_after_validation(directory, target, release, apply):
    validate(directory)
    if not apply:
        print('Dry run passed. OBS sources were not changed.', flush=True)
        return
    run('osc', 'add', target.name, cwd=directory)
    run('osc', 'commit', '-m', f'Update PyChromecast to tested upstream release {release} for Leap 16', cwd=directory)
    print('Sources submitted. Waiting for both Leap architectures to publish.', flush=True)
    wait_for_publication(release)


def obs_xml(path):
    return ET.fromstring(subprocess.check_output(['osc', 'api', path], timeout=120))


def wait_for_publication(release):
    source = obs_xml(f'/source/{PROJECT}/{PACKAGE}?view=info').get('srcmd5')
    if not source:
        raise ValueError('OBS did not report the submitted source checksum')
    deadline = time.monotonic() + 1200
    previous = None
    while time.monotonic() < deadline:
        results = obs_xml(f'/build/{PROJECT}/_result?repository=16.0&package={PACKAGE}')
        rows = []
        good = set()
        for result in results.findall('result'):
            arch = result.get('arch')
            status = result.find('status')
            if arch not in {'x86_64', 'aarch64'} or status is None:
                continue
            rows.append(f'{arch}: {status.get("code")} ({result.get("state")})')
            info = obs_xml(f'/build/{PROJECT}/16.0/{arch}/{PACKAGE}/_buildinfo')
            if info.findtext('srcmd5') != source or result.get('dirty') == 'true':
                continue
            if status.get('code') in {'failed', 'broken', 'unresolvable'}:
                raise RuntimeError(f'OBS {arch}: {ET.tostring(status, encoding="unicode")}')
            if status.get('code') == 'succeeded' and result.get('state') == 'published':
                binaries = obs_xml(f'/build/{PROJECT}/16.0/{arch}/{PACKAGE}')
                if any(b.get('filename', '').startswith(f'python313-PyChromecast-{release}-')
                       and b.get('filename', '').endswith('.noarch.rpm') for b in binaries):
                    good.add(arch)
        summary = '; '.join(rows)
        if summary != previous:
            print(summary, flush=True)
            previous = summary
        if good == {'x86_64', 'aarch64'}:
            print(f'PyChromecast {release} published for both Leap architectures.', flush=True)
            return
        time.sleep(20)
    raise TimeoutError('OBS publication still pending after 20 minutes; inspect OBS build results')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true', help='Submit only after successful RPM/compatibility checks')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='pychromecast-refresh-') as tmp:
        directory = Path(tmp) / 'package'
        run('osc', 'checkout', f'{PROJECT}/{PACKAGE}', '-o', str(directory))
        spec = (directory / 'python-PyChromecast.spec').read_text()
        installed = re.search(r'^Version:\s+(\S+)', spec, re.M).group(1)
        metadata = ET.fromstring(subprocess.check_output(['osc', 'api', f'/source/{PROJECT}/{PACKAGE}/_meta']))
        build = metadata.find('build')
        if build is None or [e.attrib for e in build.findall('disable')] != [{}] or [e.attrib for e in build.findall('enable')] != [{'repository': '16.0'}]:
            raise ValueError('Expected package builds enabled exclusively for Leap 16.0')
        with urllib.request.urlopen('https://pypi.org/pypi/PyChromecast/json', timeout=60) as response:
            data = json.load(response)
        candidate = candidate_release(data, installed)
        if candidate is None:
            print(f'No newer stable source release (OBS: {installed}).', flush=True)
            return
        release, archive = candidate
        print(f'Testing PyChromecast {installed} -> {release} for Leap 16.0', flush=True)
        original_archives = list(directory.glob('*.tar.gz'))
        target = prepare_sources(directory, release, archive, data)
        # Only the candidate archive belongs in the RPM build context.
        for old in original_archives:
            if old != target:
                run('osc', 'delete', old.name, cwd=directory)
        run('docker', 'pull', 'opensuse/leap:16.0')
        submit_after_validation(directory, target, release, args.apply)


if __name__ == '__main__':
    main()
