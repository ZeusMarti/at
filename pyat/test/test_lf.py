import pytest
import numpy
import scipy


@pytest.mark.skip
def test_numpy_version():
    print(numpy.__version__)
    print(scipy.__version__)
    assert 0
