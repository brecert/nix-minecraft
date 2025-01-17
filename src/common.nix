# This file is part of nix-minecraft.

# nix-minecraft is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# nix-minecraft is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with nix-minecraft.  If not, see <https://www.gnu.org/licenses/>.

{ pkgs, lib ? pkgs.lib }:
rec {
  os =
    let
      p = pkgs.stdenv.hostPlatform;
    in
    if p.isLinux then "linux"
    else if p.isWindows then "windows"
    else if p.isMacOS then "osx"
    else throw "unsupported OS";

  isAllowed = rules:
    (
      builtins.elem
        {
          action = "allow";
          os.name = os;
        }
        rules
    )
    || (
      (
        builtins.elem
          {
            action = "allow";
          }
          rules
      ) && (
        !builtins.elem
          {
            action = "disallow";
            os.name = os;
          }
          rules
      )
    );

  fetchJson = { url, sha1 ? "", sha256 ? "", hash ? "" }:
    let
      file = pkgs.fetchurl {
        inherit url sha1 sha256 hash;
      };
      json = builtins.readFile file;
    in
    builtins.fromJSON json;

  mergePkgs = lib.zipAttrsWith
    (
      name: values:
        # concat lists, replace other values
        if lib.all lib.isList values
        then lib.concatLists values
        else lib.head values
    );

  fixOldPkg =
    let
      knownLibs = import ./knownlibs.nix;
    in
    pkg: pkg //
      {
        libraries = map
          (l:
            if l ? downloads.artifact
            then l
            else if knownLibs ? ${l.name}
            then knownLibs.${l.name}
            else if l ? url && l ? checksums
            then {
              inherit (l) name;
              downloads.artifact =
                let
                  inherit (lib) splitString;
                  inherit (builtins) concatStringsSep head tail;
                  parts = splitString ":" l.name;
                in
                {
                  url =
                    l.url
                      + concatStringsSep "/" ((splitString "." (head parts)) ++ (tail parts))
                      + "/"
                      + concatStringsSep "-" (tail parts)
                      + ".jar";
                  sha1 = head l.checksums;
                };
            }
            else { }
          )
          pkg.libraries;
      };
}
