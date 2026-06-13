# Inside FHS environments, swap stable libdrm for libdrm-git.
#
# Requires libdrm-git / libdrm32-git in the final package set, so apply this
# alongside the mesa-git overlay (overlays.mesa-git or overlays.default).
final: prev:
let
  lib = final.lib;

  # match libdrm to arch or the 64-bit lib lands in the 32-bit path
  withLibdrmGit =
    p:
    if p.stdenv.hostPlatform.is32bit then
      p.extend (_: _: { libdrm = final.libdrm32-git; })
    else
      p.extend (
        _: prev': {
          libdrm = final.libdrm-git;
          pkgsi686Linux = prev'.pkgsi686Linux.extend (
            _: _: {
              libdrm = final.libdrm32-git;
            }
          );
        }
      );

  # Returns a callable attrset (functor) that preserves `.override`.
  # A plain function loses `.override`, so that callsite fails with "expected a set but found a function".
  wrapFhsEnv =
    orig:
    let
      wrap =
        args:
        orig (
          args
          // lib.optionalAttrs (args ? targetPkgs) {
            targetPkgs = p: args.targetPkgs (withLibdrmGit p);
          }
          // lib.optionalAttrs (args ? multiPkgs) {
            multiPkgs = p: args.multiPkgs (withLibdrmGit p);
          }
        );
    in
    {
      __functor = _: wrap;
    }
    // lib.optionalAttrs (orig ? override) {
      override = newArgs: wrapFhsEnv (orig.override newArgs);
    };
in
{
  # buildFHSEnv is an alias; some packages call it directly, wrap both.
  buildFHSEnv = wrapFhsEnv prev.buildFHSEnv;
  buildFHSEnvBubblewrap = wrapFhsEnv prev.buildFHSEnvBubblewrap;
}
