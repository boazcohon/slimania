export const ROOM_SIZE = { width: 1920, height: 1024 };
export const TOP_WALL_HEIGHT = 258;
export const BORDER = 26;
export const EXIT_RECT = { x: 1856, y: 540, width: 64, height: 170 };
export const PLAYER_SPAWN = { x: 200, y: 760 };

export const PLAYER_BASE_MAX_HP = 40;
export const PLAYER_BASE_ATTACK = 3;
export const XP_PER_LEVEL = 25;
export const LEVEL_UP_HP_BONUS = 6;
export const LEVEL_UP_ATTACK_BONUS = 1;
export const ROOM_CLEAR_HEAL = 8;
export const HEAL_AMOUNT = 20;

export const PLAYER_TUNING = {
  moveSpeed: 300,
  airSpeed: 340,
  jumpDuration: 0.45,
  jumpCooldown: 0.9,
  jumpHeight: 46,
  climbSpeed: 130,
  climbMaxStamina: 1.8,
  climbRechargeRate: 1.2,
  waterDamage: 5,
  hurtSafetyTime: 1
};

export const ENEMY_TUNING = {
  wanderSpeed: 60,
  chaseSpeed: 175,
  detectRadius: 380
};

export const DAMAGE_WIGGLE_LOW = 0.85;
export const DAMAGE_WIGGLE_HIGH = 1.15;

export const ASSETS = {
  goopzz: new URL("../slimania assets/characters/goopzz/goopzz.png", import.meta.url).href,
  goopzzAngry: new URL("../slimania assets/characters/goopzz/goopzz angry.png", import.meta.url).href,
  enemySlime: new URL("../slimania assets/characters/enemy slime/enemy slime full rez 2d.png", import.meta.url).href,
  enemySlimeAttacking: new URL("../slimania assets/characters/enemy slime/enemy slime attacking full rez 2d.png", import.meta.url).href,
  helpSlime: new URL("../slimania assets/characters/help slime/help slime full rez 2d.png", import.meta.url).href,
  sword: new URL("../slimania assets/items/goopzz/sword/goopzz s word.png", import.meta.url).href,
  moveDisc: new URL("../slimania assets/items/move disc/move disc.png", import.meta.url).href,
  beachSand: new URL("../slimania assets/terrain/areas/beach/beach sand normal full rez 2d.png", import.meta.url).href,
  beachScene: new URL("../slimania assets/terrain/areas/beach/ground.png", import.meta.url).href,
  forestGround: new URL("../slimania assets/terrain/areas/forest/forest grassy ground.png", import.meta.url).href,
  logoInvaded: new URL("../slimania assets/logo/1/slimania invaded.png", import.meta.url).href,
  logoSmall: new URL("../slimania assets/logo/2 textures/slimania logo.png", import.meta.url).href,
  skybox: new URL("../slimania assets/logo/2 textures/skybox.png", import.meta.url).href
};

export const TYPE_MULTIPLIER = {
  slime: 1,
  sword: 1.5,
  water: 1.25,
  support: 1
};

export const TYPE_COLORS = {
  slime: "#2fa65a",
  sword: "#9e7038",
  water: "#347fc7",
  support: "#8c5cb8"
};

