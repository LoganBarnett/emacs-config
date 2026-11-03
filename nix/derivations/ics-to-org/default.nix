{
  cacert,
  coreutils,
  curl,
  ical2orgpy,
  writeShellApplication,
}:
writeShellApplication {
  name = "ics-to-org";
  runtimeInputs = [
    coreutils
    curl
    ical2orgpy
  ];
  # nixpkgs' Darwin curl ships no CA bundle and launchd sets no SSL_CERT_FILE,
  # so the script is told where one lives.
  runtimeEnv.CURL_CA_BUNDLE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
  text = builtins.readFile ./ics-to-org;
}
