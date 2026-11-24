import argparse
import json
import secrets
import string
import sys

DEFAULT_ROUNDS: int = 4096

try:
    from passlib.hash import sha512_crypt
except ImportError:
    print(json.dumps({"error": "Python package passlib is not installed"}), file=sys.stderr)
    raise SystemExit(1)


def main(password: str, rounds: int|None = DEFAULT_ROUNDS) -> dict[str, str]:
    if rounds is None or rounds <= 0:
        rounds = DEFAULT_ROUNDS
    salt = "".join(
        secrets.choice(string.ascii_letters + string.digits + "./")
        for _ in range(16)
    )
    return dict (
                hash = sha512_crypt.using
                            (
                                rounds=rounds,
                                salt=salt
                            ).hash(password)
                )


def from_args() -> dict[str, str]:
    parser = argparse.ArgumentParser()
    parser.add_argument("-p", "--password", dest="password", required=True, type=str)
    parser.add_argument("-r", "--rounds", dest="rounds", default=DEFAULT_ROUNDS, type=int, required=False)
    parser.add_argument("--print", dest="print_output", action="store_true")
    args = parser.parse_args()

    if not args.password:
        parser.error("Password must be provided")

    result = main(args.password, args.rounds)

    if args.print_output:
        print(json.dumps(result, indent=2))

    return result


if __name__ == "__main__":
    from_args()
