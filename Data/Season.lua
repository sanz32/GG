local ADDON_NAME, GG = ...

GG.Season = {
  SEASON_ID = 18,

  SEASON_CURRENCY_IDS = {
    3442, 3443, 3444, 3445, 3446,
    3465,
    3509,
    3310, 3028, 3356,
    3418,
  },

  SEASON_ITEM_IDS = {
    274476,
    280562,
  },

  CURRENCY_GROUPS = {
    { labelKey = "ROSTER_ROW_CRESTS", 3442, 3443, 3444, 3445, 3446 },
    { labelKey = "ROSTER_ROW_SEASON", 3509, 274476, 3465, 3418, 280562 },
    { labelKey = "ROSTER_ROW_DELVES", 3310, 3028, 3356, "bounty" },
  },

  RAIDS = {
    { instanceID = 2987, journalInstanceID = 1317, numEncounters = 1, name = "The Tidebound Grotto",
      bossLetters = { "N" } },
    { instanceID = 3004, journalInstanceID = 1320, numEncounters = 8, name = "The Venomous Abyss",
      bossLetters = { "N", "S", "E", "V", "S", "T", "C", "U" } },
  },

  PENDING_RAIDS = {
    { instanceID = 3095, numEncounters = 1, name = "The Unbinding of Kith'ix", bossNames = { "Kith'ix" },
      bossLetters = { "K" } },
  },

  PREVIOUS_RAID_INSTANCE_IDS = { 2912, 2913, 2939, 1592 },

  DUNGEON_ABBR = {
    [588] = "AOF",
    [587] = "MR",
    [586] = "DON",
    [584] = "BV",
    [585] = "VSA",
    [249] = "KR",
    [250] = "TOS",
    [399] = "RLP",
  },

  BOUNTY = {
    itemID = 274374,
    iconTexture = [[Interface\Icons\icon_treasuremap]],
    questID = 86371,
    spellID = 1293799,
    fluteItemID = 275910,
  },

  NEMESIS = {
    itemID = 278276,
    iconFileID = 8032873,
    questIDs = { 96434, 97913 },
    mapID = 3079,
  },

  CRACKED_KEYSTONE = {
    itemID = 279012,
    iconTexture = [[Interface\Icons\inv_relics_hourglass_02]],
    questID = 97910,
  },

  KINDOJAN = {
    itemID = 285065,
    iconTexture = [[Interface\Icons\ability_argus_soulbombdebufflarge]],
    fragmentsPerItem = 3,
    quests = {
      { id = 98951, name = "Akil'zon's Roost" },
      { id = 98963, name = "Halazzi's Lair" },
      { id = 98962, name = "The Cave Towers" },
      { id = 98961, name = "Jan'alai's Refuge" },
      { id = 98960, name = "Nalorakk's Rest" },
      { id = 98959, name = "Kindo'jan, The First Hash'ey" },
    },
  },
}

GG.MIN_CHARACTER_LEVEL = 80
