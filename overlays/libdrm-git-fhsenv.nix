# Inside FHS environments, make libdrm-git shadow the stable libdrm.
# Requires libdrm-git / libdrm32-git in the final package set, so apply this
# alongside the mesa-git overlay (overlays.mesa-git or overlays.default).
final: prev:
let
  lib = final.lib;

  # match libdrm to arch or the 64-bit lib lands in the 32-bit path
  libdrmGitFor = p: if p.stdenv.hostPlatform.is32bit then final.libdrm32-git else final.libdrm-git;

  addLibdrmGit = pkgList: p: pkgList p ++ [ (lib.setPrio 4 (libdrmGitFor p)) ];

  # Same soname list the mesa-git module preloads host-side.
  preloadProfile = ''
    export LD_PRELOAD="libdrm.so.2 libdrm_amdgpu.so.1 libdrm_radeon.so.1 libdrm_intel.so.1 libdrm_nouveau.so.2''${LD_PRELOAD:+ $LD_PRELOAD}"
  '';

  # Inject whether or not the caller set targetPkgs/multiPkgs, so envs that
  # only pull stable libdrm in via includeClosures are covered too.
  transformArgs =
    args:
    args
    // {
      targetPkgs = addLibdrmGit (args.targetPkgs or (pkgs: [ ]));
      profile = (args.profile or "") + "\n" + preloadProfile;
    }
    // lib.optionalAttrs (args.multiPkgs or (pkgs: [ ]) != null) {
      multiPkgs = addLibdrmGit (args.multiPkgs or (pkgs: [ ]));
    };

  # buildFHSEnv accepts an attrset and/or a fixed-point function (finalAttrs).
  # Previous overlay did not account for finalAttrs and would break certain FHS derivations
  wrapFhsEnv =
    orig:
    if lib.isAttrs orig && orig ? __libdrmGitFhsenv then
      orig
    else
      let
        wrap =
          fpargs:
          orig (
            if lib.isFunction fpargs then
              finalAttrs: transformArgs (fpargs finalAttrs)
            else
              transformArgs fpargs
          );
      in
      (lib.optionalAttrs (lib.isAttrs orig) orig)
      // {
        __functor = _: wrap;
        __libdrmGitFhsenv = true;
      }
      // lib.optionalAttrs (lib.isAttrs orig && orig ? override) {
        override = newArgs: wrapFhsEnv (orig.override newArgs);
      };
in
{
  # buildFHSEnv is an alias; some packages call it directly, wrap both.
  buildFHSEnv = wrapFhsEnv prev.buildFHSEnv;
  buildFHSEnvBubblewrap = wrapFhsEnv prev.buildFHSEnvBubblewrap;
}
