#!/usr/bin/env python3
"""Establece contraseña bcrypt para un usuario en app_users."""
import asyncio
import os
import sys

import asyncpg
import bcrypt


async def main() -> None:
    if len(sys.argv) != 3:
        print("Uso: set_password.py <email> <nueva_contraseña>", file=sys.stderr)
        sys.exit(1)
    email, password = sys.argv[1], sys.argv[2]
    url = os.environ.get("DATABASE_URL")
    if not url:
        print("Defina DATABASE_URL", file=sys.stderr)
        sys.exit(1)
    conn = await asyncpg.connect(url)
    try:
        h = bcrypt.hashpw(password.encode("utf-8")[:72], bcrypt.gensalt()).decode("utf-8")
        r = await conn.execute(
            "update app_users set password_hash = $2 where lower(email) = lower($1)",
            email,
            h,
        )
        print(r)
    finally:
        await conn.close()


if __name__ == "__main__":
    asyncio.run(main())
