{ mkDerivation, base, bytestring, containers, exceptions
, hslua-aeson, hslua-classes, hslua-core, hslua-marshalling
, hslua-objectorientation, hslua-packaging, lib, lua, lua-arbitrary
, mtl, QuickCheck, quickcheck-instances, tasty, tasty-hslua
, tasty-hunit, text
}:
mkDerivation {
  pname = "hslua";
  version = "2.2.0";
  src = ./.;
  libraryHaskellDepends = [
    base bytestring containers exceptions hslua-aeson hslua-classes
    hslua-core hslua-marshalling hslua-objectorientation
    hslua-packaging mtl text
  ];
  testHaskellDepends = [
    base bytestring containers exceptions hslua-aeson
    hslua-classes hslua-core hslua-marshalling hslua-objectorientation
    hslua-packaging lua lua-arbitrary mtl QuickCheck
    quickcheck-instances tasty tasty-hslua tasty-hunit text
  ];
  homepage = "https://hslua.org/";
  description = "Bindings to Lua, an embeddable scripting language";
  license = lib.licenses.mit;
}
