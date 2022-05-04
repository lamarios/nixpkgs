{ lib
, buildPythonPackage
, fetchPypi
, glyphslib
, setuptools-scm
, ufo2ft
, fonttools
, fontmath
, lxml
, setuptools
}:

buildPythonPackage rec {
  pname = "fontmake";
  version = "3.3.0";

  src = fetchPypi {
    inherit pname version;
    sha256 = "sha256-lD7MvZdr9CeWdoZtD3+8stVJTeQN5/AQ4miA/I2TFoE=";
    extension = "zip";
  };

  nativeBuildInputs = [ setuptools-scm ];

  propagatedBuildInputs = [
    glyphslib
    ufo2ft
    fonttools
    fontmath
    lxml
    setuptools
  ];

  pythonImportsCheck = [ "fontmake" ];

  meta = {
    description = "Compiles fonts from various sources (.glyphs, .ufo, designspace) into binaries formats (.otf, .ttf)";
    homepage = "https://github.com/googlefonts/fontmake";
    license = lib.licenses.asl20;
    maintainers = [ lib.maintainers.BarinovMaxim ];
  };
}
