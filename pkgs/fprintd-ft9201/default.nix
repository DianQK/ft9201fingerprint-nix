{ lib
, stdenv
, fetchFromGitLab
, fetchurl
, fetchpatch
, pkg-config
, meson
, ninja
, gusb
, cairo
, perl
, libgudev
, pixman
, autoPatchelfHook
, zstd
, libusb1
, gettext
, gtk-doc
, libxslt
, gobject-introspection
, coreutils
, docbook-xsl-nons
, docbook_xsl
, docbook_xml_dtd_412
, docbook_xml_dtd_43
, glib
, dbus
, dbus-glib
, polkit
, nss
, pam
, systemd
, python3
, fprintd
,
}:
let
  gusb-0-3 = stdenv.mkDerivation rec {
    pname = "gusb";
    version = "0.3.10";

    outputs = [ "out" ];

    src = fetchurl {
      url = "https://github.com/DianQK/ft9201fingerprint-nix/releases/download/assets/libgusb2_0.3.10-1_amd64.deb";
      sha256 = "sha256-chpHYiaDFLDtBbNMxXdBrJQlTOc0TLjL2mshiA4npvA=";
    };

    nativeBuildInputs = [ autoPatchelfHook pkg-config zstd ];
    unpackPhase = ''
      ar x ${src}
      tar -I zstd -xf data.tar.zst
    '';

    buildInputs = [ glib ];

    propagatedBuildInputs = [ libusb1 ];

    installPhase = ''
      install -dm 0755 "$out/lib/"

      install -Dm 0755 usr/lib/x86_64-linux-gnu/libgusb.so.2.0.10 "$out/lib/"
      install -Dm 0755 usr/lib/x86_64-linux-gnu/libgusb.so.2 "$out/lib/"
    '';

    doCheck = false;
  };

  ft9201-deb = fetchurl {
    url = "https://github.com/DianQK/ft9201fingerprint-nix/releases/download/assets/libfprint_2_2_1_90_1+tod1_0ubuntu120_04_2_amd64_16c6e64404f8411.deb";
    sha256 = "sha256-qVrNeDps9tEwlZXQh1i14pWerICSBNVTmcyu9iDNPrw=";
  };

  # https://github.com/NixOS/nixpkgs/blob/master/pkgs/tools/security/fprintd/tod.nix#L38
  libfprint-ft9201 = stdenv.mkDerivation rec {
    pname = "libfprint-ft9201";
    version = "1.90.1";
    outputs = [ "out" "devdoc" ];

    src = fetchFromGitLab {
      domain = "gitlab.freedesktop.org";
      owner = "libfprint";
      repo = pname;
      rev = "v${version}";
      sha256 = "0fdaak7qjr9b4482g7fhhqpyfdqpxq5kpmyzkp7f5i7qq2ynb78a";
    };

    nativeBuildInputs = [
      pkg-config
      meson
      ninja
      gtk-doc
      docbook_xsl
      docbook_xml_dtd_43
      gobject-introspection
    ];

    buildInputs = [ gusb pixman glib nss ];

    NIX_CFLAGS_COMPILE = "-Wno-error=array-bounds";

    mesonFlags = [ "-Dudev_rules_dir=${placeholder "out"}/lib/udev/rules.d" ];

    preFixup =
      let
        libPath = lib.makeLibraryPath [ glib gusb-0-3 pixman nss cairo libgudev ];
      in
      ''
          ar x ${ft9201-deb}
        tar xf data.tar.xz
          cp usr/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0 $out/lib/
          cp lib/udev/rules.d/60-libfprint-2.rules $out/lib/udev/rules.d/
          patchelf --set-rpath ${libPath} $out/lib/libfprint-2.so.2.0.0
      '';
    meta = with lib; {
      homepage = "https://github.com/DianQK/ft9201fingerprint-nix";
      description = "A library designed to make it easy to add support for consumer fingerprint readers";
      license = licenses.lgpl21;
      platforms = platforms.linux;
      maintainers = with maintainers; [ DianQK ];
    };
  };
in


(fprintd.override { libfprint = libfprint-ft9201; }).overrideAttrs (oldAttrs: rec {
  pname = "fprintd-ft9201";
  version = "1.90.1";

  src = fetchFromGitLab {
    domain = "gitlab.freedesktop.org";
    owner = "libfprint";
    repo = pname;
    rev = version;
    sha256 = "0mbzk263x7f58i9cxhs44mrngs7zw5wkm62j5r6xlcidhmfn03cg";
  };

  buildInputs = oldAttrs.buildInputs ++ [ dbus-glib ];

  patches = [
    # Fixes issue with ":" when there is multiple paths (might be the case on NixOS)
    # https://gitlab.freedesktop.org/libfprint/fprintd/-/merge_requests/50
    (fetchpatch {
      url = "https://gitlab.freedesktop.org/libfprint/fprintd/-/commit/d7fec03f24d10f88d34581c72f0eef201f5eafac.patch";
      sha256 = "0f88dhizai8jz7hpm5lpki1fx4593zcy89iwi4brsqbqc7jp9ls0";
    })

    # Fix locating libpam_wrapper for tests
    (fetchpatch {
      url = "https://gitlab.freedesktop.org/libfprint/fprintd/-/merge_requests/40.patch";
      sha256 = "0qqy090p93lzabavwjxzxaqidkcb3ifacl0d3yh1q7ms2a58yyz3";
    })
    (fetchpatch {
      url = "https://gitlab.freedesktop.org/libfprint/fprintd/-/commit/f401f399a85dbeb2de165b9b9162eb552ab6eea7.patch";
      sha256 = "1bc9g6kc95imlcdpvp8qgqjsnsxg6nipr6817c1pz5i407yvw1iy";
    })
    (fetchpatch {
      name = "use-more-idiomatic-correct-embedded-shell-scripting";
      url = "https://gitlab.freedesktop.org/libfprint/fprintd/-/commit/f4256533d1ffdc203c3f8c6ee42e8dcde470a93f.patch";
      sha256 = "sha256-4uPrYEgJyXU4zx2V3gwKKLaD6ty0wylSriHlvKvOhek=";
    })
    # (fetchpatch {
    #   name = "remove-pointless-copying-of-files-into-build-directory";
    #   url = "https://gitlab.freedesktop.org/libfprint/fprintd/-/commit/2c34cef5ef2004d8479475db5523c572eb409a6b.patch";
    #   sha256 = "sha256-2pZBbMF1xjoDKn/jCAIldbeR2JNEVduXB8bqUrj2Ih4=";
    # })
    (fetchpatch {
      name = "build-Do-not-use-positional-arguments-in-i18n.merge_file";
      url = "https://gitlab.freedesktop.org/libfprint/fprintd/-/commit/50943b1bd4f18d103c35233f0446ce7a31d1817e.patch";
      sha256 = "sha256-ANkAq6fr0VRjkS0ckvf/ddVB2mH4b2uJRTI4H8vPPes=";
    })
  ];

  meta = with lib; {
    homepage = "https://fprint.freedesktop.org/";
    description = "D-Bus daemon that offers libfprint functionality over the D-Bus interprocess communication bus";
    license = licenses.gpl2;
    platforms = platforms.linux;
    maintainers = with maintainers; [ DianQK ];
  };
})
