{ mkDerivation, base, bytestring, containers, exceptions
, hslua-classes, hslua-core, hslua-marshalling
, hslua-objectorientation, hslua-packaging, lib, mtl, tasty
, tasty-hslua, tasty-hunit, text
}:
mkDerivation {
  pname = "hslua";
  version = "2.1.0";
  src = ./.;
  libraryHaskellDepends = [
    base bytestring containers exceptions hslua-classes hslua-core
    hslua-marshalling hslua-objectorientation hslua-packaging mtl text
  ];
  homepage = "https://hslua.org/";
  description = "Bindings to Lua, an embeddable scripting language";
  license = lib.licenses.mit;
  doCheck = false;
}
