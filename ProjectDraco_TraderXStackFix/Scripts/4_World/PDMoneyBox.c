// PDMoneyBox — a temporary, UID-locked container spawned when TraderX bonus
// payment can't safely go to a player's inventory after a stack-sell fix.
// UID enforcement is server-side only (CanPutInCargo + OnExecuteServer).

class PDMoneyBox extends SeaChest
{
    protected string m_OwnerUID;
    protected string m_OwnerName;

    void SetOwner(string uid, string name)
    {
        m_OwnerUID = uid;
        m_OwnerName = name;
    }

    string GetOwnerUID()  { return m_OwnerUID; }
    string GetOwnerName() { return m_OwnerName; }

    bool IsOwnedBy(PlayerBase player)
    {
        if (!player || !player.GetIdentity()) return false;
        return player.GetIdentity().GetId() == m_OwnerUID;
    }

    override bool CanPutInCargo(EntityAI parent)
    {
        if (!parent) return false;
        PlayerBase player = PlayerBase.Cast(parent.GetHierarchyRootPlayer());
        if (!player) return false;
        return IsOwnedBy(player);
    }

    override void OnStoreSave(ParamsWriteContext ctx)
    {
        super.OnStoreSave(ctx);
        ctx.Write(m_OwnerUID);
        ctx.Write(m_OwnerName);
    }

    override bool OnStoreLoad(ParamsReadContext ctx, int version)
    {
        if (!super.OnStoreLoad(ctx, version)) return false;
        ctx.Read(m_OwnerUID);
        ctx.Read(m_OwnerName);
        return true;
    }
}
