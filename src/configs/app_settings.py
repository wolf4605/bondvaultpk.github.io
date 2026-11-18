"""Application metadata and OpenAPI documentation settings."""

from pathlib import Path

from pydantic import Field, field_validator
from pydantic_settings import (
    BaseSettings,
    PydanticBaseSettingsSource,
    SettingsConfigDict,
    TomlConfigSettingsSource,
)


class _AppSettings(BaseSettings):
    """Contains all the main app settings settings."""

    Title: str = Field(default=..., alias= "name", description= "Title of the Application.")
    """Title of the Application."""
    Summary: str = Field(default=..., alias= "summary", description= "Summary of the Application.")
    """Summary of the Application."""
    Version: str = Field(default=..., alias= "version", description="Current application version.") 
    """Current application version."""
    Description: str = Field(default=..., alias="description", description="A detailed explaination of the Project.")
    """A detailed explaination of the Project."""
    Contact: list[dict[str,str]] = Field(default=..., alias="authors", description="A detailed explaination of the Project.")
    """Contact info of the authors of the application."""
    License: dict[str,str] = Field(default=..., alias="licence", description= "The applications liscense page.")
    """The applications license page."""
    Initialize_Database: bool = Field(default=False, alias = "initialize_db", description="A bool to trigger initial database initialization.")
    """A boolean value used to initialize database. Default = `False`\n\nIt is recommended to turn it on for the first start so that the Backend can execute it's database structure.\n\n**Important:** You need set the following variables in the .env file **IF** the valuse is set to `True`.\n- `ADMIN_POSTGRES_USER`\n- `ADMIN_POSTGRES_PASSWORD`\n\nIf the value is `False` then no need for the above two variables.
    """


    @field_validator("Title", mode="before")
    @classmethod
    def __replace_underscore(cls, value:str):
        if isinstance(value, str):
            return value.replace("_", " ")
        return value


    model_config = SettingsConfigDict(
        toml_file=Path(__file__).parent.parent.parent.joinpath("pyproject.toml"),
        toml_table_header= ("project",),
        extra="ignore",
        case_sensitive=False,
        populate_by_name= True
    )

    @classmethod
    def settings_customise_sources(
        cls,
        settings_cls: type[BaseSettings],
        init_settings: PydanticBaseSettingsSource,
        env_settings: PydanticBaseSettingsSource,
        dotenv_settings: PydanticBaseSettingsSource,
        file_secret_settings: PydanticBaseSettingsSource,
) -> tuple[PydanticBaseSettingsSource, ...]:
        """Prioritizes loading variables directly from the defined TOML configuration file."""
        return (TomlConfigSettingsSource(settings_cls),)

AppSettings:_AppSettings = _AppSettings()
"""Contains all the main app settings settings."""