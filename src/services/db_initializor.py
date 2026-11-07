"""
* Project Name: BONDVAULT PK

* Description: The database initializor to initialize the postgreSQL database with some data.

* Author: Wolf4605
* Email: mab4605@gmail.com

* Date: 2026-10-23 09:20:21

* Last Modified by: Wolf4605
* Last Modified time: 2026-10-23 09:20:23

* License: MIT
* Copyright© BondVault PK. All rights reserved.
"""

from pathlib import Path

from .. import models
from ..configs import AdminDBConfigs
from ..database import Database
from ..logging import get_logger

logger = get_logger()


def _ordered_missing_tables(
    tables: tuple[str, ...],
    existing_tables: set[str],
) -> list[str]:
    """Keep missing tables in their declared prerequisite order."""
    return [table for table in tables if table not in existing_tables]


class DB_initializor:
    """A class to populate the databse with some seed data."""
    def __init__(self) -> None:
        self.__db:Database = Database(dsn=AdminDBConfigs.CONNECTION_STRING)
        """The database instance with administrator priveleges."""

        self.__is_initialized:bool = False
        """Flag indicating if data is already there in the table."""

        self.__TABLES = (
            "admins", "users", "bondlists", "drawlists",
            "market", "reports", "blacklist", "upcoming_draws"
        )
        """A list of tables names that are to be found in the database."""


    async def __get_missing_tables(self) -> list[str]|None:
        """Returns a string of tables not found in the database."""

        table_names_db = await self.__db.fetch(
            """
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = 'public'
                AND table_name = ANY($1)
            """,
            list(self.__TABLES)
        )

        existing_tables:set[str] = {row["table_name"] for row in table_names_db}

        missing_tables = _ordered_missing_tables(self.__TABLES, existing_tables)

        if missing_tables:
            return missing_tables

        return None

    async def __get_empty_tables(self) -> list[str]|None:
        """Return empty tables from the database."""

        empty_tables = []
        for name in self.__TABLES:
            row = await self.__db.fetchrow(f"SELECT 1 FROM \"{name}\" LIMIT 1")

            if row is None:
                empty_tables.append(name)

        return empty_tables

    async def __create_tables(self):
        """Creates the missing database tables."""

        missing_tables = await self.__get_missing_tables()

        if missing_tables:
            schema_dir = Path(__file__).resolve().parent.parent / "database" / "schema"
            
            schema_file = {
                "admins" : "1-Admins.sql",
                "users" : "2-Users.sql",
                "bondlists" : "3-Bondlists.sql",
                "drawlists" : "4-Drawlists.sql",
                "market" : "5-Market.sql",
                "reports" : "6-Reports.sql",
                "blacklist" : "7-Blacklist.sql",
                "upcoming_draws" : "14-Upcoming-Draws.sql",
            }

            for name in missing_tables:
                file = schema_dir / schema_file[name]
                schema = file.read_text(encoding="utf-8")
                await self.__db.execute(schema)

                logger.info(f"Successfully executed [cyan]{schema_file[name]}[/].")

    async def __create_func_triggers(self):
        schema_dir = Path(__file__).resolve().parent.parent / "database" / "schema"

        index_schema = schema_dir.joinpath("8-Indexes.sql").read_text(encoding="utf-8")
        tasks_schema = schema_dir.joinpath("9-Tasks.sql").read_text(encoding="utf-8")
        funcs_schema = schema_dir.joinpath("10-Functions&Triggers.sql").read_text(encoding="utf-8")
        admin_invites_schema = schema_dir.joinpath(
            "12-Admin-Invites.sql"
        ).read_text(encoding="utf-8")
        admin_tasks_schema = schema_dir.joinpath(
            "13-Admin-Tasks.sql"
        ).read_text(encoding="utf-8")

        async with self.__db.transaction() as conn:
            await conn.execute(index_schema)
            logger.info("Successfully executed [cyan]8-Indexes.sql[/].")
            await conn.execute(funcs_schema)
            logger.info("Successfully executed [cyan]10-Functions&Triggers.sql[/].")
            await conn.execute(tasks_schema)
            logger.info("Successfully executed [cyan]9-Tasks.sql[/].")
            await conn.execute(admin_invites_schema)
            logger.info("Successfully executed [cyan]12-Admin-Invites.sql[/].")
            await conn.execute(admin_tasks_schema)
            logger.info("Successfully executed [cyan]13-Admin-Tasks.sql[/].")

    
    async def __populate_empty_tables(self):
        """Populates the empty tables with some seed data."""

        empty_tables = await self.__get_empty_tables()
        if empty_tables:
            for name in empty_tables:
                if name == "admins":

                    data = models.AdminRegister(
                        username="admin",
                        email="admin@example.com",
                        password_hash="admin",
                        first_name="System",
                        last_name="Admin",
                        contact = "03127820161",
                        is_superuser= True
                    )

                    await self.__db.execute(
                        """
                        INSERT INTO "admins" (
                            "username", "email", "password_hash", "first_name",
                            "last_name", "contact", "is_superuser"
                        )
                        VALUES ($1, $2, $3, $4, $5, $6, $7)
                        """,
                        data.username,
                        data.email,
                        data.password_hash,
                        data.first_name,
                        data.last_name,
                        data.contact,
                        data.is_superuser,
                    )

                    logger.info(f"Administrator added.\nusername: {data.username}\nemail: {data.email}")

                elif name == "users":
                    data = [
                        models.UserRegister(
                            username="user",
                            email="user@example.com",
                            password_hash="user",
                            first_name="New",
                            last_name="User",
                            contact = "03120987654",
                            city="Karachi",
                            address="Sample Street 1",
                        ),
                        models.UserRegister(
                            username="bob",
                            email="bob@example.com",
                            password_hash="bob",
                            first_name="Bob",
                            last_name="Murphy",
                            contact = "03120004455",
                            city="Lahore",
                            address="Sample Street 2",
                        ),
                    ]

                    for item in data:
                        await self.__db.execute(
                            """
                            INSERT INTO "users" (
                                "username", "email", "password_hash", "first_name",
                                "last_name", "contact", "city", "address", "is_verified"
                            )
                            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, TRUE)
                            """,
                            item.username,
                            item.email,
                            item.password_hash,
                            item.first_name,
                            item.last_name,
                            item.contact,
                            item.city,
                            item.address,
                        )
                elif name == "market":
                    await self.__db.execute(
                        """
                        INSERT INTO "market" (
                            "posted_by", "title", "description", "price", "category"
                        )
                        SELECT
                            "users"."id", seed."title", seed."description",
                            seed."price", seed."category"
                        FROM (
                            VALUES
                                (
                                    'user',
                                    'Prize bonds for sale',
                                    'Selling a selection of prize bonds in good condition.',
                                    5000,
                                    'sell'
                                ),
                                (
                                    'bob',
                                    'Looking for Rs. 750 bonds',
                                    'Interested in buying Rs. 750 prize bonds.',
                                    750,
                                    'buy'
                                ),
                                (
                                    'user',
                                    'Wanted: Rs. 1500 bonds',
                                    'Looking to purchase Rs. 1500 prize bonds.',
                                    1500,
                                    'buy'
                                )
                        ) AS seed("username", "title", "description", "price", "category")
                        JOIN "users" ON "users"."username" = seed."username"
                        """
                    )
                    logger.info("Sample marketplace listings added.")

                elif name == "reports":
                    await self.__db.execute(
                        """
                        INSERT INTO "reports" ("reported_by", "subject", "content")
                        SELECT "users"."id", seed."subject", seed."content"
                        FROM (
                            VALUES
                                (
                                    'user',
                                    'Sample report: listing inquiry',
                                    'This is a sample report for the development database.'
                                ),
                                (
                                    'bob',
                                    'Sample report: account assistance',
                                    'This is a sample account assistance report.'
                                )
                        ) AS seed("username", "subject", "content")
                        JOIN "users" ON "users"."username" = seed."username"
                        """
                    )
                    logger.info("Sample reports added.")
                else:
                    continue


    async def start(self):
        """Start the data population procedure."""

        if self.__is_initialized:
            logger.info("Database is already initialized.")
            return True
        
        try:
            await self.__db.pool_create()
            await self.__create_tables()
            await self.__create_func_triggers()
            await self.__populate_empty_tables()
            
        except ConnectionError:
            self.__is_initialized = False
            raise
        except RuntimeError:
            self.__is_initialized = False
            raise
        except Exception as error:
            self.__is_initialized = False
            raise RuntimeError("The database could not be initialized.") from error
        finally:
            await self.__db.pool_close()
        