"""
One-time script to create the first admin account.

Usage:
    python create_admin.py --phone +919487896921 --name "Johan Paul"

Run from the backend root folder with the venv activated.
"""
import asyncio
import argparse
import sys
from pathlib import Path

# Make sure app package is importable
sys.path.insert(0, str(Path(__file__).parent))

from sqlalchemy import select
from app.database import AsyncSessionLocal
from app.models.models import User, UserRole


async def create_admin(phone: str, name: str) -> None:
    async with AsyncSessionLocal() as db:
        # Check if already exists
        result = await db.execute(select(User).where(User.phone_number == phone))
        existing = result.scalar_one_or_none()

        if existing:
            if existing.role == UserRole.admin:
                print(f"✓ Admin already exists: {existing.name} ({existing.phone_number})")
            else:
                existing.role = UserRole.admin
                await db.commit()
                print(f"✓ Upgraded existing user to admin: {existing.name} ({existing.phone_number})")
            return

        user = User(
            phone_number=phone,
            name=name,
            role=UserRole.admin,
            trust_score=100,
        )
        db.add(user)
        await db.commit()
        print(f"✓ Admin account created:")
        print(f"  Name  : {name}")
        print(f"  Phone : {phone}")
        print(f"  Role  : admin")
        print()
        print("Now add ADMIN_SECRET to your .env and use it on the web dashboard login page.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Create the RoadWatch admin account")
    parser.add_argument("--phone", required=True, help="Phone number e.g. +919487896921")
    parser.add_argument("--name",  required=True, help="Admin full name")
    args = parser.parse_args()

    asyncio.run(create_admin(args.phone, args.name))
