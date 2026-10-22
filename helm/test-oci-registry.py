#!/usr/bin/env python3
"""
Lightweight, standalone OCI Distribution Spec v1.0/v2.0 test registry for Helm charts.
Uses standard Python library (no external dependencies required).
Enables offline/local testing of:
  - helm registry login
  - helm push <chart>.tgz oci://localhost:<port>/<repo>
  - helm pull oci://localhost:<port>/<repo>/<chart> --version <version>
  - helm install <release> oci://localhost:<port>/<repo>/<chart> --version <version> --dry-run
"""

import argparse
import hashlib
import http.server
import json
import os
import signal
import socketserver
import sys
import urllib.parse

class InMemoryOCIRegistry:
    def __init__(self, storage_dir=None):
        self.storage_dir = storage_dir
        self.blobs = {}      # digest -> bytes
        self.manifests = {}  # repo:tag -> bytes & repo:digest -> bytes
        self.tags = {}       # repo -> set(tags)
        self.uploads = {}    # upload_id -> bytearray

    def put_blob(self, repo, digest, data):
        self.blobs[digest] = data
        if self.storage_dir:
            blob_path = os.path.join(self.storage_dir, "blobs", digest.replace(":", "_"))
            os.makedirs(os.path.dirname(blob_path), exist_ok=True)
            with open(blob_path, "wb") as f:
                f.write(data)

    def get_blob(self, repo, digest):
        return self.blobs.get(digest)

    def put_manifest(self, repo, ref, data):
        digest = "sha256:" + hashlib.sha256(data).hexdigest()
        self.manifests[f"{repo}:{ref}"] = data
        self.manifests[f"{repo}:{digest}"] = data
        if not ref.startswith("sha256:"):
            if repo not in self.tags:
                self.tags[repo] = set()
            self.tags[repo].add(ref)
        if self.storage_dir:
            mf_path = os.path.join(self.storage_dir, "manifests", repo, ref.replace(":", "_"))
            os.makedirs(os.path.dirname(mf_path), exist_ok=True)
            with open(mf_path, "wb") as f:
                f.write(data)
        return digest

    def get_manifest(self, repo, ref):
        return self.manifests.get(f"{repo}:{ref}")

    def list_tags(self, repo):
        return sorted(list(self.tags.get(repo, set())))


