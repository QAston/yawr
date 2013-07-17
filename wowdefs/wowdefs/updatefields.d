module wowdefs.updatefields;

import wowdefs.wow_version;

enum UFVisibilityFlags
{
	NONE         = 0x000,
	PUBLIC       = 0x001,
	PRIVATE      = 0x002,
	OWNER        = 0x004,
	UNUSED1      = 0x008,
	ITEM_OWNER   = 0x010,
	SPECIAL_INFO = 0x020,
	PARTY_MEMBER = 0x040,
	UNUSED2      = 0x080,
	DYNAMIC      = 0x100
}

/+
 + Annotation
 + Marks which updatefields changes should be visible to which clients
 + no annotation means public visibility
 +/
private struct Visibility
{
	uint UFVisibilityFlags;
	this(uint UFVisibilityFlags)
	{
		this.UFVisibilityFlags = UFVisibilityFlags;
	}
}

alias ulong Guid;
align (1) struct ObjectFields
{
	align (1):
	Guid guid;
	static if (wowVersion >= WowVersion.V4_2_0_14333) {
		ulong data;
	}
	ushort[2] type;
	uint entry;
	float scale;
	static if (wowVersion >= WowVersion.V4_0_6_13596 && wowVersion < WowVersion.V4_2_0_14333) {
		ulong data;
	}
	@Visibility(UFVisibilityFlags.NONE)
	int padding;
}

static if (wowVersion == WowVersion.V3_3_5a_12340) {
	static assert (ObjectFields.sizeof == 6*4);
}
else static if (wowVersion == WowVersion.V4_3_4_15595) {
	static assert (ObjectFields.sizeof == 8*4);
}


alias int ItemFlags;
align (1) struct ItemFields
{
	align (1):
	static if (wowVersion >= WowVersion.V4_3_0_15005)
		enum numItemEnchantments  = 15;
	else static if (wowVersion >= WowVersion.V4_0_6_13596)
		enum numItemEnchantments  = 14;
	else
		enum numItemEnchantments  = 12;

	ObjectFields objectFields;
	Guid owner;
	Guid contained;
	Guid creator;
	Guid giftCreator;
	@Visibility(UFVisibilityFlags.OWNER | UFVisibilityFlags.ITEM_OWNER) {
		int stackCount;
		int duration;
		int[5] spellCharges;
	}
	ItemFlags flags;
	int[3][numItemEnchantments] itemEnchantments;
	int propertySeed;
	int randomPropertiesId;
	@Visibility(UFVisibilityFlags.OWNER | UFVisibilityFlags.ITEM_OWNER)
	int durability;
	@Visibility(UFVisibilityFlags.OWNER | UFVisibilityFlags.ITEM_OWNER)
	int maxDurability;
	int createPlayedTime;
	static if (wowVersion < WowVersion.V4_3_0_15005) {
		@Visibility(UFVisibilityFlags.NONE)
		uint padding;
	}
}

static if (wowVersion == WowVersion.V3_3_5a_12340) {
	static assert (ItemFields.sizeof == ObjectFields.sizeof + 0x003A*4);
}
else static if (wowVersion == WowVersion.V4_3_4_15595) {
	static assert (ItemFields.sizeof == ObjectFields.sizeof + 0x0042*4);
}

align (1) struct ContainerFields
{
	align (1):
	ItemFields itemFields;
	int numSlots;
	@Visibility(UFVisibilityFlags.NONE)
	int padding;
	Guid[36] slots;
}

static if (wowVersion == WowVersion.V3_3_5a_12340) {
	static assert (ContainerFields.sizeof == ItemFields.sizeof + 0x004A*4);
}
else static if (wowVersion == WowVersion.V4_3_4_15595) {
	static assert (ContainerFields.sizeof == ItemFields.sizeof + 0x004A*4);
}

