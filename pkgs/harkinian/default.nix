{
  pkgs,
  shipwrightSrc,
  _2ship2harkinianSrc,
}:

let
  createMetadata =
    name: src: version:
    pkgs.runCommandLocal "${name}-src-${version}" { inherit src; } ''
      cp -r $src $out
      chmod -R u+w $out
      echo "" > $out/GIT_BRANCH
      echo "${version}" > $out/GIT_COMMIT_TAG
      echo "${builtins.substring 0 7 src.rev}" > $out/GIT_COMMIT_HASH
    '';
in
{
  shipwright = pkgs.shipwright.overrideAttrs {
    version = shipwrightSrc.version;
    src = createMetadata "shipwright" shipwrightSrc.src shipwrightSrc.version;
  };
  _2ship2harkinian = pkgs._2ship2harkinian.overrideAttrs {
    version = _2ship2harkinianSrc.version;
    src = createMetadata "2ship2harkinian" _2ship2harkinianSrc.src _2ship2harkinianSrc.version;
  };
}
