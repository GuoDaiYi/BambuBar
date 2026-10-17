---
name: BambuBar GitHub Release
description: Build, sanitize, document and publish a BambuBar macOS release to GitHub, including bilingual screenshots, DMG assets and token cleanup.
---

# BambuBar GitHub Release

Use this skill when iterating on BambuBar and publishing an update to
`GuoDaiYi/BambuBar`.

## Non-negotiable rules

1. Never commit real printer serial numbers, access codes, account names, UIDs,
   local IP addresses, tokens or log files. The demo data in `AppModel.demo`
   must stay fictional.
2. `README.md` is English-only: English prose and only `docs/en/*` screenshots.
   `README.zh-CN.md` is Chinese-only: Chinese prose and only `docs/zh/*`
   screenshots.
3. The app must stay a native `LSUIElement` menu bar app. Do not add a Dock icon.
4. The release must contain a universal (x86_64 + arm64) app, a DMG and a ZIP.
5. Never print a PAT or put it in a URL, commit, shell history or chat. Revoke it
   when publishing is done.

## Workflow

### 1. Implement and verify locally

```bash
cd /path/to/BambuBar
./build.sh                 # universal app
./Tools/snapshot.sh        # renders zh + en screenshots into /tmp/bambubar-shots
```

Copy the screenshots to the correct language folder:

```bash
cp /tmp/bambubar-shots/zh/*.png docs/zh/
cp /tmp/bambubar-shots/en/*.png docs/en/
```

Check that the UI is landscape for the main popover (`DashboardView` frame is
`784 × 500`), and that `PopoverEntrance` only animates on its own popover's
appearance. Do not observe global `NSWindow` key notifications; opening the
Settings window must not replay the animation.

### 2. Bump the version

Update both version values in `Info.plist`, then update the version badge and
asset names in both READMEs:

```bash
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Info.plist
```

Create `docs/release-notes-<version>.md` with the changelog. Keep the previous
release notes; do not rewrite history.

### 3. Build release artifacts

```bash
./release.sh
```

This produces:

```text
build/BambuBar-<version>-macOS.dmg
build/BambuBar-<version>-macOS.zip
```

Verify:

```bash
lipo -info build/BambuBar.app/Contents/MacOS/BambuBar
codesign --verify --deep --strict build/BambuBar.app
hdiutil verify build/BambuBar-<version>-macOS.dmg
shasum -a 256 build/BambuBar-<version>-macOS.*
```

### 4. Sanitize before every commit

Run:

```bash
grep -rInE "<real-serial>|<real-access-code>|<real-uid>|<real-device-name>|ghp_|github_pat_|<local-user>" \
  . --exclude-dir=.git --exclude-dir=build
```

Use the current real values from the user's environment, or simply search for
anything that looks like a Bambu serial (`0[0-9A-Z]{15}`), an 8-character hex
access code, `ghp_`, `ghu_` and the local username. Also scan binaries:

```bash
grep -rIal "ghp_\|github_pat_" docs Assets Sources
```

### 5. Commit and push

```bash
git add -A
git commit -m "Release <version>: <summary>"
git config http.version HTTP/1.1
cat > /tmp/bambubar_askpass.sh <<'EOF'
#!/bin/sh
case "$1" in
  *Username*) printf '%s' "GuoDaiYi" ;;
  *Password*) cat "$HOME/.bambubar_pat" ;;
esac
EOF
chmod 700 /tmp/bambubar_askpass.sh
GIT_ASKPASS=/tmp/bambubar_askpass.sh GIT_TERMINAL_PROMPT=0 \
  git -c credential.helper= push origin main
```

Why these flags:

- GitHub sometimes returns `RPC failed; HTTP 400` for this repo's pack. Use
  `http.version HTTP/1.1` and a large `http.postBuffer`.
- The system `osxkeychain` helper can supply a stale token. `-c credential.helper=`
  forces `GIT_ASKPASS`.

### 6. Create the GitHub release

Use the API with the temporary PAT:

- `POST /repos/GuoDaiYi/BambuBar/releases` with `tag_name: v<version>`,
  `target_commitish: main`, bilingual release notes, `draft: false`.
- Upload `BambuBar-<version>-macOS.dmg` and `.zip` to
  `https://uploads.github.com/repos/GuoDaiYi/BambuBar/releases/{id}/assets?name=...`.
- Append SHA-256 checksums to the release body.
- Verify the direct asset URLs return HTTP 200.

### 7. Clean up credentials

1. Open `https://github.com/settings/tokens` in the OpenCode browser, find the
   token named for this release, click **Delete**, confirm.
2. Remove `~/.bambubar_pat`, `/tmp/bambubar_askpass.sh`, any local token server
   script and any temporary session file.
3. Clear the clipboard: `printf '' | pbcopy`.
4. Confirm `git remote -v` contains no credentials.

## Browser-only authentication (no PAT from chat)

The preferred flow when the OpenCode browser is already signed in to GitHub:

1. Open `https://github.com/settings/tokens/new?scopes=repo,workflow&description=BambuBar%20release%20<version>`.
2. Confirm `repo` and `workflow` are checked, then click **Generate token**.
3. Read the new token from `#new-oauth-token` with `browser.evaluate`, and send it
   to a tiny loopback server (127.0.0.1) that writes it to `~/.bambubar_pat`
   with mode `0600`. Do not return the token in tool output.
4. Proceed with the git/API steps.
5. Revoke the token in the browser when done.

A working loopback receiver is documented in
`references/github-browser-auth.md`.

## README checklist

- English README: no CJK characters, no Chinese screenshots, no Chinese links.
- Chinese README: Chinese sections and `docs/zh/*` screenshots only.
- Both mention the same version and DMG filename.
- Release notes are linked from the README or the GitHub Release.
- Screenshots show fictional demo serials/access codes.

## Final verification

```bash
# local
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" build/BambuBar.app/Contents/Info.plist
lipo -info build/BambuBar.app/Contents/MacOS/BambuBar

# remote
curl -s https://api.github.com/repos/GuoDaiYi/BambuBar/releases/latest
curl -s https://api.github.com/repos/GuoDaiYi/BambuBar/actions/runs
```

Deliver the repository URL, release URL, direct DMG URL, version, and a short
list of changes to the user.
