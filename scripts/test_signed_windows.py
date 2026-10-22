import pathlib
import struct
import tempfile
import unittest
import zipfile

from verify_signed_windows import verify_payload, verify_pe_change, zip_payload


def executable():
    data = bytearray(512)
    data[:2] = b'MZ'
    struct.pack_into('<I', data, 60, 64)
    data[64:68] = b'PE\0\0'
    struct.pack_into('<H', data, 88, 0x20b)
    data[400:404] = b'CODE'
    return bytes(data)


def signed_executable(original):
    data = bytearray(original)
    struct.pack_into('<I', data, 152, 1234)
    struct.pack_into('<II', data, 232, len(data), 8)
    return bytes(data) + b'FAKECERT'


class SignedPackageTests(unittest.TestCase):
    def test_only_authenticode_fields_may_change(self):
        original = executable()
        signed = signed_executable(original)
        verify_pe_change(original, signed)
        changed = bytearray(signed)
        changed[400] ^= 1
        with self.assertRaisesRegex(ValueError, 'content changed'):
            verify_pe_change(original, changed)
        with self.assertRaisesRegex(ValueError, 'certificate table'):
            verify_pe_change(original, original)
        with self.assertRaisesRegex(ValueError, 'certificate table'):
            verify_pe_change(original, signed + b'EXTRA')

    def test_other_files_and_file_lists_must_match(self):
        original = {'omniquiz.exe': executable(), 'flutter_windows.dll': b'upstream'}
        signed = dict(original, **{'omniquiz.exe': signed_executable(original['omniquiz.exe'])})
        verify_payload(original, signed)
        signed['flutter_windows.dll'] = b'modified'
        with self.assertRaisesRegex(ValueError, 'Unexpected payload'):
            verify_payload(original, signed)
        signed['extra.exe'] = b'new'
        with self.assertRaisesRegex(ValueError, 'file list'):
            verify_payload(original, signed)

    def test_archive_paths_cannot_escape_or_collide(self):
        with tempfile.TemporaryDirectory() as temporary:
            archive = pathlib.Path(temporary) / 'package.zip'
            for names in (['../outside.exe'], ['A.exe', 'a.exe'], ['C:/outside.exe']):
                with zipfile.ZipFile(archive, 'w') as output:
                    for name in names:
                        output.writestr(name, b'data')
                with self.assertRaises(ValueError):
                    zip_payload(archive)


if __name__ == '__main__':
    unittest.main()