align (1) struct UnitFields
{
	align (1):
	alias byte[4] ByteFlags0, ByteFlags1, ByteFlags2;
	alias uint Flags, DynamicFlags, NpcFlags;
	alias uint Flags2;

	static if (wowVersion >= WowVersion.V4_2_0_14333)
		enum numPowers = 5;
	else static if (wowVersion >= WowVersion.V4_0_6_13596)
		enum numPowers = 11;
	else
		enum numPowers = 7;

	ObjectFields objectFields;
	Guid charm;
	Guid summon;
	@Visibility(UFVisibilityFlags.PRIVATE)
	Guid critter;
	Guid charmedBy;
	Guid summonedBy;
	Guid createdBy;
	Guid target;
	Guid channelObject;
	uint channelSpell;
	ByteFlags0 bytes0;
	uint health;
	uint[numPowers] powers;
	uint maxHealth;
	uint[numPowers] maxPowers;
	@Visibility(UFVisibilityFlags.PRIVATE | UFVisibilityFlags.OWNER | UFVisibilityFlags.UNUSED2) {
		float[numPowers] powerRegenFlatModifiers;
		float[numPowers] powerRegenInterruptedModifiers;
	}
	uint level;
	uint factionTemplate;
	uint[3] virtualItemSlots;
	Flags flags;
	Flags2 flags2;
	uint auraState;
	uint mainHandAttackTime;
	uint offHandAttackTime;
	@Visibility(UFVisibilityFlags.PRIVATE)
	uint rangedAttackTime;
	float boundingRadius;
	float combatReach;
	@Visibility(UFVisibilityFlags.DYNAMIC)
	uint displayId;
	uint nativeDisplayId;
	uint mountDisplayId;
	@Visibility(UFVisibilityFlags.PRIVATE | UFVisibilityFlags.OWNER | UFVisibilityFlags.SPECIAL_INFO) {
		float minDamage;
		float maxDamage;
		float minOffhandDamage;
		float maxOffhandDamage;
	}
	ByteFlags1 bytes1;
	uint petNumber;
	uint petNameTimeStamp;
	@Visibility(UFVisibilityFlags.OWNER)
	uint petExperience;
	@Visibility(UFVisibilityFlags.OWNER)
	uint petNextLevelXp;
	@Visibility(UFVisibilityFlags.DYNAMIC)
	DynamicFlags dynamicFlags;
	float modCastSpeed;
	static if (wowVersion >= WowVersion.V4_2_0_14333)
		float modCastHaste;
	uint createdBySpell;
	@Visibility(UFVisibilityFlags.DYNAMIC)
	NpcFlags npcFlags;
	uint npcEmoteState;
	@Visibility(UFVisibilityFlags.PRIVATE | UFVisibilityFlags.OWNER) {
		uint[5] stats;
		uint[5] posStats;
		uint[5] negStats;
	}
	@Visibility(UFVisibilityFlags.PRIVATE | UFVisibilityFlags.OWNER | UFVisibilityFlags.SPECIAL_INFO)
	uint[7] resistances;
	@Visibility(UFVisibilityFlags.PRIVATE | UFVisibilityFlags.OWNER) {
		uint[7] resistancesBuffModPositive;
		uint[7] resistancesBuffModNegative;
	}
	uint baseMana;
	@Visibility(UFVisibilityFlags.PRIVATE | UFVisibilityFlags.OWNER)
	uint baseHealth;
	ByteFlags2 bytes2;
	@Visibility(UFVisibilityFlags.PRIVATE | UFVisibilityFlags.OWNER) {
		uint attackPower;
		static if (wowVersion >= WowVersion.V4_0_6_13596) {
			uint attackPowerModPos;
			uint attackPowerModNeg;
		}
		else
			uint attackPowerMod;

		float attackPowerMultiplier;
		uint rangedAttackPower;
		static if (wowVersion >= WowVersion.V4_0_6_13596) {
			uint rangedAttackPowerModPos;
			uint rangedAttackPowerModNeg;
		}
		else
			uint rangedAttackPowerMod;

		float rangedAttackPowerMultiplier;
		float minRangedDamage;
		float maxRangedDamage;
		uint[7] powerCostModifier;
		float[7] powerCostMultiplier;
		uint maxHealthModifier;
	}
	float hoverHeight;
	static if (wowVersion >= WowVersion.V4_0_6_13596)
		uint maxItemLevel;
	static if (wowVersion < WowVersion.V4_0_6_13596 || wowVersion >= WowVersion.V4_2_0_14333) {
		@Visibility(UFVisibilityFlags.NONE)
		uint padding;
	}
}

static if (wowVersion == WowVersion.V3_3_5a_12340) {
	static assert (UnitFields.sizeof == ObjectFields.sizeof + 0x008E*4);
}
else static if (wowVersion == WowVersion.V4_3_4_15595) {
	static assert (UnitFields.sizeof == ObjectFields.sizeof + 0x008A*4);
}