export const ALL_MOVES = {
  bonk: {
    name: "Bonk",
    type: "slime",
    effect: "damage",
    power: 6,
    description: "A friendly headbutt. Reliable, like a good sandwich."
  },
  sword_slash: {
    name: "Sword Slash",
    type: "sword",
    effect: "damage",
    power: 7,
    description: "Goopzz's trusty wooden sword. Slimes hate swords."
  },
  goo_shield: {
    name: "Goo Shield",
    type: "support",
    effect: "shield",
    power: 0,
    description: "Puff up into a wall of goo. The next hit does half damage."
  },
  slime_snack: {
    name: "Slime Snack",
    type: "support",
    effect: "heal",
    power: 14,
    description: "Munch an emergency snack. Restores 14 HP."
  },
  double_bounce: {
    name: "Double Bounce",
    type: "slime",
    effect: "multi_hit",
    power: 4,
    hits: 2,
    description: "Boing! Boing! Hits twice."
  },
  splash: {
    name: "Splash",
    type: "water",
    effect: "damage",
    power: 8,
    description: "Slimes are weak to water. Yes, even you. Use responsibly."
  },
  battle_cry: {
    name: "Battle Cry",
    type: "support",
    effect: "buff_attack",
    power: 3,
    description: "BLORP! Raises your attack for the rest of this battle."
  },
  sand_throw: {
    name: "Sand Throw",
    type: "support",
    effect: "debuff_attack",
    power: 3,
    description: "Kick beach sand at the enemy. Lowers their attack."
  },
  mega_bonk: {
    name: "Mega Bonk",
    type: "slime",
    effect: "damage",
    power: 13,
    description: "Like Bonk, but MEGA."
  },
  sword_spin: {
    name: "Sword Spin",
    type: "sword",
    effect: "damage_recoil",
    power: 12,
    recoil: 4,
    description: "Spin with the sword. Huge damage, but you take 4 recoil."
  },
  royal_jelly: {
    name: "Royal Jelly",
    type: "support",
    effect: "heal",
    power: 30,
    description: "Fancy healing jelly fit for a king. Restores 30 HP."
  },
  tackle: {
    name: "Tackle",
    type: "slime",
    effect: "damage",
    power: 5,
    description: "A wobbly body slam."
  },
  chomp: {
    name: "Chomp",
    type: "slime",
    effect: "damage",
    power: 8,
    description: "Angry slime teeth."
  },
  war_cry: {
    name: "War Cry",
    type: "support",
    effect: "buff_attack",
    power: 2,
    description: "GRRRB! The enemy powers up."
  },
  big_slam: {
    name: "Big Slam",
    type: "slime",
    effect: "damage",
    power: 12,
    description: "A boss-sized belly flop."
  }
};

export const STARTING_LOADOUT = ["bonk", "sword_slash", "goo_shield", "slime_snack"];
export const REWARD_POOL = [
  "double_bounce",
  "splash",
  "battle_cry",
  "sand_throw",
  "mega_bonk",
  "sword_spin",
  "royal_jelly"
];
export const MAX_LOADOUT_SIZE = 4;

