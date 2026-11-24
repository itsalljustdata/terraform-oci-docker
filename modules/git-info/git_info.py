import argparse
import json
import re
import subprocess
from pathlib import Path


def run_git(repo_dir: Path, *args: str) -> str:
    try:
        result = subprocess.run(
            ["git", "-C", str(repo_dir), *args],
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout.strip()
    except (subprocess.CalledProcessError, OSError):
        return ""


def get_repo_info(repo_dir: str = "") -> dict[str, str]:
    target_dir = Path(repo_dir) if repo_dir else Path(__file__).resolve().parent.parent.parent

    commit = run_git(target_dir, "rev-parse", "HEAD") or "unknown"
    remote_url = run_git(target_dir, "remote", "get-url", "origin") or "unknown"
    is_dirty = bool(run_git(target_dir, "status", "--porcelain"))

    source = "unknown"
    if remote_url and remote_url != "unknown":
        normalized = re.sub(r"\.git$", "", remote_url.rstrip("/"))

        patterns = [
            r"^https?://[^/]+/(.+)$",
            r"^ssh://[^/]+/(.+)$",
            r"^[^@]+@[^:]+:(.+)$",
            r"^git@[^:]+:(.+)$",
        ]
        for pattern in patterns:
            match = re.match(pattern, normalized)
            if match:
                source = match.group(1)
                break
        else:
            source = normalized

    retDict = dict (
        commit     = commit,
        remote_url = remote_url,
        source     = source,
        is_dirty   = str(is_dirty).lower(),
    )
    return retDict


def fromArgs() -> dict[str, str]:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-dir", dest="repo_dir", help="Path to the repository directory", required=True, type=str)
    parser.add_argument("--print", dest="print_output", help="Print the output", action="store_true")
    args = parser.parse_args()
    
    info = get_repo_info(repo_dir = args.repo_dir)

    if args.print_output:
        print(json.dumps(info, indent=2))

    return info

if __name__ == "__main__":
    fromArgs()
