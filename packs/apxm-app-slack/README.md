# apxm-app-slack

A connector **App** pack: it contributes Slack workflow **blocks**, not an
executable skill. Installing it (`dekk apxm libs install apxm-app-slack`) makes
its `tools.toml` blocks real capabilities (e.g. `slack.post`, backed by
`provider.call`). Connect a Slack account via apxm-auth, then the block becomes
draggable in apxm-studio.