export const ROOMS = [
  {
    title: "Sandy Landing",
    area: "beach",
    hint: "Welcome back, hero! WASD to move, SPACE to hop, and walk into that red slime to battle it!",
    enemies: [{ pos: { x: 1400, y: 640 }, level: 1 }],
    pickups: [],
    water: [],
    climbWalls: []
  },
  {
    title: "Tide Pools",
    area: "beach",
    hint: "Hop over the water with SPACE. Slimes and water do not mix! That rainbow thing is a Move Disc. Grab it!",
    enemies: [
      { pos: { x: 1250, y: 450 }, level: 1 },
      { pos: { x: 1500, y: 750 }, level: 2 }
    ],
    pickups: [{ pos: { x: 1700, y: 380 }, kind: "move" }],
    water: [{ x: 860, y: 260, width: 120, height: 764 }],
    climbWalls: []
  },
  {
    title: "The Rocks",
    area: "beach",
    hint: "Hold SHIFT on the rocks to climb, but hurry. Slimes slip when their grip runs out!",
    enemies: [
      { pos: { x: 1300, y: 400 }, level: 2 },
      { pos: { x: 1450, y: 800 }, level: 3 }
    ],
    pickups: [{ pos: { x: 300, y: 850 }, kind: "heal" }],
    water: [],
    climbWalls: [{ x: 900, y: 260, width: 110, height: 764 }]
  },
  {
    title: "Slime Patrol",
    area: "beach",
    hint: "Three on patrol! They're slower than you. Lead them around and fight one at a time.",
    enemies: [
      { pos: { x: 1150, y: 350 }, level: 3 },
      { pos: { x: 1350, y: 650 }, level: 3 },
      { pos: { x: 1600, y: 880 }, level: 4 }
    ],
    pickups: [{ pos: { x: 1750, y: 320 }, kind: "move" }],
    water: [{ x: 600, y: 260, width: 120, height: 764 }],
    climbWalls: [{ x: 1000, y: 260, width: 110, height: 400 }]
  },
  {
    title: "Invader's Camp",
    area: "beach",
    hint: "General Wobble runs the beach invasion. Show him what a real hero slime can do!",
    enemies: [
      { pos: { x: 1100, y: 850 }, level: 2 },
      { pos: { x: 1500, y: 620 }, level: 5, boss: true }
    ],
    pickups: [{ pos: { x: 350, y: 400 }, kind: "heal" }],
    water: [],
    climbWalls: []
  },
  {
    title: "Forest Edge",
    area: "forest",
    hint: "The forest! Slimes grow bigger under the trees. Hop the stream if you need to shake off a chaser.",
    enemies: [
      { pos: { x: 1250, y: 420 }, level: 4 },
      { pos: { x: 1500, y: 780 }, level: 4 }
    ],
    pickups: [{ pos: { x: 350, y: 420 }, kind: "heal" }],
    water: [{ x: 760, y: 260, width: 120, height: 764 }],
    climbWalls: []
  },
  {
    title: "Deep Woods",
    area: "forest",
    hint: "It is dark in here. These bullies hit hard. Sand Throw makes them gentler, and Goo Shield never goes out of style.",
    enemies: [
      { pos: { x: 1200, y: 380 }, level: 5 },
      { pos: { x: 1400, y: 860 }, level: 4 },
      { pos: { x: 1650, y: 560 }, level: 5 }
    ],
    pickups: [{ pos: { x: 1780, y: 330 }, kind: "move" }],
    water: [],
    climbWalls: [{ x: 950, y: 260, width: 110, height: 500 }]
  },
  {
    title: "Heart of the Forest",
    area: "forest",
    hint: "Duke Mulch, the forest boss! Shield before his big slams, and do not be shy about healing.",
    enemies: [
      { pos: { x: 1050, y: 850 }, level: 4 },
      { pos: { x: 1500, y: 600 }, level: 6, boss: true }
    ],
    pickups: [{ pos: { x: 330, y: 380 }, kind: "heal" }],
    water: [],
    climbWalls: []
  }
];

export function getMove(moveId) {
  return ALL_MOVES[moveId] || {
    name: moveId,
    type: "slime",
    effect: "damage",
    power: 1,
    description: "Unknown move."
  };
}

export function randomRewardChoices(count, exclude = []) {
  const options = REWARD_POOL.filter((moveId) => !exclude.includes(moveId));
  for (let i = options.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [options[i], options[j]] = [options[j], options[i]];
  }
  return options.slice(0, count);
}

export function makeEnemyStats(level = 1, isBoss = false) {
  const names = {
    1: "Baby Red",
    2: "Red Slime",
    3: "Angry Red",
    4: "Slime Bruiser",
    5: "Slime Bully",
    6: "Camo Red",
    7: "Elder Red"
  };
  const bossNames = {
    5: "General Wobble",
    6: "Duke Mulch"
  };
  const moves = ["tackle"];
  if (level >= 2) moves.push("chomp");
  if (level >= 4) moves.push("war_cry");

  const stats = {
    name: names[level] || "Red Slime",
    level,
    isBoss,
    maxHp: 14 + level * 7,
    attack: 1 + level * 2,
    moves,
    xp: 10 + level * 5,
    spriteScale: 1 + (level - 1) * 0.06
  };

  if (isBoss) {
    stats.name = bossNames[level] || "General Wobble";
    stats.maxHp = Math.round(stats.maxHp * 1.7);
    stats.moves = ["chomp", "big_slam", "war_cry"];
    stats.xp = Math.round(stats.xp * 2);
    stats.spriteScale = 1.5;
  }

  stats.hp = stats.maxHp;
  return stats;
}
