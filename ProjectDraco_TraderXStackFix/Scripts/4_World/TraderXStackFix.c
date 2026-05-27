// TraderX Stack Quantity Fix  v1.1
// Fixes a bug where selling a stack of count items (e.g. Diesel Coins) only pays
// for 1 unit even though the entire stack is removed.
//
// Root cause: tradeQuantity=1 encodes as SELL_EMPTY mode → quantity=0 passed to
// RemoveItem → whole entity deleted, but price calculated for multiplier=1 only.
//
// Fix: capture actual stack count before super removes it, then issue a bonus
// payment for (actualCount - multiplier) remaining units via a UID-locked
// PDMoneyBox spawned at the player's feet. Only discrete count items are affected.

modded class TraderXTransactionService
{
    override TraderXTransactionResult ProcessTransaction(TraderXTransaction transaction, PlayerBase player)
    {
        // Only patch sell transactions
        if (!transaction || transaction.IsBuy())
            return super.ProcessTransaction(transaction, player);

        // Skip vehicle sells — they use a separate code path and don't stack
        TraderXProduct product = TraderXProductRepository.GetItemById(transaction.GetProductId());
        if (!product || TraderXVehicleTransactionService.GetInstance().IsVehicleProduct(product.className))
            return super.ProcessTransaction(transaction, player);

        // Locate the physical item before the transaction removes it
        ItemBase itemToSell = ItemBase.Cast(GetGame().GetObjectByNetworkId(
            transaction.GetNetworkId().GetLowId(),
            transaction.GetNetworkId().GetHighId()));

        if (!itemToSell)
            return super.ProcessTransaction(transaction, player);

        // Only fix discrete count items (QuantityConversions type 1).
        // Type 0 = no quantity. Type 2 = liquids (price per container, not per ml).
        // Detachable magazines (Mag_AK_30Rnd etc.) return type 0 — their "15/30"
        // display is handled by the magazine ammo UI, not the standard quantity system,
        // so they are automatically excluded here. Loose ammo stacks (Ammo_9x19mm x25)
        // return type 1 and are correctly included.
        int quantityType = QuantityConversions.HasItemQuantity(itemToSell);
        if (quantityType != 1)
            return super.ProcessTransaction(transaction, player);

        // Capture what we need before super destroys the item entity
        int actualQuantity    = TraderXQuantityManager.GetItemAmount(itemToSell);
        int itemState         = itemToSell.GetHealthLevel();
        int clientMultiplier  = transaction.GetMultiplier();

        // Run the original sell: removes the entity, pays for clientMultiplier units
        TraderXTransactionResult result = super.ProcessTransaction(transaction, player);

        // If the stack held more units than the client-side multiplier, pay the difference
        if (result.IsSuccess() && actualQuantity > clientMultiplier)
        {
            int bonusUnits = actualQuantity - clientMultiplier;

            TraderXPriceCalculation bonusCalc = TraderXPricingService.GetInstance().CalculateSellPrice(product, bonusUnits, itemState);
            int bonusAmount = bonusCalc.GetCalculatedPrice();

            if (bonusAmount > 0)
            {
                TraderXNpc npc = GetTraderXModule().GetSettings().GetNpcById(transaction.GetTraderId());
                if (npc)
                {
                    GetTraderXLogger().LogInfo(string.Format(
                        "[PDStackFix] Spawning money box — %1 TXD bonus for %2 extra units of %3 (stack=%4, mult=%5)",
                        bonusAmount, bonusUnits, product.className, actualQuantity, clientMultiplier));

                    int remaining = bonusAmount;
                    int boxCount = 0;
                    int boxLimit = 10;

                    while (remaining > 0 && boxLimit > 0)
                    {
                        boxLimit--;
                        PDMoneyBox box = PDMoneyBox.Cast(GetGame().CreateObjectEx("PDMoneyBox", player.GetPosition(), ECE_PLACE_ON_SURFACE));
                        if (!box)
                        {
                            GetTraderXLogger().LogWarning(string.Format(
                                "[PDStackFix] PDMoneyBox spawn failed with %1 TXD remaining, falling back to AddMoneyToPlayer", remaining));
                            TraderXCurrencyService.GetInstance().AddMoneyToPlayer(player, remaining, npc.GetCurrenciesAccepted());
                            remaining = 0;
                            break;
                        }

                        box.SetOwner(player.GetIdentity().GetId(), player.GetIdentity().GetName());
                        box.SetLifetime(1800.0);
                        remaining = TraderXCurrencyService.GetInstance().AddMoneyToContainer(box, remaining, npc.GetCurrenciesAccepted());
                        boxCount++;
                    }

                    if (boxCount > 0)
                    {
                        player.MessageImportant(string.Format(
                            "[Payment] Bonus %1 TXD placed in %2 Money Box(es) at your feet — only you can open them.",
                            bonusAmount, boxCount));
                    }
                }
            }
        }

        return result;
    }
}
