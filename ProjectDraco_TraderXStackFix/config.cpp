class CfgPatches
{
    class ProjectDraco_TraderXStackFix
    {
        units[] = {};
        weapons[] = {};
        requiredVersion = 0.1;
        requiredAddons[] = {};
    };
};

class CfgVehicles
{
    class SeaChest;

    class PDMoneyBox : SeaChest
    {
        scope = 2;
        displayName = "Money Box";
        descriptionShort = "A secure payment box. Only the rightful owner can open it.";
    };
};

class CfgMods
{
    class ProjectDraco_TraderXStackFix
    {
        dir = "ProjectDraco_TraderXStackFix";
        picture = "";
        action = "";
        hideName = 1;
        hidePicture = 1;
        name = "Project Draco TraderX Stack Fix";
        credits = "Project Draco";
        author = "Project Draco";
        authorID = "";
        version = "1.1";
        extra = 0;
        type = "mod";

        dependencies[] = {"World"};

        class defs
        {
            class worldScriptModule
            {
                value = "";
                files[] = {"ProjectDraco_TraderXStackFix/Scripts/4_World"};
            };
        };
    };
};
