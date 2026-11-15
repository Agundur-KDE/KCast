# OBS dependency RPM maintenance

KCast uses third-party projects. We maintain their RPM packaging, not forks of
their upstream application or library code.

- `catt-refresh.yml` runs weekly and retriggers the existing unpinned upstream
  Git source service for `home:Agundur/catt`.
- `pychromecast-refresh.yml` checks PyPI daily at 04:23 UTC for a newer stable,
  non-yanked PyChromecast source release. It updates
  `home:Agundur/python-PyChromecast`, enabled exclusively for Leap 16.0.
  Tumbleweed continues to use its distribution package.

The PyChromecast job verifies the source archive against its PyPI SHA-256 and
checks its package/version/dependency metadata. It updates the version, source
archive layout and RPM runtime dependency minimums. Unknown dependencies,
conditional requirements or complex version constraints stop the job for
packaging review.

Before submitting anything, the job builds the actual candidate RPM inside a
fresh Leap 16.0 x86_64 container. It installs `catt` from our repository, installs
the candidate RPM, checks Python dependencies, runs `catt --version` and
`catt --help`, and imports the controller APIs. Repository dependencies use
normal signature checks; the locally built candidate is unsigned.
These are installation and CLI/API smoke checks, not device playback tests.

Only after successful checks does the job commit the sources to OBS. It then
waits for the submitted source checksum to build and publish on both Leap
architectures, checking the resulting RPM version. Failed checks or unresolved
builds fail the workflow, and its log is retained as a GitHub Actions artifact.
OBS publication follows its normal per-architecture process; a subsequent
failure does not automatically roll back an already submitted or published RPM.

The workflow uses the existing KCast `OBS_USER` and `OBS_PASSWORD` secrets. It
does not modify upstream repositories, the user's host installation, or the
`python-casttube` package. If a future release requires a newer casttube or other
unavailable RPM, the preflight fails for review.

Manual runs default to a dry run:

```bash
gh workflow run pychromecast-refresh.yml --ref main -f apply=false
# Submit a tested update and monitor publication:
gh workflow run pychromecast-refresh.yml --ref main -f apply=true
```

Local development (Python 3.11+, packaging, osc credentials and Docker needed):

```bash
python3 -m unittest discover -s tests -p 'test_pychromecast_refresh.py'
python3 scripts/refresh_pychromecast.py
python3 scripts/refresh_pychromecast.py --apply
```
