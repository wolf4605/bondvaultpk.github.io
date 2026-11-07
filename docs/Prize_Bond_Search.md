# Public prize-bond draw search

These public endpoints search the imported draw results. They do not require an
access token. Bond numbers are six digits and may be sent without leading
zeroes; shorter values are normalized to six digits for lookup (for example,
`20` is searched as `000020`).

## Search one bond number

`GET /bonds/draw-results/{denomination}/number/{bond_number}`

The denomination must be one of `100`, `200`, `750`, `1500`, `25000`, or
`40000`. The bond number must be between `1` and `999999`. The response lists
every matching draw for that denomination, newest first.

## Search an inclusive number range

`GET /bonds/draw-results/{denomination}/range?start_num={start}&end_num={end}`

The endpoint returns all winning bonds in the inclusive range across draw
dates in one response. Results are ordered newest draw first and then by bond
number. `start_num` and `end_num` accept one to six digits and are normalized
to six digits; the start must not exceed the end.

Each result includes `bond_number`, `denomination`, `prize_position` (`1`, `2`,
or `3`), the corresponding `prize_name`, `prize_amount`, and `draw_date`.
`total` equals the number of returned results. An empty `results` array means
no matching winning bonds were found.

## Search the authenticated user's bondlists

`GET /user/bond-winnings`

This endpoint requires a user access token. It searches every bond saved in the
authenticated user's bondlists against all imported draw results and returns
each matching winning bond, including its prize position, prize name, prize
amount, denomination, and draw date. Results are ordered newest draw first.
The response uses the same `results` and `total` shape as the public draw
searches; an empty `results` array means none of the user's saved bonds won.
