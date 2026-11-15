import os
import sys
import unittest

def suite():
    loader = unittest.TestLoader()
    start_dir = os.path.dirname(__file__)
    return loader.discover(start_dir, pattern='test_seam*.py')

if __name__ == '__main__':
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite())
    sys.exit(0 if result.wasSuccessful() else 1)
