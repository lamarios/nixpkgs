{ lib, stdenv, beamPackages, fetchFromGitHub, glibcLocales, cacert
, mkYarnModules, nodejs, fetchpatch, nixosTests
}:

let
  pname = "plausible";
  version = "1.3.0";
  name = "${pname}-${version}";

  src = fetchFromGitHub {
    owner = "plausible";
    repo = "analytics";
    rev = "v${version}";
    sha256 = "03lm1f29gwwixnhgjish5bhi3m73qyp71ns2sczdnwnbhrw61zps";
  };

  # TODO consider using `mix2nix` as soon as it supports git dependencies.
  mixFodDeps = beamPackages.fetchMixDeps {
    pname = "${pname}-deps";
    inherit src version;
    sha256 = "sha256-pv/zXcku+ZgxV1804kIfDZN0jave2qG3rgZwm4yGA6I=";
    patches = [ ./ecto_sql-fix.patch ];
  };

  yarnDeps = mkYarnModules {
    pname = "${pname}-yarn-deps";
    inherit version;
    packageJSON = ./package.json;
    yarnNix = ./yarn.nix;
    yarnLock = ./yarn.lock;
    preBuild = ''
      mkdir -p tmp/deps
      cp -r ${mixFodDeps}/phoenix tmp/deps/phoenix
      cp -r ${mixFodDeps}/phoenix_html tmp/deps/phoenix_html
    '';
    postBuild = ''
      echo 'module.exports = {}' > $out/node_modules/flatpickr/dist/postcss.config.js
    '';
  };
in beamPackages.mixRelease {
  inherit pname version src mixFodDeps;

  nativeBuildInputs = [ nodejs ];

  patches = [
    # Allow socket-authentication against postgresql. Upstream PR is
    # https://github.com/plausible/analytics/pull/1052
    (fetchpatch {
      url = "https://github.com/Ma27/analytics/commit/f2ee5892a6c3e1a861d69ed30cac43e05e9cd36f.patch";
      sha256 = "sha256-JvJ7xlGw+tHtWje+jiQChVC4KTyqqdq2q+MIcOv/k1o=";
    })

    # CREATE EXTENSION requires super-user privileges. To avoid that, we just skip
    # the responsible SQL statement here and take care of it in the module.
    ./skip-create-ext.patch
  ];

  passthru = {
    tests = { inherit (nixosTests) plausible; };
    updateScript = ./update.sh;
  };

  postPatch = ''
    # Without this modification, tzdata tries to write in its store-path:
    # https://github.com/lau/tzdata#data-directory-and-releases
    echo 'config :tzdata, :data_dir, (System.get_env("PLAUSIBLE_TZDATA") || "/tmp/plausible_tzdata")' \
      >> config/config.exs
  '';

  buildPhase = ''
    runHook preBuild

    mkdir -p $out
    ln -sf ${yarnDeps}/node_modules assets/node_modules
    mix deps.compile --path $out --no-deps-check
    mix compile --no-deps-check --path $out

    npm run deploy --prefix ./assets
    mix release plausible --no-deps-check --path $out

    runHook postBuild
  '';

  meta = with lib; {
    license = licenses.agpl3Plus;
    homepage = "https://plausible.io/";
    description = " Simple, open-source, lightweight (< 1 KB) and privacy-friendly web analytics alternative to Google Analytics.";
    maintainers = with maintainers; [ ma27 ];
    platforms = platforms.linux;
  };
}