align (1) struct PlayerFields
{
	align (1):
	alias uint Flags;
	alias byte[4] ByteFlags, ByteFlags2, ByteFlags3;
	alias uint[2] VisibleItem; // entryid, enchantmentid
	alias byte[4] Bytes;

	static if (wowVersion >= WowVersion.V4_0_6_13596)
		enum numQuestLogEntries = 50;
	else
		enum numQuestLogEntries = 25;

	static if (wowVersion >= WowVersion.V4_0_6_13596)
		enum numZones = 156;
	else
		enum numZones = 128;

	static if (wowVersion >= WowVersion.V4_0_6_13596)
		enum numCombatRatings = 26;
	else
		enum numCombatRatings = 25;

	static if (wowVersion >= WowVersion.V4_0_6_13596)
		enum numGlyphs =  9;
	else
		enum numGlyphs = 6;

	UnitFields unitFields;

	Guid duelArbiter;
	Flags flags;
	static if (wowVersion >= WowVersion.V4_0_6_13596)
	{
		uint guildRank;
		uint guildDeleteDate;
		uint guildLevel;
	}
	else
	{
		uint guildId;
		uint guildRank;
	}
	ByteFlags publicBytes;
	ByteFlags2 publicBytes2;
	ByteFlags3 publicBytes3;
	uint duelTeam;
	uint guildTimeStamp;
	@Visibility(UFVisibilityFlags.PARTY_MEMBER)
	uint[5][numQuestLogEntries] questLog;
	VisibleItem[19] visibleItems;
	uint chosenTitle;
	uint fakeInebriation;
	@Visibility(UFVisibilityFlags.NONE)
	uint padding_0;
	@Visibility(UFVisibilityFlags.PRIVATE) {
		Guid[23] inventory;
		Guid[16] packSlots;
		Guid[28] bankSlots;
		Guid[7] bankBagSlots;
		Guid[12] vendorBuyBackSlots;
		static if (wowVersion < WowVersion.V4_2_0_14333)
			Guid[32] keyringSlots;
		static if (wowVersion < WowVersion.V4_0_6_13596)
			ulong[32] currencyTokenSlots;
		Guid farsight;
	    static if (wowVersion >= WowVersion.V4_3_3_15354)
			ulong knownTitles[4];
	    else
	    	ulong knownTitles[3];
		static if (wowVersion < WowVersion.V4_0_6_13596)
			ulong knownCurrencies;
		uint xp;
		uint nextLevelXp;
		uint[64] skillLineIds;
		uint[64] skillSteps;
		uint[64] skillRanks;
		uint[64] skillMaxRanks;
		uint[64] skillModifiers;
		uint[64] skillTalents;
		uint characterPoints;
		static if (wowVersion < WowVersion.V4_0_6_13596)
			uint characterPoints2;
		uint trackCreatures;
		uint trackResources;
		static if (wowVersion >= WowVersion.V4_2_0_14333)
		{
			uint expertise;
			uint offhandExpertise;
		}
		float blockPercentage;
		float dodgePercentage;
		float parryPercentage;
		static if (wowVersion < WowVersion.V4_2_0_14333)
		{
			uint expertise;
			uint offhandExpertise;
		}
		float critPercentage;
		float rangedCritPercentage;
		float offHandCritPercentage;
		float[7] spellCritPercentage;
		uint shieldBlock;
		float shieldBlockCritPercentage;
		static if (wowVersion > WowVersion.V4_0_6_13596) {
			float mastery;
		}
		Bytes[numZones] exploredZones;
		uint restStateExperience;
		static if (wowVersion >= WowVersion.V4_0_6_13596)
			ulong coinage;
		else
			uint coinage;
		uint[7] modDamageDonePos;
		uint[7] modDamageDoneNeg;
		uint[7] modDamageDonePct;
		uint modHealingDonePos;
		float modHealingPct;
		float modHealingDonePct;
		static if (wowVersion >= WowVersion.V4_2_0_14333)
			float[3] weaponDamageMultipliers;
		static if (wowVersion >= WowVersion.V4_0_6_13596)
			float modSpellPowerPct;
	    static if (wowVersion >= WowVersion.V4_3_3_15354) {
			float overrideSpellPowerByApPct;
	    }
		int modTargetResistance;
		int modTargetPhysicalResistance;
		Bytes privateBytes;
		static if (wowVersion < WowVersion.V4_0_6_13596)
			uint ammoId;
		uint selfResSpell;
		uint pvpMedals;
		uint[12] buybackPrices;
		uint[12] buybackTimestamps;
		uint kills;
		static if (wowVersion < WowVersion.V4_0_6_13596) {
			uint todayContribution;
			uint yesterdayContribution;
		}
		uint lifetimeHonorableKills;
		Bytes privateBytes2;
		uint watchedFactionIndex;
		uint[numCombatRatings] combatRating;
		uint[7][3] arenaTeamInfo;
		static if (wowVersion < WowVersion.V4_0_6_13596) {
			uint honorCurrency;
			uint arenaCurrency;
		}
		else {
			uint battleGroundRating;
		}
		uint maxLevel;
		uint[25] dailyQuests;
		float[4] runeRegen;
		uint[3] noReagentCost;
		uint[numGlyphs] glyphSlots;
		uint[numGlyphs] glyphs;
		uint glyphsEnabled;
		uint petSpellPower;
		static if (wowVersion >= WowVersion.V4_0_6_13596) {
			uint[8] researching;
			uint[8] researchState;
			uint[2] professionSkillLine;
			float uiHitModifier;
			float uiSpellHitModifier;
			int homeRealTimeOffset;
			float modHaste;
			float modRangedHaste;
			float modPetHaste;
			float modHasteRegen;
		}
	}
	static if (wowVersion < WowVersion.V4_3_3_15354 && wowVersion >= WowVersion.V4_2_0_14333) {
	    @Visibility(UFVisibilityFlags.NONE)
		uint padding;
	}
}

