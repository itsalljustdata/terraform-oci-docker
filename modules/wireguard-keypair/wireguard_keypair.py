import base64
import json
import sys
from pathlib import Path
import argparse

try:
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric import x25519
except ImportError:
    print(json.dumps({"error": "Python package cryptography is not installed"}), file=sys.stderr)
    raise SystemExit(1)


def decode_key(value):
    if not isinstance(value, str):
        raise ValueError("key is not a string")
    raw = base64.b64decode(value, validate=True)
    if len(raw) != 32:
        raise ValueError("key must decode to exactly 32 bytes")
    return raw


def load_existing(output_file: str|Path) -> dict[str,str]|None:

    if isinstance(output_file, str):
        output_file = Path(output_file)

    if not output_file.is_file():
        return None

    try:

        result = json.loads(output_file.read_text(encoding="utf-8"))

        keys = ["private_key", "public_key"]
        if not all(key in result for key in keys):
            return None
        
        private_raw = decode_key(result["private_key"])
        public_raw  = decode_key(result["public_key"])

        private_key = x25519.X25519PrivateKey.from_private_bytes(private_raw)
        derived_public_raw = private_key.public_key().public_bytes(
            encoding=serialization.Encoding.Raw,
            format=serialization.PublicFormat.Raw,
        )

        if derived_public_raw != public_raw:
            raise ValueError("public key does not match private key")

        return {k:v for k,v in result.items() if k in keys}
    
    except (OSError, json.JSONDecodeError, KeyError, TypeError, ValueError):
        return None


def main (output_file: str|Path) -> dict[str,str]:
    if isinstance(output_file,str):
        output_file = Path(output_file)
    result = load_existing(output_file) 

    if result is None:
        private_key = x25519.X25519PrivateKey.generate()
        public_key  = private_key.public_key()

        result = dict (
            private_key = base64.b64encode
                            (
                                private_key.private_bytes
                                    (
                                        encoding=serialization.Encoding.Raw,
                                        format=serialization.PrivateFormat.Raw,
                                        encryption_algorithm=serialization.NoEncryption(),
                                    )
                            ).decode("utf-8"),
            public_key = base64.b64encode
                            (
                                public_key.public_bytes
                                    (
                                        encoding=serialization.Encoding.Raw,
                                        format=serialization.PublicFormat.Raw,
                                    )
                            ).decode("utf-8"),
        )

        output_file.parent.mkdir(parents=True, exist_ok=True)
        output_file.write_text(json.dumps(result, indent=2), encoding="utf-8")

    return result

def fromArgs() -> dict[str,str]:
    parser = argparse.ArgumentParser()
    parser.add_argument("-o", "--output_file", help="Path to the output file", type=str, required=True)
    parser.add_argument("--print", dest="print_output", help="Print the output", action="store_true")
    args = parser.parse_args()
    result = main(args.output_file)
    if args.print_output:
        print(json.dumps(result, indent=2))
    return result

if __name__ == "__main__":
    fromArgs()