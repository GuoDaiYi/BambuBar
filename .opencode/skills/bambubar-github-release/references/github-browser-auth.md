# Browser-only GitHub authentication

Use this when the OpenCode browser is already signed in to GitHub and no PAT is
available. The goal is to create a short-lived classic PAT without copying the
token through chat.

## 1. Start a loopback receiver

Create `/tmp/bambubar_token_server.py`:

```python
import http.server, os, urllib.parse

TOKEN_PATH = os.path.expanduser("~/.bambubar_pat")

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/token":
            value = (urllib.parse.parse_qs(parsed.query).get("value") or [""])[0].strip()
            if value.startswith(("ghp_", "github_pat_")):
                fd = os.open(TOKEN_PATH, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
                with os.fdopen(fd, "w") as f:
                    f.write(value)
                self.send_response(200)
                body = b"ok"
            else:
                self.send_response(400)
                body = b"bad token"
        else:
            self.send_response(200)
            body = b"ready"
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass

http.server.HTTPServer(("127.0.0.1", 8765), Handler).serve_forever()
```

Run it in the background and verify `curl http://127.0.0.1:8765/` returns `ready`.

## 2. Create the PAT in the browser

Open:

```text
https://github.com/settings/tokens/new?scopes=repo,workflow&description=BambuBar%20release%20<version>
```

Check that `repo` and `workflow` are selected, then click **Generate token**.

## 3. Transfer it without printing it

With `browser.evaluate` on the token page:

```js
(() => {
  const token = document.querySelector("#new-oauth-token").textContent.trim();
  location.href = "http://127.0.0.1:8765/token?value=" + encodeURIComponent(token);
  return "transferred";
})()
```

The token is written to `~/.bambubar_pat` with mode `0600`. Verify the file
exists and is 40+ characters; do not print its contents.

## 4. Use it, then revoke it

Use `GIT_ASKPASS` and the GitHub API, then delete the PAT from
<https://github.com/settings/tokens>, remove the local file and clear the
clipboard.
