# generate_snowflake_key.py
# Creates a private/public key pair for the dbt service user.
# Keys are saved OUTSIDE the project folder, in your home folder.

from pathlib import Path
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

key_folder = Path.home() / ".snowflake"
private_key_file = key_folder / "dbt_user_key.p8"
public_key_file = key_folder / "dbt_user_key.pub"

# Safety: never overwrite an existing key (it would break the connection)
if private_key_file.exists():
    print(f"Key already exists at {private_key_file}. Not creating a new one.")
    raise SystemExit

key_folder.mkdir(parents=True, exist_ok=True)

# Create the key pair
private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)

private_pem = private_key.private_bytes(
    encoding=serialization.Encoding.PEM,
    format=serialization.PrivateFormat.PKCS8,
    encryption_algorithm=serialization.NoEncryption(),
)
public_pem = private_key.public_key().public_bytes(
    encoding=serialization.Encoding.PEM,
    format=serialization.PublicFormat.SubjectPublicKeyInfo,
)

private_key_file.write_bytes(private_pem)
public_key_file.write_bytes(public_pem)

# Snowflake needs the public key as one line, without the BEGIN/END lines
public_key_one_line = "".join(
    line for line in public_pem.decode().splitlines() if "-----" not in line
)

print(f"Private key saved to: {private_key_file}")
print(f"Public key saved to:  {public_key_file}")
print("\nCopy this public key into Snowflake (RSA_PUBLIC_KEY):\n")
print(public_key_one_line)