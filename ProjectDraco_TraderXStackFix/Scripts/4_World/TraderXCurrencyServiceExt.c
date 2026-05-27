// Extends TraderXCurrencyService with AddMoneyToContainer — mirrors the
// AddMoneyToPlayer denomination loop but targets a container's inventory
// instead of a player. Used by the stack-fix bonus payment box.

modded class TraderXCurrencyService
{
    // Returns any amount that could not fit in the container (0 = fully paid out).
    int AddMoneyToContainer(EntityAI container, int amount, ref TStringArray acceptedCurrencyTypes = null)
    {
        if (!container || amount <= 0) return 0;

        if (!acceptedCurrencyTypes)
            acceptedCurrencyTypes = new TStringArray();

        foreach (TraderXCurrencyType currencyType : currencySettings.currencyTypes)
        {
            if (acceptedCurrencyTypes.Count() > 0 && acceptedCurrencyTypes.Find(currencyType.currencyName) == -1)
                continue;

            foreach (TraderXCurrency currency : currencyType.currencies)
            {
                int value = currency.GetCurrencyValue();
                if (value <= 0 || value > amount) continue;

                int totalQty = amount / value;
                int maxStack = TraderXQuantityManager.GetMaxItemQuantityServer(currency.GetCurrencyClassName());
                if (maxStack <= 0) maxStack = 1;

                while (totalQty > 0)
                {
                    int stackQty = Math.Min(totalQty, maxStack);
                    ItemBase item = ItemBase.Cast(
                        container.GetInventory().CreateInInventory(currency.GetCurrencyClassName()));

                    if (!item)
                    {
                        GetTraderXLogger().LogWarning(string.Format(
                            "[PDMoneyBox] Container full, could not place %1 x%2 (box may be overfull)",
                            stackQty, currency.GetCurrencyClassName()));
                        break;
                    }

                    TraderXQuantityManager.SetQuantity(item, stackQty);
                    totalQty -= stackQty;
                    amount -= stackQty * value;
                }

                if (amount <= 0) break;
            }

            if (amount <= 0) break;
        }

        return amount;
    }
}
