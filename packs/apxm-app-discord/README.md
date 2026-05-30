# apxm-app-discord

Connector **App** pack contributing Discord workflow blocks (e.g. `discord.post`,
backed by `provider.call`). Discord's bot API authenticates with
`Authorization: Bot <token>`, injected by apxm-auth `/proxy` per the provider
descriptor's `auth_inject = "bot"`. Connect a Discord bot via apxm-auth, then the
block becomes draggable in apxm-studio.
