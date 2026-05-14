# Competition Trees

Competition trees are persisted knockout brackets for individual categories. Pools remain the source for qualification: admins record `participation.pool_number` and `participation.pool_position`, then explicitly generate the tree when pool results are final.

## Lifecycle

1. Assign pools and pool positions on participations.
2. Use the individual category admin action to generate the competition tree.
3. `IndividualCategoryBracketBuilder` reads the qualified participations, creates deterministic `Fight` records, and links later rounds through parent fights.
4. Admins record each fight winner and optional score from the category admin page.
5. Updating a fight winner broadcasts a Turbo Stream replacement for the category tree, so subscribed admin and public views update live.

## Rebuild Rules

Generating a tree replaces existing fights only while no winners have been recorded. Once the bracket has started, admins must explicitly confirm a rebuild. Rebuilding deletes recorded winners and recreates fights from the current pool positions.

## Scope

The first version supports individual categories only. Team categories still have pool data, but they should not use the individual bracket builder until team-specific fighter and seeding rules are designed.