static if (wowVersion == WowVersion.V3_3_5a_12340) {
	static assert (PlayerFields.sizeof == UnitFields.sizeof + 0x049A*4);
}
else static if (wowVersion == WowVersion.V4_3_4_15595) {
	static assert (PlayerFields.sizeof == UnitFields.sizeof + 0x04D6*4);
}

align (1) struct GameObjectFields
{
	align (1):
	alias uint Flags;
	alias byte[4] Bytes;
	ObjectFields objectFields;
	Guid createdBy;
	uint displayId;
	Flags flags;
	float[4] parentRotation;
	@Visibility(UFVisibilityFlags.DYNAMIC)
	ushort[2] dynamic;
	uint faction;
	uint level;
	Bytes bytes;
}

static if (wowVersion == WowVersion.V3_3_5a_12340) {
	static assert (GameObjectFields.sizeof == ObjectFields.sizeof + 0x000C*4);
}
else static if (wowVersion == WowVersion.V4_3_4_15595) {
	static assert (GameObjectFields.sizeof == ObjectFields.sizeof + 0x000C*4);
}

align (1) struct DynamicObjectFields
{
	align (1):
	alias ubyte[4] Bytes;
	ObjectFields objectFields;
	Guid caster;
	@Visibility(UFVisibilityFlags.DYNAMIC)
	Bytes bytes;
	uint spellId;
	float radius;
	uint castTime;
}

static if (wowVersion == WowVersion.V3_3_5a_12340) {
	static assert (DynamicObjectFields.sizeof == ObjectFields.sizeof + 0x0006*4);
}
else static if (wowVersion == WowVersion.V4_3_4_15595) {
	static assert (DynamicObjectFields.sizeof == ObjectFields.sizeof + 0x0006*4);
}

align (1) struct CorpseFields
{
	align (1):
	alias ubyte[4] Bytes1, Bytes2;
	alias uint Flags, DynamicFlags;
	ObjectFields objectFields;
	Guid owner;
	Guid party;
	uint displayId;
	uint[19] items;
	Bytes1 bytes1;
	Bytes2 bytes2;
	static if (wowVersion < WowVersion.V4_0_6_13596) {
		uint guild;
	}

	Flags flags;

	@Visibility(UFVisibilityFlags.DYNAMIC)
	DynamicFlags dynamicFlags;

	static if (wowVersion < WowVersion.V4_0_6_13596) {
		@Visibility(UFVisibilityFlags.NONE)
		uint padding;
	}
}

static if (wowVersion == WowVersion.V3_3_5a_12340) {
	static assert (CorpseFields.sizeof == ObjectFields.sizeof + 0x001E*4);
}
else static if (wowVersion == WowVersion.V4_3_4_15595) {
	static assert (CorpseFields.sizeof == ObjectFields.sizeof + 0x001C*4);
}

static if (wowVersion >=  WowVersion.V4_3_3_15354) {
	align (1) struct AreaTriggerFields
	{
		align (1):
		ObjectFields objectFields;
		uint spellId;
		uint spellVisualId;
		uint duration;
		float[3] finalPos;
	}

	static if (wowVersion == WowVersion.V4_3_4_15595) {
		static assert (AreaTriggerFields.sizeof == ObjectFields.sizeof + 0x0006*4);
	}
}