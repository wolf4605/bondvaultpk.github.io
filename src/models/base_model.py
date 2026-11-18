"""Base Pydantic model configurations."""

from pydantic import BaseModel, ConfigDict


class Model(BaseModel):
    """Common configuration for models created from records."""

    model_config = ConfigDict(from_attributes=True, extra="ignore")


__all__ = ["Model"]
