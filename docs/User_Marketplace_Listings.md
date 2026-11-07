# User marketplace listings

Authenticated users can manage their own market listings:

- `POST /user/market/listings` creates a listing. Supply `title`, non-negative
  `price`, and `category` (`buy` or `sell`); `description` is optional.
- `PATCH /user/market/listings/{listing_id}` updates one or more of `title`,
  `description`, `price`, and `category`. Send `description: null` to clear the
  description. Other fields cannot be set to `null`.
- `DELETE /user/market/listings/{listing_id}` deletes the listing.

The API derives the listing owner from the authenticated user. Update and
delete operations only act on listings owned by that user and return `404` when
the listing does not exist or is owned by someone else.