def create_handler(registry, verbose=False):
    class OCIRequestHandler(http.server.BaseHTTPRequestHandler):
        def log_message(self, format, *args):
            if verbose:
                super().log_message(format, *args)

        def send_oci(self, status_code, content_type="application/json", headers=None, body=b""):
            self.send_response(status_code)
            self.send_header("Docker-Distribution-API-Version", "registry/2.0")
            if content_type:
                self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            if headers:
                for k, v in headers.items():
                    self.send_header(k, str(v))
            self.end_headers()
            if body and self.command != "HEAD":
                self.wfile.write(body)

        def parse_repo_and_subpath(self, path, keyword):
            # path is /v2/<repo>/<keyword>/<remainder>
            prefix = "/v2/"
            if not path.startswith(prefix):
                return None, None
            sub = path[len(prefix):]
            target = f"/{keyword}/"
            if target not in sub:
                if sub.endswith(f"/{keyword}"):
                    repo = sub[:-len(f"/{keyword}")]
                    return repo, ""
                return None, None
            parts = sub.split(target, 1)
            return parts[0], parts[1]

        def do_HEAD(self):
            parsed = urllib.parse.urlparse(self.path)
            path = parsed.path.rstrip("/")
            if path == "/v2":
                self.send_oci(200)
                return

            if "/blobs/" in path:
                repo, digest = self.parse_repo_and_subpath(path, "blobs")
                data = registry.get_blob(repo, digest)
                if data is not None:
                    self.send_oci(200, "application/octet-stream", {
                        "Docker-Content-Digest": digest,
                        "ETag": f'"{digest}"'
                    }, body=b"")
                    return
                self.send_oci(404, body=b'{"errors":[{"code":"BLOB_UNKNOWN"}]}')
                return

            if "/manifests/" in path:
                repo, ref = self.parse_repo_and_subpath(path, "manifests")
                data = registry.get_manifest(repo, ref)
                if data is not None:
                    digest = "sha256:" + hashlib.sha256(data).hexdigest()
                    self.send_oci(200, "application/vnd.oci.image.manifest.v1+json", {
                        "Docker-Content-Digest": digest,
                        "ETag": f'"{digest}"'
                    }, body=b"")
                    return
                self.send_oci(404, body=b'{"errors":[{"code":"MANIFEST_UNKNOWN"}]}')
                return

            self.send_oci(404)

        def do_GET(self):
            parsed = urllib.parse.urlparse(self.path)
            path = parsed.path.rstrip("/")
            if path in ("/v2", "/v2/"):
                self.send_oci(200, body=b"{}")
                return

            if path == "/shutdown":
                self.send_oci(200, body=b'{"status":"shutting down"}')
                threading.Thread(target=self.server.shutdown).start()
                return

            if "/tags/list" in path:
                repo = path[len("/v2/"):path.index("/tags/list")]
                tags = registry.list_tags(repo)
                body = json.dumps({"name": repo, "tags": tags}).encode("utf-8")
                self.send_oci(200, "application/json", body=body)
                return

            if "/blobs/" in path:
                repo, digest = self.parse_repo_and_subpath(path, "blobs")
                data = registry.get_blob(repo, digest)
                if data is not None:
                    self.send_oci(200, "application/octet-stream", {
                        "Docker-Content-Digest": digest
                    }, body=data)
                    return
                self.send_oci(404, body=b'{"errors":[{"code":"BLOB_UNKNOWN"}]}')
                return

            if "/manifests/" in path:
                repo, ref = self.parse_repo_and_subpath(path, "manifests")
                data = registry.get_manifest(repo, ref)
                if data is not None:
                    digest = "sha256:" + hashlib.sha256(data).hexdigest()
                    self.send_oci(200, "application/vnd.oci.image.manifest.v1+json", {
                        "Docker-Content-Digest": digest
                    }, body=data)
                    return
                self.send_oci(404, body=b'{"errors":[{"code":"MANIFEST_UNKNOWN"}]}')
                return

            self.send_oci(404, body=b'{"errors":[{"code":"NOT_FOUND"}]}')

        def do_POST(self):
            parsed = urllib.parse.urlparse(self.path)
            path = parsed.path.rstrip("/")
            if "/blobs/uploads" in path:
                repo, remainder = self.parse_repo_and_subpath(path, "blobs")
                upload_id = hashlib.sha256(f"{repo}:{len(registry.uploads)}".encode()).hexdigest()[:16]
                registry.uploads[upload_id] = bytearray()
                loc = f"/v2/{repo}/blobs/uploads/{upload_id}"
                self.send_oci(202, headers={
                    "Location": loc,
                    "Range": "0-0",
                    "Docker-Upload-UUID": upload_id
                })
                return
            self.send_oci(404)

        def do_PATCH(self):
            parsed = urllib.parse.urlparse(self.path)
            path = parsed.path.rstrip("/")
            upload_id = path.split("/")[-1]
            length = int(self.headers.get("Content-Length", 0))
            chunk = self.rfile.read(length) if length > 0 else b""
            if upload_id in registry.uploads:
                registry.uploads[upload_id].extend(chunk)
                current_len = len(registry.uploads[upload_id])
                self.send_oci(202, headers={
                    "Location": self.path,
                    "Range": f"0-{current_len}",
                    "Docker-Upload-UUID": upload_id
                })
                return
            self.send_oci(404)

        def do_PUT(self):
            parsed = urllib.parse.urlparse(self.path)
            path = parsed.path.rstrip("/")
            query = urllib.parse.parse_qs(parsed.query)
            length = int(self.headers.get("Content-Length", 0))
            data = self.rfile.read(length) if length > 0 else b""

            if "/blobs/uploads/" in path:
                repo = path[len("/v2/"):path.index("/blobs/uploads/")]
                upload_id = path.split("/")[-1]
                buf = registry.uploads.get(upload_id, bytearray())
                buf.extend(data)
                digest = query.get("digest", [""])[0]
                if not digest:
                    digest = "sha256:" + hashlib.sha256(buf).hexdigest()
                registry.put_blob(repo, digest, bytes(buf))
                if upload_id in registry.uploads:
                    del registry.uploads[upload_id]
                self.send_oci(201, headers={
                    "Location": f"/v2/{repo}/blobs/{digest}",
                    "Docker-Content-Digest": digest
                })
                return

            if "/manifests/" in path:
                repo, ref = self.parse_repo_and_subpath(path, "manifests")
                digest = registry.put_manifest(repo, ref, data)
                self.send_oci(201, headers={
                    "Location": f"/v2/{repo}/manifests/{ref}",
                    "Docker-Content-Digest": digest
                })
                return

            self.send_oci(404)

    return OCIRequestHandler

def main():
    parser = argparse.ArgumentParser(description="TitanOps OCI Test Registry for Helm")
    parser.add_argument("--port", type=int, default=5055, help="Port to listen on (default: 5055)")
    parser.add_argument("--host", type=str, default="127.0.0.1", help="Host interface (default: 127.0.0.1)")
    parser.add_argument("--storage-dir", type=str, default=None, help="Directory to persist OCI artifacts")
    parser.add_argument("--verbose", action="store_true", help="Log HTTP requests")
    args = parser.parse_args()

    reg = InMemoryOCIRegistry(storage_dir=args.storage_dir)
    handler = create_handler(reg, verbose=args.verbose)

    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer((args.host, args.port), handler) as httpd:
        print(f"[OCI Registry] Running on http://{args.host}:{args.port}")
        sys.stdout.flush()

        def signal_handler(sig, frame):
            print("\n[OCI Registry] Shutting down...")
            httpd.server_close()
            sys.exit(0)

        signal.signal(signal.SIGINT, signal_handler)
        signal.signal(signal.SIGTERM, signal_handler)

        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass

if __name__ == "__main__":
    main()
