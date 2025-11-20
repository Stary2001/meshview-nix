{
  stdenv,
  fetchFromGitHub,
  writeScript,
  venv,
  lib,
}:
stdenv.mkDerivation rec {
  pname = "meshview-src";
  version = "2.0.7";

  src = fetchFromGitHub {
    name = "meshview";
    owner = "pablorevilla-meshtastic";
    repo = "meshview";
    rev = "v${version}";
    hash = "sha256-kN5GWDJ44H148BP/QCNFH4K/xe0x+jQG7hxYaOzmSL0=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [
    venv
  ];

  installPhase = ''
    runHook  preInstall
    pushd meshview
    find . -type f -exec install -Dm 755 "{}" "$out/{}" \;
    popd
    runHook postInstall
  '';

  meta = with lib; {
    homepage = "https://github.com/Stary2001/meshview-nix";
    description = "meshview packaged for nixos";
    license = licenses.gpl3;
    platforms = platforms.all;
  };
}