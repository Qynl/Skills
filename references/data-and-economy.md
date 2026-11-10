# Data, economy and monetization

## DataStore rules

1. **Every call in `pcall`.** Transient failures are normal.
2. **Retry with exponential backoff** (`0.5, 1, 2, 4 s`, capped attempts), and give up loudly, not silently.
3. **Session lock per player** so two servers can't overwrite each other. Without it, a player who joins a second server (or reconnects during shutdown) can duplicate or lose items.
4. **Debounce writes.** Save on leave, on `BindToClose`, on meaningful purchases, and every ~120 s. Never per coin.
5. **Version the schema** and migrate. `schema = 1` in every record buys you a future.
6. **Budget**: roughly 60 reads and 60 writes per minute per key, and 4 MB per value. A single record per player, written a few times a minute, is well inside it. A record per item is not.
7. **Don't store what you can compute.** `level` derived from `xp`, `totalPlays` from analytics. Store inputs, derive outputs, so migrations stay small.

## Session lock, conceptually

A record holds:

```lua
{
	schema = 1,
	data = { coins = 0, wins = 0, owned = {} },
	lock = { session = "<server/session id>", ts = 1712345678 },
}
```

- **Load**: `UpdateAsync`; if `lock` exists, is from another session, and is fresher than `SessionLockSeconds`, the player is still in another server → refuse (kick with "your data is open elsewhere, rejoin in a minute").
- **On success**: write your `session` id and a fresh `ts`, return the record.
- **Heartbeat**: every 30 s, refresh `lock.ts` while the player is in this server, so a long session doesn't look stale.
- **Save/leave**: write `data`, then clear `lock` (or leave it with your session id and let it age out).
- **Crashes**: a stale lock older than `SessionLockSeconds` can be stolen. That's the recovery path.
- `UpdateAsync` returning `nil` cancels the write — useful to abort a locked load without throwing.

Roblox's own recommendation for production is a proven library: **ProfileStore** (successor to ProfileService) handles sessions, retries, and cross-server conflict resolution. Use it unless you have a reason not to; the teaching implementation in `assets/project/src/server/DataService.luau` shows the shape and the failure modes.

## Migrations

```lua
local MIGRATIONS = {
	[1] = function(record)
		-- v0 -> v1: coins were stored as a string once
		record.data.coins = tonumber(record.data.coins) or 0
		return record
	end,
}

local function migrate(record)
	local version = record.schema or 0
	while version < Config.SchemaVersion do
		version += 1
		local step = MIGRATIONS[version]
		if step then record = step(record) end
		record.schema = version
	end
	return record
end
```

Write the migration when you change the shape, and test it against a hand-made old record. "It'll be fine, nobody has data yet" is true right up until launch.

## Currency design

- **One soft currency** (coins/gems) and, at most, one premium currency. Three currencies means the player can't tell what anything costs.
- **Earn rates** should make the first purchase feel achievable in ~2–5 minutes of play; the aspirational item in ~1–3 hours. If the first meaningful reward takes an hour, new players leave.
- **Sinks** matter as much as sources: cosmetics, upgrades, rerolls, entry fees. Without sinks, prices inflate and the economy becomes pointless.
- **Never let the currency loophole the loop.** If buying coins skips the game, the game has no game in it.
- Show balances changing with feedback (tween the number, pop the icon). Silent balance changes read as bugs.

## Shop and upgrades

- Data-driven (`Config.Shop`) so pricing and items change without touching logic.
- Every purchase: validation → affordability → apply → persist → notify. Return `(ok, message)`.
- Grant *effects* on the server (walk speed attribute, an item in `owned`), and let the client render them. A cosmetic trail is a client effect; the right to use it is server state.
- Owned items are a set (`owned[itemId] = true`), never a list you have to scan.

## Passes and Developer Products

- **Game Pass** = permanent unlock, checked with `MarketplaceService:UserOwnsGamePassAsync(userId, passId)` (cache the result per session — it's rate-limited).
- **Developer Product** = repeatable purchase, handled in `ProcessReceipt`:

```lua
MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet  -- retry when they're back
	end

	local key = "receipt_" .. receipt.PurchaseId
	if DataService.hasReceipt(player, key) then
		return Enum.ProductPurchaseDecision.PurchaseGranted     -- already given
	end

	local ok = pcall(function()
		DataService.grantProduct(player, receipt.ProductId)
		DataService.markReceipt(player, key)
	end)

	return if ok
		then Enum.ProductPurchaseDecision.PurchaseGranted
		else Enum.ProductPurchaseDecision.NotProcessedYet
end
```

- **Idempotency is mandatory**: Roblox retries receipts. Granting twice is the classic "player bought 100 coins and got 200" bug.
- Call `PromptProductPurchase` from the client, but grant **only** in `ProcessReceipt` on the server.
- Price from `GetProductInfo` at display time; never hardcode a Robux amount in the UI.

## Policy and audience

Roblox's audience skews young, and the platform has rules about paid random items, gambling-like mechanics, and misleading monetization. Before shipping loot boxes, gacha, or "pay to continue", check the current Roblox policy pages — requirements change, and a game that violates them gets moderated, not just criticized. Cosmetics and convenience are the safe, sustainable design.

## Analytics that are worth wiring

- First-session funnel: join → first action → first reward → first purchase → return next day.
- Round completion rate and average session length.
- Where players quit (which round, which zone, which death).
- Currency inflow/outflow by source and sink — the fastest way to spot an economy that's broken or being farmed.

Roblox analytics (`AnalyticsService`, custom events) is enough for all of this; add it before launch, not after you wonder why retention is flat.
