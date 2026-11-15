import unittest
from pathlib import Path
from unittest.mock import patch
import xml.etree.ElementTree as ET

from scripts.refresh_pychromecast import candidate_release, update_spec, submit_after_validation, validate_build_scope


SPEC = '''Name: python-PyChromecast
Version: 14.0.5
Source: https://example.test/PyChromecast-%{version}.tar.gz
Requires: python-casttube >= 0.2.0
Requires: python-protobuf >= 3.19.1
Requires: python-zeroconf >= 0.25.1
%prep
%setup -q -n PyChromecast-%{version}
'''


class RefreshTests(unittest.TestCase):
    def test_only_both_supported_leap_repositories_are_enabled(self):
        def metadata(extra=''):
            return ET.fromstring('<package><build><disable/><enable repository="16.0"/>'
                                 '<enable repository="16.1"/>' + extra + '</build></package>')
        validate_build_scope(metadata())
        with self.assertRaises(ValueError):
            validate_build_scope(metadata('<enable repository="openSUSE_Tumbleweed"/>'))
        with self.assertRaises(ValueError):
            validate_build_scope(ET.fromstring('<package><build><enable/></build></package>'))
    def metadata(self, version='14.1.1', **archive):
        return {'info': {'version': version}, 'urls': [
            dict(packagetype='sdist', yanked=False, filename='pychromecast-14.1.1.tar.gz', **archive)]}

    def test_only_new_stable_non_yanked_source_releases(self):
        self.assertIsNotNone(candidate_release(self.metadata(), '14.0.5'))
        for version in ['14.0.5', '14.0.4', '15.0.0rc1', '15.0.0.dev1']:
            self.assertIsNone(candidate_release(self.metadata(version), '14.0.5'))
        data = self.metadata()
        data['urls'][0]['yanked'] = True
        self.assertIsNone(candidate_release(data, '14.0.5'))

    def test_release_updates_dependency_minimums_and_archive_directory(self):
        text = update_spec(SPEC, '14.1.1', 'pychromecast-14.1.1',
                           'https://files.pythonhosted.org/pychromecast-14.1.1.tar.gz',
                           ['casttube>=0.2.0', 'protobuf>=4.25.1', 'zeroconf>=0.128.1'])
        self.assertIn('Version:        14.1.1', text)
        self.assertIn('Requires:       python-protobuf >= 4.25.1', text)
        self.assertIn('%setup -q -n pychromecast-%{version}', text)
        self.assertIn('pychromecast-%{version}.tar.gz', text)
        self.assertNotIn('>= 3.19.1', text)

    def test_unmapped_or_complex_dependencies_require_review(self):
        for dep in ['new-library>=1', 'protobuf>=4,<8', 'protobuf; python_version>="3.12"']:
            with self.assertRaises(ValueError):
                update_spec(SPEC, '14.1.1', 'pychromecast-14.1.1',
                            'https://files.pythonhosted.org/pychromecast-14.1.1.tar.gz', [dep])

    @patch('scripts.refresh_pychromecast.run')
    @patch('scripts.refresh_pychromecast.validate', side_effect=RuntimeError('catt failed'))
    def test_failed_compatibility_check_prevents_obs_submission(self, validate, run):
        with self.assertRaises(RuntimeError):
            submit_after_validation(Path('/candidate'), Path('/candidate/release.tar.gz'), '14.1.1', True)
        run.assert_not_called()

    @patch('scripts.refresh_pychromecast.run')
    @patch('scripts.refresh_pychromecast.validate')
    def test_dry_run_never_submits(self, validate, run):
        submit_after_validation(Path('/candidate'), Path('/candidate/release.tar.gz'), '14.1.1', False)
        validate.assert_called_once()
        run.assert_not_called()


if __name__ == '__main__':
    unittest.main()
