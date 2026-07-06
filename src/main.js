import * as THREE from "three";
import "./styles.css";
import {
  ALL_MOVES,
  ASSETS,
  BORDER,
  DAMAGE_WIGGLE_HIGH,
  DAMAGE_WIGGLE_LOW,
  ENEMY_TUNING,
  EXIT_RECT,
  HEAL_AMOUNT,
  LEVEL_UP_ATTACK_BONUS,
  LEVEL_UP_HP_BONUS,
  MAX_LOADOUT_SIZE,
  PLAYER_BASE_ATTACK,
  PLAYER_BASE_MAX_HP,
  PLAYER_SPAWN,
  PLAYER_TUNING,
  ROOM_CLEAR_HEAL,
  ROOM_SIZE,
  ROOMS,
  STARTING_LOADOUT,
  TOP_WALL_HEIGHT,
  TYPE_COLORS,
  TYPE_MULTIPLIER,
  XP_PER_LEVEL,
  getMove,
  makeEnemyStats,
  randomRewardChoices
} from "./data.js";

const clamp = (value, min, max) => Math.min(max, Math.max(min, value));
const lerp = (from, to, t) => from + (to - from) * t;
const length = (x, y) => Math.hypot(x, y);
const wait = (ms) => new Promise((resolve) => window.setTimeout(resolve, ms));

function pointInRect(point, rect) {
  return (
    point.x >= rect.x &&
    point.x <= rect.x + rect.width &&
    point.y >= rect.y &&
    point.y <= rect.y + rect.height
  );
}

function rectCenter(rect) {
  return { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 };
}

function expandRect(rect, amount) {
  return {
    x: rect.x - amount,
    y: rect.y - amount,
    width: rect.width + amount * 2,
    height: rect.height + amount * 2
  };
}

function shrinkRect(rect, amount) {
  return {
    x: rect.x + amount,
    y: rect.y + amount,
    width: Math.max(24, rect.width - amount * 2),
    height: Math.max(24, rect.height - amount * 2)
  };
}

function circleRectOverlap(point, radius, rect) {
  const nearestX = clamp(point.x, rect.x, rect.x + rect.width);
  const nearestY = clamp(point.y, rect.y, rect.y + rect.height);
  return length(point.x - nearestX, point.y - nearestY) <= radius;
}

function setWorldPosition(object, point, z = 0) {
  object.position.set(point.x, -point.y, z);
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

class RunState {
  constructor() {
    this.reset();
  }

  reset() {
    this.playerLevel = 1;
    this.playerXp = 0;
    this.playerMaxHp = PLAYER_BASE_MAX_HP;
    this.playerHp = PLAYER_BASE_MAX_HP;
    this.playerAttack = PLAYER_BASE_ATTACK;
    this.loadout = [...STARTING_LOADOUT];
    this.currentRoom = 1;
    this.battlesWon = 0;
    this.runWon = false;
  }

  roomConfig() {
    return ROOMS[clamp(this.currentRoom - 1, 0, ROOMS.length - 1)];
  }

  totalRooms() {
    return ROOMS.length;
  }

  isLastRoom() {
    return this.currentRoom >= ROOMS.length;
  }

  advanceRoom() {
    this.currentRoom += 1;
    this.playerHp = Math.min(this.playerHp + ROOM_CLEAR_HEAL, this.playerMaxHp);
  }

  xpToNextLevel() {
    return XP_PER_LEVEL * this.playerLevel;
  }

  addXp(amount) {
    this.playerXp += amount;
    let levelsGained = 0;
    while (this.playerXp >= this.xpToNextLevel()) {
      this.playerXp -= this.xpToNextLevel();
      this.playerLevel += 1;
      levelsGained += 1;
      this.playerMaxHp += LEVEL_UP_HP_BONUS;
      this.playerAttack += LEVEL_UP_ATTACK_BONUS;
      this.playerHp = Math.min(this.playerHp + LEVEL_UP_HP_BONUS * 2, this.playerMaxHp);
    }
    return levelsGained;
  }
}

class SlimaniaGame {
  constructor() {
    this.gameEl = document.querySelector("#game");
    this.hudEl = document.querySelector("#hud");
    this.overlayEl = document.querySelector("#overlay");
    this.run = new RunState();
    this.keys = new Set();
    this.jumpPressed = false;
    this.clock = new THREE.Clock();
    this.textureLoader = new THREE.TextureLoader();
    this.textures = {};
    this.state = "loading";
    this.scene = null;
    this.camera = null;
    this.renderer = null;
    this.player = null;
    this.enemies = [];
    this.pickups = [];
    this.obstacles = [];
    this.borderRects = [];
    this.climbWalls = [];
    this.waterRects = [];
    this.exitOpen = false;
    this.exitGate = null;
    this.exitSign = null;
    this.battleCooldown = 0;
    this.toastTimer = 0;
    this.resizeObserver = null;
    this.hudRefs = {};
  }

  async start() {
    await this.loadTextures();
    this.initThree();
    this.bindEvents();
    this.showTitle();
    this.clock.start();
    this.animate();
  }

  async loadTextures() {
    const entries = Object.entries(ASSETS);
    await Promise.all(
      entries.map(([key, url]) =>
        new Promise((resolve, reject) => {
          this.textureLoader.load(
            url,
            (texture) => {
              texture.colorSpace = THREE.SRGBColorSpace;
              texture.minFilter = THREE.LinearFilter;
              texture.magFilter = THREE.LinearFilter;
              this.textures[key] = texture;
              resolve();
            },
            undefined,
            reject
          );
        })
      )
    );
  }

  initThree() {
    this.renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    this.gameEl.appendChild(this.renderer.domElement);

    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0x102016);
    this.camera = new THREE.OrthographicCamera(-640, 640, 360, -360, 0.1, 2000);
    this.camera.position.set(PLAYER_SPAWN.x, -PLAYER_SPAWN.y, 1000);
    this.camera.lookAt(PLAYER_SPAWN.x, -PLAYER_SPAWN.y, 0);
    this.resize();
  }

  bindEvents() {
    window.addEventListener("resize", () => this.resize());
    window.addEventListener("keydown", (event) => {
      if (["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "Space"].includes(event.code)) {
        event.preventDefault();
      }
      if (event.code === "Space" && !event.repeat) {
        this.jumpPressed = true;
      }
      this.keys.add(event.code);

      if (event.code === "Enter" && (this.state === "title" || this.state === "gameOver")) {
        this.startRun();
      }

      if (this.state === "battle" && /^Digit[1-4]$/.test(event.code)) {
        const index = Number(event.code.replace("Digit", "")) - 1;
        const button = this.overlayEl.querySelector(`[data-move-index="${index}"]`);
        button?.click();
      }
    });
    window.addEventListener("keyup", (event) => {
      this.keys.delete(event.code);
    });
  }

  resize() {
    const width = this.gameEl.clientWidth || window.innerWidth;
    const height = this.gameEl.clientHeight || window.innerHeight;
    this.renderer.setSize(width, height, false);

    const aspect = width / Math.max(1, height);
    let visibleHeight = 720;
    let visibleWidth = visibleHeight * aspect;
    if (visibleWidth > ROOM_SIZE.width) {
      visibleWidth = ROOM_SIZE.width;
      visibleHeight = visibleWidth / aspect;
    }
    visibleHeight = Math.min(ROOM_SIZE.height, visibleHeight);
    visibleWidth = visibleHeight * aspect;

    this.camera.left = -visibleWidth / 2;
    this.camera.right = visibleWidth / 2;
    this.camera.top = visibleHeight / 2;
    this.camera.bottom = -visibleHeight / 2;
    this.camera.updateProjectionMatrix();
  }

  showTitle() {
    this.state = "title";
    this.hudEl.classList.add("hidden");
    this.overlayEl.className = "overlay title-screen";
    this.overlayEl.style.setProperty("--title-bg", `url("${ASSETS.skybox}")`);
    this.overlayEl.innerHTML = `
      <div class="title-content">
        <img class="title-logo" src="${ASSETS.logoInvaded}" alt="Slimania" />
        <p class="title-copy">Goopzz is back on the beach. Eight rooms of red invader slimes stand between him and a clean run.</p>
        <div class="button-row">
          <button class="command" data-action="start">Start run</button>
        </div>
      </div>
    `;
    this.overlayEl.querySelector("[data-action='start']").addEventListener("click", () => this.startRun());
  }

  startRun() {
    this.run.reset();
    this.state = "overworld";
    this.overlayEl.className = "overlay hidden";
    this.overlayEl.innerHTML = "";
    this.hudEl.classList.remove("hidden");
    this.loadRoom();
  }

  clearScene() {
    while (this.scene.children.length > 0) {
      this.scene.remove(this.scene.children[0]);
    }
  }

  loadRoom() {
    this.clearScene();
    this.enemies = [];
    this.pickups = [];
    this.obstacles = [];
    this.borderRects = [];
    this.climbWalls = [];
    this.waterRects = [];
    this.exitOpen = false;
    this.exitGate = null;
    this.battleCooldown = 0;

    const config = this.run.roomConfig();
    this.buildBackdrop(config);
    this.buildBorders();
    this.buildClimbWalls(config);
    this.buildWater(config);
    this.buildExit();
    this.buildPlayer();
    this.buildEnemies(config);
    this.buildPickups(config);
    this.buildHud(config);
    this.updateHud();
    this.showToast(`Room ${this.run.currentRoom}/${this.run.totalRooms()} - ${config.title}`);
  }

  buildBackdrop(config) {
    const texture = config.area === "forest" ? this.textures.forestGround : this.textures.beachSand;
    const ground = this.makeTexturedPlane(texture, ROOM_SIZE.width, ROOM_SIZE.height);
    ground.position.set(ROOM_SIZE.width / 2, -ROOM_SIZE.height / 2, -20);
    ground.renderOrder = 0;
    this.scene.add(ground);

    if (config.area !== "beach") {
      this.scene.add(this.makeRectMesh({ x: 0, y: 0, width: ROOM_SIZE.width, height: TOP_WALL_HEIGHT }, 0x132a18, 1, -10));
      this.scene.add(this.makeRectMesh({ x: 0, y: TOP_WALL_HEIGHT - 14, width: ROOM_SIZE.width, height: 14 }, 0x285536, 1, -9));
    }
  }

  buildBorders() {
    const top = { x: 0, y: 0, width: ROOM_SIZE.width, height: TOP_WALL_HEIGHT };
    const left = { x: 0, y: 0, width: BORDER, height: ROOM_SIZE.height };
    const bottom = { x: 0, y: ROOM_SIZE.height - BORDER, width: ROOM_SIZE.width, height: BORDER };
    const rightTop = { x: ROOM_SIZE.width - BORDER, y: 0, width: BORDER, height: EXIT_RECT.y };
    const rightBottom = {
      x: ROOM_SIZE.width - BORDER,
      y: EXIT_RECT.y + EXIT_RECT.height,
      width: BORDER,
      height: ROOM_SIZE.height - (EXIT_RECT.y + EXIT_RECT.height)
    };
    this.borderRects.push(top, left, bottom, rightTop, rightBottom);
    this.obstacles.push(...this.borderRects);
    [left, bottom, rightTop, rightBottom].forEach((rect) => {
      this.scene.add(this.makeRectMesh(rect, 0x0d0d0d, 0.95, 5));
    });
  }

  buildClimbWalls(config) {
    this.climbWalls = [...config.climbWalls];
    this.climbWalls.forEach((rect) => {
      this.scene.add(this.makeRectMesh(rect, 0x7a6b57, 1, 8));
      this.scene.add(this.makeRectMesh({ x: rect.x, y: rect.y, width: rect.width, height: 16 }, 0xa18d73, 1, 9));
      this.scene.add(this.makeRectMesh({ x: rect.x, y: rect.y + rect.height - 12, width: rect.width, height: 12 }, 0x554839, 1, 9));
      const label = this.makeTextSprite("hold SHIFT\nto climb", {
        fontSize: 38,
        width: 280,
        height: 96,
        color: "#fff1bd"
      });
      setWorldPosition(label, { x: rect.x + rect.width / 2, y: rect.y + 74 }, 45);
      label.scale.set(140, 48, 1);
      this.scene.add(label);
    });
  }

  buildWater(config) {
    this.waterRects = [...config.water];
    this.waterRects.forEach((rect) => {
      this.scene.add(this.makeRectMesh(expandRect(rect, 6), 0xd9f4ff, 0.45, 6));
      this.scene.add(this.makeRectMesh(rect, 0x357fc7, 0.78, 7));
    });
  }

  buildExit() {
    const sign = this.makeTextSprite("EXIT ->", {
      fontSize: 42,
      width: 240,
      height: 70,
      color: "#ff9a7d"
    });
    setWorldPosition(sign, { x: EXIT_RECT.x - 88, y: EXIT_RECT.y + EXIT_RECT.height / 2 }, 50);
    sign.scale.set(160, 46, 1);
    this.exitSign = sign;
    this.scene.add(sign);

    this.exitGate = new THREE.Group();
    this.exitGate.add(this.makeRectMesh(EXIT_RECT, 0xb33333, 0.92, 12));
    const lock = this.makeTextSprite("clear all\nslimes", {
      fontSize: 32,
      width: 180,
      height: 90,
      color: "#ffe0dd"
    });
    setWorldPosition(lock, rectCenter(EXIT_RECT), 55);
    lock.scale.set(100, 50, 1);
    this.exitGate.add(lock);
    this.scene.add(this.exitGate);
    this.obstacles.push(EXIT_RECT);
  }

  buildPlayer() {
    const group = new THREE.Group();
    const shadow = this.makeShadow(48, 20, 0.28);
    const sprite = this.makeSprite("goopzz", 94);
    sprite.position.z = 32;
    group.add(shadow);
    group.add(sprite);
    setWorldPosition(group, PLAYER_SPAWN, 0);
    this.scene.add(group);

    this.player = {
      pos: { ...PLAYER_SPAWN },
      velocity: { x: 0, y: 0 },
      group,
      sprite,
      shadow,
      baseHeight: 94,
      isAirborne: false,
      jumpTimeLeft: 0,
      jumpCooldownLeft: 0,
      climbStamina: PLAYER_TUNING.climbMaxStamina,
      isClimbing: false,
      isSlipping: false,
      slipElapsed: 0,
      slipDuration: 0,
      slipFrom: { ...PLAYER_SPAWN },
      slipTo: { ...PLAYER_SPAWN },
      climbEntryPoint: { ...PLAYER_SPAWN },
      lastSafePosition: { ...PLAYER_SPAWN },
      hurtTimer: 0,
      wobbleTime: 0
    };
    this.snapCameraToPlayer();
  }

  buildEnemies(config) {
    config.enemies.forEach((enemyConfig) => {
      const stats = makeEnemyStats(enemyConfig.level, Boolean(enemyConfig.boss));
      const sizeScale = stats.spriteScale;
      const group = new THREE.Group();
      const shadow = this.makeShadow(42 * sizeScale, 18 * sizeScale, 0.24);
      const sprite = this.makeSprite("enemySlime", 78 * sizeScale);
      sprite.position.z = 30;
      group.add(shadow);
      group.add(sprite);
      const label = this.makeTextSprite(`${stats.name}  Lv ${stats.level}`, {
        fontSize: 30,
        width: 320,
        height: 62,
        color: "#ffd1cf"
      });
      label.scale.set(160, 31, 1);
      label.position.set(0, 62 * sizeScale, 52);
      group.add(label);
      setWorldPosition(group, enemyConfig.pos, 0);
      this.scene.add(group);
      this.enemies.push({
        pos: { ...enemyConfig.pos },
        velocity: { x: 0, y: 0 },
        group,
        sprite,
        shadow,
        stats,
        radius: 28 * sizeScale,
        wanderDirection: { x: 0, y: 0 },
        wanderTimer: 0,
        wobbleTime: Math.random() * 10,
        removed: false,
        isChasing: false
      });
    });
  }

  buildPickups(config) {
    config.pickups.forEach((pickupConfig) => {
      const group = new THREE.Group();
      if (pickupConfig.kind === "heal") {
        const glow = new THREE.Mesh(
          new THREE.CircleGeometry(28, 32),
          new THREE.MeshBasicMaterial({
            color: 0xff72a2,
            transparent: true,
            opacity: 0.88,
            depthWrite: false
          })
        );
        glow.position.z = 25;
        group.add(glow);
      } else {
        const disc = this.makeSprite("moveDisc", 64);
        disc.position.z = 28;
        group.add(disc);
      }
      const caption = this.makeTextSprite(pickupConfig.kind === "heal" ? `+${HEAL_AMOUNT} HP` : "Move Disc", {
        fontSize: 30,
        width: 220,
        height: 60,
        color: pickupConfig.kind === "heal" ? "#ffd2df" : "#c5ffd1"
      });
      caption.scale.set(130, 36, 1);
      caption.position.set(0, -42, 48);
      group.add(caption);
      setWorldPosition(group, pickupConfig.pos, 0);
      this.scene.add(group);
      this.pickups.push({
        kind: pickupConfig.kind,
        pos: { ...pickupConfig.pos },
        group,
        bobTime: Math.random() * Math.PI * 2,
        removed: false
      });
    });
  }

  buildHud(config) {
    this.hudEl.innerHTML = `
      <div class="hud-panel vitals">
        <div class="large" data-ref="playerName"></div>
        <div class="stat-row">
          <span class="label">HP</span>
          <div class="bar" style="--bar-color:#54d878"><span data-ref="hpBar"></span></div>
          <span class="small" data-ref="hpText"></span>
        </div>
        <div class="small" data-ref="attackText"></div>
        <div class="stat-row">
          <span class="label">XP</span>
          <div class="bar" style="--bar-color:#b286df"><span data-ref="xpBar"></span></div>
          <span class="small" data-ref="xpText"></span>
        </div>
      </div>
      <div class="hud-panel room-status">
        <div class="large">Room ${this.run.currentRoom}/${this.run.totalRooms()} - ${escapeHtml(config.title)}</div>
        <div class="small" data-ref="slimesText"></div>
      </div>
      <div class="hud-panel moves">
        <div class="label">Moves</div>
        <div class="move-list" data-ref="moveList"></div>
      </div>
      <div class="hud-panel meters">
        <div class="meter-row">
          <span class="label">Hop</span>
          <div class="bar" style="--bar-color:#fee17a"><span data-ref="jumpBar"></span></div>
          <span></span>
        </div>
        <div class="meter-row">
          <span class="label">Grip</span>
          <div class="bar" style="--bar-color:#df9143"><span data-ref="climbBar"></span></div>
          <span></span>
        </div>
      </div>
      <div class="hud-panel guide">
        <img src="${ASSETS.helpSlime}" alt="Blurpo" />
        <div class="guide-copy">
          <div class="label">Blurpo</div>
          <div>${escapeHtml(config.hint)}</div>
        </div>
      </div>
      <div class="toast" data-ref="toast"></div>
    `;
    this.hudRefs = {};
    this.hudEl.querySelectorAll("[data-ref]").forEach((node) => {
      this.hudRefs[node.dataset.ref] = node;
    });
  }

  animate() {
    window.requestAnimationFrame(() => this.animate());
    const delta = Math.min(0.033, this.clock.getDelta());
    if (this.state === "overworld") {
      this.updateOverworld(delta);
    }
    this.renderer.render(this.scene, this.camera);
  }

  updateOverworld(delta) {
    this.battleCooldown = Math.max(0, this.battleCooldown - delta);
    this.updatePlayer(delta);
    this.updateEnemies(delta);
    this.updatePickups(delta);
    this.checkExit();
    this.updateCamera(delta);
    this.updateHud();
  }

  updatePlayer(delta) {
    const player = this.player;
    if (!player) return;
    player.jumpCooldownLeft = Math.max(0, player.jumpCooldownLeft - delta);
    player.hurtTimer = Math.max(0, player.hurtTimer - delta);

    if (player.isSlipping) {
      player.slipElapsed += delta;
      const progress = clamp(player.slipElapsed / player.slipDuration, 0, 1);
      const eased = 1 - Math.pow(1 - progress, 2);
      player.pos.x = lerp(player.slipFrom.x, player.slipTo.x, eased);
      player.pos.y = lerp(player.slipFrom.y, player.slipTo.y, eased);
      if (progress >= 1) player.isSlipping = false;
      this.applyPlayerVisual(delta);
      return;
    }

    this.handleClimbing(delta);
    this.handleJumping(delta);

    const input = this.inputDirection();
    let speed = PLAYER_TUNING.moveSpeed;
    if (player.isClimbing) speed = PLAYER_TUNING.climbSpeed;
    if (player.isAirborne) speed = PLAYER_TUNING.airSpeed;

    const next = {
      x: player.pos.x + input.x * speed * delta,
      y: player.pos.y + input.y * speed * delta
    };
    this.movePlayerAxis(next);
    player.velocity = { x: input.x * speed, y: input.y * speed };

    if (!player.isAirborne && !player.isClimbing && !this.playerTouchesWater()) {
      player.lastSafePosition = { ...player.pos };
    }

    this.handleWater();
    this.applyPlayerVisual(delta);
  }

  inputDirection() {
    const left = this.keys.has("KeyA") || this.keys.has("ArrowLeft");
    const right = this.keys.has("KeyD") || this.keys.has("ArrowRight");
    const up = this.keys.has("KeyW") || this.keys.has("ArrowUp");
    const down = this.keys.has("KeyS") || this.keys.has("ArrowDown");
    let x = (right ? 1 : 0) - (left ? 1 : 0);
    let y = (down ? 1 : 0) - (up ? 1 : 0);
    const magnitude = length(x, y);
    if (magnitude > 0) {
      x /= magnitude;
      y /= magnitude;
    }
    return { x, y };
  }

  handleJumping(delta) {
    const player = this.player;
    if (
      this.jumpPressed &&
      !player.isAirborne &&
      !player.isClimbing &&
      player.jumpCooldownLeft <= 0
    ) {
      player.isAirborne = true;
      player.jumpTimeLeft = PLAYER_TUNING.jumpDuration;
      player.jumpCooldownLeft = PLAYER_TUNING.jumpCooldown + PLAYER_TUNING.jumpDuration;
    }
    this.jumpPressed = false;

    if (player.isAirborne) {
      player.jumpTimeLeft -= delta;
      if (player.jumpTimeLeft <= 0) {
        player.isAirborne = false;
        player.jumpTimeLeft = 0;
      }
    }
  }

  handleClimbing(delta) {
    const player = this.player;
    const shiftDown = this.keys.has("ShiftLeft") || this.keys.has("ShiftRight");
    const onWall = this.insideClimbWall(player.pos);
    const inZone = this.inClimbZone(player.pos);

    if (player.isClimbing) {
      player.climbStamina -= delta;
      if (!inZone && !onWall) {
        this.stopClimbing();
      } else if (player.climbStamina <= 0 || !shiftDown) {
        if (onWall) {
          this.slipPlayerTo(player.climbEntryPoint, 0.45);
          player.climbStamina = 0;
          this.stopClimbing();
        } else {
          this.stopClimbing();
        }
      }
      return;
    }

    player.climbStamina = Math.min(
      PLAYER_TUNING.climbMaxStamina,
      player.climbStamina + PLAYER_TUNING.climbRechargeRate * delta
    );
    if (
      shiftDown &&
      inZone &&
      player.climbStamina >= PLAYER_TUNING.climbMaxStamina * 0.5 &&
      !player.isAirborne
    ) {
      player.isClimbing = true;
      player.climbEntryPoint = { ...player.pos };
      player.sprite.material.color.set(0xffffff);
    }
  }

  stopClimbing() {
    if (!this.player) return;
    this.player.isClimbing = false;
    this.player.sprite.material.color.set(0xffffff);
  }

  insideClimbWall(point) {
    return this.climbWalls.some((rect) => pointInRect(point, rect));
  }

  inClimbZone(point) {
    return this.climbWalls.some((rect) => circleRectOverlap(point, 20, expandRect(rect, 34)));
  }

  movePlayerAxis(target) {
    const player = this.player;
    const radius = 26;
    const xCandidate = { x: target.x, y: player.pos.y };
    if (!this.isPlayerBlocked(xCandidate, radius)) {
      player.pos.x = xCandidate.x;
    }
    const yCandidate = { x: player.pos.x, y: target.y };
    if (!this.isPlayerBlocked(yCandidate, radius)) {
      player.pos.y = yCandidate.y;
    }
  }

  isPlayerBlocked(point, radius) {
    const rects = [...this.obstacles];
    if (!this.player?.isClimbing) rects.push(...this.climbWalls);
    return rects.some((rect) => circleRectOverlap(point, radius, rect));
  }

  playerTouchesWater() {
    return this.waterRects.some((rect) => circleRectOverlap(this.player.pos, 20, shrinkRect(rect, 24)));
  }

  handleWater() {
    const player = this.player;
    if (this.playerTouchesWater() && !player.isAirborne && player.hurtTimer <= 0) {
      this.run.playerHp = Math.max(0, this.run.playerHp - PLAYER_TUNING.waterDamage);
      player.hurtTimer = PLAYER_TUNING.hurtSafetyTime;
      this.slipPlayerTo(player.lastSafePosition, 0.3);
      this.showToast(`Water sting! -${PLAYER_TUNING.waterDamage} HP`);
      if (this.run.playerHp <= 0) {
        this.endRun(false);
      }
    }
  }

  slipPlayerTo(target, duration) {
    const player = this.player;
    player.isSlipping = true;
    player.slipElapsed = 0;
    player.slipDuration = duration;
    player.slipFrom = { ...player.pos };
    player.slipTo = { ...target };
    player.velocity = { x: 0, y: 0 };
  }

  applyPlayerVisual(delta) {
    const player = this.player;
    player.wobbleTime += delta;
    const moving = length(player.velocity.x, player.velocity.y) > 10 && !player.isAirborne;
    const jumpProgress = player.isAirborne
      ? 1 - player.jumpTimeLeft / PLAYER_TUNING.jumpDuration
      : 1;
    const lift = player.isAirborne ? Math.sin(jumpProgress * Math.PI) * PLAYER_TUNING.jumpHeight : 0;
    player.sprite.position.y = lift;
    player.sprite.material.map = player.hurtTimer > 0 ? this.textures.goopzzAngry : this.textures.goopzz;
    if (moving) {
      const wobble = Math.sin(player.wobbleTime * 14) * 0.06;
      const aspect = this.spriteAspect("goopzz");
      const facing = player.velocity.x < -1 ? -1 : 1;
      player.sprite.scale.set(player.baseHeight * aspect * (1 + wobble) * facing, player.baseHeight * (1 - wobble), 1);
    } else {
      const aspect = this.spriteAspect("goopzz");
      player.sprite.scale.set(player.baseHeight * aspect, player.baseHeight, 1);
    }
    player.shadow.scale.set(player.isAirborne ? 36 : 48, player.isAirborne ? 15 : 20, 1);
    setWorldPosition(player.group, player.pos, 0);
  }

  updateEnemies(delta) {
    this.enemies.forEach((enemy) => {
      if (enemy.removed) return;
      const distanceToPlayer = length(enemy.pos.x - this.player.pos.x, enemy.pos.y - this.player.pos.y);
      enemy.isChasing = distanceToPlayer < ENEMY_TUNING.detectRadius;
      let direction = { x: 0, y: 0 };
      let speed = ENEMY_TUNING.wanderSpeed;

      if (enemy.isChasing) {
        direction = {
          x: (this.player.pos.x - enemy.pos.x) / Math.max(1, distanceToPlayer),
          y: (this.player.pos.y - enemy.pos.y) / Math.max(1, distanceToPlayer)
        };
        speed = ENEMY_TUNING.chaseSpeed;
        enemy.sprite.material.map = this.textures.enemySlimeAttacking;
      } else {
        enemy.wanderTimer -= delta;
        if (enemy.wanderTimer <= 0) {
          enemy.wanderTimer = 1.5 + Math.random() * 1.5;
          if (Math.random() < 0.3) {
            enemy.wanderDirection = { x: 0, y: 0 };
          } else {
            const angle = Math.random() * Math.PI * 2;
            enemy.wanderDirection = { x: Math.cos(angle), y: Math.sin(angle) };
          }
        }
        direction = enemy.wanderDirection;
        enemy.sprite.material.map = this.textures.enemySlime;
      }

      enemy.velocity = { x: direction.x * speed, y: direction.y * speed };
      this.moveEnemyAxis(enemy, {
        x: enemy.pos.x + enemy.velocity.x * delta,
        y: enemy.pos.y + enemy.velocity.y * delta
      });
      this.applyEnemyVisual(enemy, delta);

      if (this.battleCooldown <= 0 && distanceToPlayer <= enemy.radius + 28) {
        this.startBattle(enemy);
      }
    });
  }

  moveEnemyAxis(enemy, target) {
    const xCandidate = { x: target.x, y: enemy.pos.y };
    if (!this.isEnemyBlocked(xCandidate, enemy.radius)) {
      enemy.pos.x = xCandidate.x;
    } else if (!enemy.isChasing) {
      enemy.wanderTimer = 0;
    }
    const yCandidate = { x: enemy.pos.x, y: target.y };
    if (!this.isEnemyBlocked(yCandidate, enemy.radius)) {
      enemy.pos.y = yCandidate.y;
    } else if (!enemy.isChasing) {
      enemy.wanderTimer = 0;
    }
  }

  isEnemyBlocked(point, radius) {
    const rects = [...this.obstacles, ...this.climbWalls, ...this.waterRects];
    return rects.some((rect) => circleRectOverlap(point, radius, rect));
  }

  applyEnemyVisual(enemy, delta) {
    enemy.wobbleTime += delta;
    const moving = length(enemy.velocity.x, enemy.velocity.y) > 5;
    const baseHeight = 78 * enemy.stats.spriteScale;
    const aspect = this.spriteAspect("enemySlime");
    const facing = enemy.velocity.x < -1 ? -1 : 1;
    if (moving) {
      const wobble = Math.sin(enemy.wobbleTime * 10) * 0.05;
      enemy.sprite.scale.set(baseHeight * aspect * (1 + wobble) * facing, baseHeight * (1 - wobble), 1);
    } else {
      enemy.sprite.scale.set(baseHeight * aspect, baseHeight, 1);
    }
    setWorldPosition(enemy.group, enemy.pos, 0);
  }

  updatePickups(delta) {
    this.pickups.forEach((pickup) => {
      if (pickup.removed) return;
      pickup.bobTime += delta * 4;
      pickup.group.position.z = Math.sin(pickup.bobTime) * 8;
      const distanceToPlayer = length(pickup.pos.x - this.player.pos.x, pickup.pos.y - this.player.pos.y);
      if (distanceToPlayer < 58) {
        this.collectPickup(pickup);
      }
    });
  }

  async collectPickup(pickup) {
    if (pickup.removed) return;
    pickup.removed = true;
    this.scene.remove(pickup.group);
    if (pickup.kind === "heal") {
      const healed = Math.min(HEAL_AMOUNT, this.run.playerMaxHp - this.run.playerHp);
      this.run.playerHp += healed;
      this.showToast(`Mmm, jelly! +${healed} HP`);
      return;
    }

    const choices = randomRewardChoices(3, this.run.loadout);
    if (choices.length === 0) {
      this.run.addXp(10);
      this.showToast("You already know every move. +10 XP");
      return;
    }
    this.state = "paused";
    await this.showMoveLearn(choices, "You found a Move Disc!");
    this.overlayEl.className = "overlay hidden";
    this.overlayEl.innerHTML = "";
    this.state = "overworld";
    this.updateHud();
  }

  checkExit() {
    if (!this.exitOpen || !this.player) return;
    if (!pointInRect(this.player.pos, EXIT_RECT)) return;
    this.exitOpen = false;
    if (this.run.isLastRoom()) {
      this.run.runWon = true;
      this.endRun(true);
      return;
    }
    this.run.advanceRoom();
    this.loadRoom();
  }

  openExit() {
    this.exitOpen = true;
    this.obstacles = this.obstacles.filter((rect) => rect !== EXIT_RECT);
    if (this.exitGate) {
      this.scene.remove(this.exitGate);
      this.exitGate = null;
    }
    if (this.exitSign) {
      this.exitSign.material.color.set("#89ff94");
    }
    this.showToast("Room clear! The exit is open.");
  }

  updateCamera(delta) {
    const halfWidth = (this.camera.right - this.camera.left) / 2;
    const halfHeight = (this.camera.top - this.camera.bottom) / 2;
    const targetX = clamp(this.player.pos.x, halfWidth, ROOM_SIZE.width - halfWidth);
    const targetY = clamp(this.player.pos.y, halfHeight, ROOM_SIZE.height - halfHeight);
    const follow = Math.min(1, delta * 8);
    this.camera.position.x = lerp(this.camera.position.x, targetX, follow);
    this.camera.position.y = lerp(this.camera.position.y, -targetY, follow);
    this.camera.lookAt(this.camera.position.x, this.camera.position.y, 0);
  }

  snapCameraToPlayer() {
    this.camera.position.x = this.player.pos.x;
    this.camera.position.y = -this.player.pos.y;
    this.camera.lookAt(this.camera.position.x, this.camera.position.y, 0);
  }

  updateHud() {
    if (!this.hudRefs.playerName || !this.player) return;
    const hpPercent = (this.run.playerHp / this.run.playerMaxHp) * 100;
    const xpPercent = (this.run.playerXp / this.run.xpToNextLevel()) * 100;
    const jumpReady =
      1 -
      clamp(
        this.player.jumpCooldownLeft / (PLAYER_TUNING.jumpCooldown + PLAYER_TUNING.jumpDuration),
        0,
        1
      );
    const climbReady = clamp(this.player.climbStamina / PLAYER_TUNING.climbMaxStamina, 0, 1);

    this.hudRefs.playerName.textContent = `Goopzz  Lv ${this.run.playerLevel}`;
    this.hudRefs.hpBar.style.width = `${hpPercent}%`;
    this.hudRefs.hpText.textContent = `${this.run.playerHp} / ${this.run.playerMaxHp}`;
    this.hudRefs.attackText.textContent = `Attack: ${this.run.playerAttack}`;
    this.hudRefs.xpBar.style.width = `${xpPercent}%`;
    this.hudRefs.xpText.textContent = `${this.run.playerXp} / ${this.run.xpToNextLevel()}`;
    this.hudRefs.jumpBar.style.width = `${jumpReady * 100}%`;
    this.hudRefs.climbBar.style.width = `${climbReady * 100}%`;
    const remaining = this.enemies.filter((enemy) => !enemy.removed).length;
    this.hudRefs.slimesText.textContent = remaining > 0 ? `Slimes left: ${remaining}` : "Head for the exit!";
    this.hudRefs.moveList.innerHTML = this.run.loadout
      .map((moveId, index) => {
        const move = getMove(moveId);
        return `
          <div class="move-chip">
            <span>${index + 1}</span>
            <strong>${escapeHtml(move.name)}</strong>
            <span style="color:${TYPE_COLORS[move.type] || "#ffffff"}">${escapeHtml(move.type)}</span>
          </div>
        `;
      })
      .join("");
  }

  showToast(text) {
    const toast = this.hudRefs.toast;
    if (!toast) return;
    toast.textContent = text;
    toast.classList.add("show");
    window.clearTimeout(this.toastTimer);
    this.toastTimer = window.setTimeout(() => {
      toast.classList.remove("show");
    }, 1700);
  }

  startBattle(enemy) {
    if (this.state !== "overworld" || enemy.removed) return;
    this.state = "battle";
    const battle = {
      enemyRef: enemy,
      enemyStats: {
        ...enemy.stats,
        moves: [...enemy.stats.moves]
      },
      playerShielded: false,
      playerAttackBonus: 0,
      enemyAttackBonus: 0,
      busy: true
    };
    this.battle = battle;
    this.renderBattle();
    this.beginBattle();
  }

  async beginBattle() {
    const { enemyStats } = this.battle;
    this.setBattleButtonsEnabled(false);
    this.setBattleMessage(
      enemyStats.isBoss
        ? `${enemyStats.name} blocks the way.`
        : `A wild ${enemyStats.name} wobbles closer.`
    );
    await wait(800);
    this.setBattleMessage("Pick a move.");
    this.setBattleButtonsEnabled(true);
  }

  renderBattle() {
    const { enemyStats } = this.battle;
    this.overlayEl.className = "overlay";
    this.overlayEl.style.setProperty("--battle-bg", `url("${ASSETS.beachScene}")`);
    this.overlayEl.innerHTML = `
      <div class="dialog battle-dialog">
        <div class="battle-stage">
          <div class="fighter">
            <div class="fighter-card enemy">
              <div class="large" data-battle-ref="enemyName"></div>
              <div class="stat-row">
                <span class="label">HP</span>
                <div class="bar" style="--bar-color:#e45757"><span data-battle-ref="enemyHpBar"></span></div>
                <span class="small" data-battle-ref="enemyHpText"></span>
              </div>
            </div>
            <img class="fighter-sprite" data-battle-ref="enemySprite" src="${ASSETS.enemySlime}" alt="${escapeHtml(enemyStats.name)}" />
          </div>
          <div class="fighter">
            <div class="fighter-card player">
              <div class="large" data-battle-ref="playerName"></div>
              <div class="stat-row">
                <span class="label">HP</span>
                <div class="bar" style="--bar-color:#54d878"><span data-battle-ref="playerHpBar"></span></div>
                <span class="small" data-battle-ref="playerHpText"></span>
              </div>
            </div>
            <img class="fighter-sprite" data-battle-ref="playerSprite" src="${ASSETS.goopzz}" alt="Goopzz" />
          </div>
        </div>
        <div class="battle-bottom">
          <div class="message-box" data-battle-ref="message"></div>
          <div class="move-grid" data-battle-ref="moves"></div>
        </div>
      </div>
    `;
    this.battleRefs = {};
    this.overlayEl.querySelectorAll("[data-battle-ref]").forEach((node) => {
      this.battleRefs[node.dataset.battleRef] = node;
    });
    this.renderBattleMoves();
    this.updateBattleUi();
  }

  renderBattleMoves() {
    this.battleRefs.moves.innerHTML = this.run.loadout
      .map((moveId, index) => {
        const move = getMove(moveId);
        return `
          <button class="move-button" data-move-index="${index}" data-move-id="${moveId}" style="--move-color:${TYPE_COLORS[move.type] || "#567"}">
            <strong>${index + 1}. ${escapeHtml(move.name)}</strong>
            <span data-move-detail="${index}"></span>
          </button>
        `;
      })
      .join("");
    this.battleRefs.moves.querySelectorAll("[data-move-id]").forEach((button) => {
      button.addEventListener("click", () => this.onMovePressed(button.dataset.moveId));
    });
    this.updateMoveButtonDetails();
  }

  updateBattleUi() {
    const { enemyStats, playerAttackBonus, enemyAttackBonus } = this.battle;
    this.battleRefs.playerName.textContent = `Goopzz  Lv ${this.run.playerLevel}  ATK ${this.run.playerAttack + playerAttackBonus}`;
    this.battleRefs.enemyName.textContent = `${enemyStats.name}  Lv ${enemyStats.level}  ATK ${Math.max(0, enemyStats.attack + enemyAttackBonus)}`;
    this.battleRefs.playerHpBar.style.width = `${(this.run.playerHp / this.run.playerMaxHp) * 100}%`;
    this.battleRefs.playerHpText.textContent = `${this.run.playerHp} / ${this.run.playerMaxHp}`;
    this.battleRefs.enemyHpBar.style.width = `${(enemyStats.hp / enemyStats.maxHp) * 100}%`;
    this.battleRefs.enemyHpText.textContent = `${enemyStats.hp} / ${enemyStats.maxHp}`;
    this.updateMoveButtonDetails();
  }

  updateMoveButtonDetails() {
    if (!this.battleRefs?.moves) return;
    this.run.loadout.forEach((moveId, index) => {
      const move = getMove(moveId);
      const detail = this.moveDetail(move);
      const node = this.battleRefs.moves.querySelector(`[data-move-detail="${index}"]`);
      if (node) node.textContent = detail;
    });
  }

  moveDetail(move) {
    let detail = move.type;
    switch (move.effect) {
      case "damage": {
        const [low, high] = this.damageRange(move);
        detail += ` - ${low}-${high} dmg`;
        break;
      }
      case "multi_hit": {
        const [low, high] = this.damageRange(move);
        detail += ` - ${low}-${high} dmg x${move.hits || 2}`;
        break;
      }
      case "damage_recoil": {
        const [low, high] = this.damageRange(move);
        detail += ` - ${low}-${high} dmg, ${move.recoil || 0} recoil`;
        break;
      }
      case "heal":
        detail += ` - heal ${move.power} HP`;
        break;
      case "shield":
        detail += " - halve next hit";
        break;
      case "buff_attack":
        detail += ` - attack +${move.power}`;
        break;
      case "debuff_attack":
        detail += ` - enemy attack -${move.power}`;
        break;
      default:
        break;
    }
    return detail;
  }

  damageRange(move) {
    let base = (move.power || 0) + this.run.playerAttack + (this.battle?.playerAttackBonus || 0);
    base *= TYPE_MULTIPLIER[move.type] || 1;
    return [
      Math.max(1, Math.round(base * DAMAGE_WIGGLE_LOW)),
      Math.max(1, Math.round(base * DAMAGE_WIGGLE_HIGH))
    ];
  }

  calcDamage(move, attackerAttack, defenderShielded) {
    let amount = (move.power || 0) + attackerAttack;
    amount *= TYPE_MULTIPLIER[move.type] || 1;
    amount *= DAMAGE_WIGGLE_LOW + Math.random() * (DAMAGE_WIGGLE_HIGH - DAMAGE_WIGGLE_LOW);
    if (defenderShielded) amount *= 0.5;
    return Math.max(1, Math.round(amount));
  }

  setBattleMessage(text) {
    this.battleRefs.message.textContent = text;
  }

  setBattleButtonsEnabled(enabled) {
    this.battle.busy = !enabled;
    this.battleRefs.moves.querySelectorAll("button").forEach((button) => {
      button.disabled = !enabled;
    });
    if (enabled) this.updateMoveButtonDetails();
  }

  async onMovePressed(moveId) {
    if (!this.battle || this.battle.busy) return;
    this.setBattleButtonsEnabled(false);
    await this.doPlayerMove(moveId);
    if (this.battle.enemyStats.hp <= 0) {
      await this.winBattle();
      return;
    }
    await this.doEnemyMove();
    if (this.run.playerHp <= 0) {
      await this.loseBattle();
      return;
    }
    this.setBattleMessage("Pick a move.");
    this.setBattleButtonsEnabled(true);
  }

  async doPlayerMove(moveId) {
    const move = getMove(moveId);
    this.setBattleMessage(`Goopzz used ${move.name}.`);
    this.battleRefs.playerSprite.src = ASSETS.goopzzAngry;
    await wait(move.type === "sword" ? 420 : 300);

    switch (move.effect) {
      case "damage":
        await this.hitEnemy(move);
        break;
      case "multi_hit": {
        const hits = move.hits || 2;
        for (let i = 0; i < hits; i += 1) {
          await this.hitEnemy(move);
          await wait(220);
          if (this.battle.enemyStats.hp <= 0) break;
        }
        break;
      }
      case "damage_recoil": {
        await this.hitEnemy(move);
        const recoil = move.recoil || 0;
        this.run.playerHp = Math.max(0, this.run.playerHp - recoil);
        this.setBattleMessage(`Whoa, dizzy. Goopzz took ${recoil} recoil damage.`);
        this.updateBattleUi();
        await wait(500);
        break;
      }
      case "heal": {
        const healed = Math.min(move.power || 0, this.run.playerMaxHp - this.run.playerHp);
        this.run.playerHp += healed;
        this.setBattleMessage(`Goopzz recovered ${healed} HP.`);
        this.updateBattleUi();
        await wait(540);
        break;
      }
      case "shield":
        this.battle.playerShielded = true;
        this.setBattleMessage("Goopzz puffed up. The next hit will do half damage.");
        await wait(540);
        break;
      case "buff_attack":
        this.battle.playerAttackBonus += move.power || 0;
        this.setBattleMessage(`BLORP! Goopzz's attack rose by ${move.power || 0}.`);
        this.updateBattleUi();
        await wait(540);
        break;
      case "debuff_attack":
        this.battle.enemyAttackBonus -= move.power || 0;
        this.setBattleMessage(`${this.battle.enemyStats.name}'s attack fell by ${move.power || 0}.`);
        this.updateBattleUi();
        await wait(540);
        break;
      default:
        break;
    }

    this.battleRefs.playerSprite.src = ASSETS.goopzz;
    this.updateBattleUi();
  }

  async hitEnemy(move) {
    const damage = this.calcDamage(move, this.run.playerAttack + this.battle.playerAttackBonus, false);
    this.battle.enemyStats.hp = Math.max(0, this.battle.enemyStats.hp - damage);
    const quip = move.type === "sword" ? " Slimes hate swords." : move.type === "water" ? " Sploosh." : "";
    this.setBattleMessage(`It hit ${this.battle.enemyStats.name} for ${damage} damage.${quip}`);
    this.updateBattleUi();
    this.battleRefs.enemySprite.classList.add("hit");
    await wait(360);
    this.battleRefs.enemySprite.classList.remove("hit");
  }

  async doEnemyMove() {
    await wait(300);
    const { enemyStats } = this.battle;
    const moveId = enemyStats.moves[Math.floor(Math.random() * enemyStats.moves.length)];
    const move = getMove(moveId);
    this.setBattleMessage(`${enemyStats.name} used ${move.name}.`);
    this.battleRefs.enemySprite.src = ASSETS.enemySlimeAttacking;
    await wait(460);

    if (move.effect === "buff_attack") {
      this.battle.enemyAttackBonus += move.power || 0;
      this.setBattleMessage(`${enemyStats.name} is getting angrier. Its attack rose.`);
      this.updateBattleUi();
      await wait(520);
    } else {
      const attack = Math.max(0, enemyStats.attack + this.battle.enemyAttackBonus);
      const damage = this.calcDamage(move, attack, this.battle.playerShielded);
      if (this.battle.playerShielded) {
        this.battle.playerShielded = false;
        this.setBattleMessage(`Goo Shield softened the blow. Only ${damage} damage.`);
      } else {
        this.setBattleMessage(`Ouch. Goopzz took ${damage} damage.`);
      }
      this.run.playerHp = Math.max(0, this.run.playerHp - damage);
      this.battleRefs.playerSprite.classList.add("hit");
      this.updateBattleUi();
      await wait(420);
      this.battleRefs.playerSprite.classList.remove("hit");
    }

    this.battleRefs.enemySprite.src = ASSETS.enemySlime;
    this.updateBattleUi();
  }

  async winBattle() {
    const { enemyStats, enemyRef } = this.battle;
    this.setBattleMessage(`${enemyStats.name} dissolved into puddle goo. Victory!`);
    await wait(700);
    const levelsGained = this.run.addXp(enemyStats.xp || 10);
    this.run.battlesWon += 1;
    this.setBattleMessage(`Goopzz gained ${enemyStats.xp || 10} XP.`);
    this.updateBattleUi();
    await wait(700);
    if (levelsGained > 0) {
      this.setBattleMessage(`LEVEL UP! Goopzz is now Lv ${this.run.playerLevel}.`);
      this.updateBattleUi();
      await wait(800);
    }

    const choices = randomRewardChoices(3, this.run.loadout);
    if (choices.length > 0) {
      await this.showMoveLearn(choices, "Victory! Pick a new move:");
    }

    this.removeEnemy(enemyRef);
    this.overlayEl.className = "overlay hidden";
    this.overlayEl.innerHTML = "";
    this.battle = null;
    this.state = "overworld";
    this.battleCooldown = 1.5;
    if (this.enemies.filter((enemy) => !enemy.removed).length <= 0) {
      this.openExit();
    } else {
      this.showToast(`${this.enemies.filter((enemy) => !enemy.removed).length} slime(s) left`);
    }
  }

  async loseBattle() {
    this.setBattleMessage("Goopzz was splattered. The run is over.");
    await wait(900);
    this.endRun(false);
  }

  removeEnemy(enemy) {
    enemy.removed = true;
    this.scene.remove(enemy.group);
  }

  showMoveLearn(choices, title) {
    return new Promise((resolve) => {
      const renderChoices = () => {
        this.overlayEl.className = "overlay";
        this.overlayEl.innerHTML = `
          <div class="dialog">
            <div class="dialog-inner">
              <h2>${escapeHtml(title)}</h2>
              <p>Choose one. Goopzz can carry four moves.</p>
              <div class="choice-grid">
                ${choices
                  .map((moveId) => {
                    const move = getMove(moveId);
                    return `
                      <button class="choice-button" data-choice="${moveId}" style="--move-color:${TYPE_COLORS[move.type] || "#567"}">
                        <strong>${escapeHtml(move.name)}</strong>
                        <span>${escapeHtml(this.moveDetailForLearn(move))}</span>
                        <span>${escapeHtml(move.description || "")}</span>
                      </button>
                    `;
                  })
                  .join("")}
              </div>
              <div class="button-row">
                <button class="command secondary" data-skip>Keep current moves</button>
              </div>
            </div>
          </div>
        `;
        this.overlayEl.querySelectorAll("[data-choice]").forEach((button) => {
          button.addEventListener("click", () => {
            const moveId = button.dataset.choice;
            if (this.run.loadout.length < MAX_LOADOUT_SIZE) {
              this.run.loadout.push(moveId);
              resolve(moveId);
              return;
            }
            renderReplace(moveId);
          });
        });
        this.overlayEl.querySelector("[data-skip]").addEventListener("click", () => resolve(null));
      };

      const renderReplace = (newMoveId) => {
        const newMove = getMove(newMoveId);
        this.overlayEl.innerHTML = `
          <div class="dialog">
            <div class="dialog-inner">
              <h2>Learn ${escapeHtml(newMove.name)}</h2>
              <p>Pick a move to forget.</p>
              <div class="choice-grid">
                ${this.run.loadout
                  .map((moveId, index) => {
                    const move = getMove(moveId);
                    return `
                      <button class="choice-button" data-replace="${index}" style="--move-color:${TYPE_COLORS[move.type] || "#567"}">
                        <strong>${index + 1}. ${escapeHtml(move.name)}</strong>
                        <span>${escapeHtml(this.moveDetailForLearn(move))}</span>
                      </button>
                    `;
                  })
                  .join("")}
              </div>
              <div class="button-row">
                <button class="command secondary" data-back>Back</button>
                <button class="command secondary" data-skip>Skip</button>
              </div>
            </div>
          </div>
        `;
        this.overlayEl.querySelectorAll("[data-replace]").forEach((button) => {
          button.addEventListener("click", () => {
            this.run.loadout[Number(button.dataset.replace)] = newMoveId;
            resolve(newMoveId);
          });
        });
        this.overlayEl.querySelector("[data-back]").addEventListener("click", renderChoices);
        this.overlayEl.querySelector("[data-skip]").addEventListener("click", () => resolve(null));
      };

      renderChoices();
    });
  }

  moveDetailForLearn(move) {
    switch (move.effect) {
      case "damage":
        return `${move.type} - ${move.power} power`;
      case "multi_hit":
        return `${move.type} - ${move.power} power x${move.hits || 2}`;
      case "damage_recoil":
        return `${move.type} - ${move.power} power, ${move.recoil || 0} recoil`;
      case "heal":
        return `${move.type} - heal ${move.power} HP`;
      case "shield":
        return `${move.type} - halves the next hit`;
      case "buff_attack":
        return `${move.type} - attack +${move.power}`;
      case "debuff_attack":
        return `${move.type} - enemy attack -${move.power}`;
      default:
        return move.type;
    }
  }

  endRun(won) {
    this.state = "gameOver";
    this.hudEl.classList.add("hidden");
    this.overlayEl.className = "overlay";
    const title = won ? "Slimania Saved" : "Run Over";
    const body = won
      ? `Goopzz cleared all ${this.run.totalRooms()} rooms and sent the invaders packing.`
      : `Goopzz reached room ${this.run.currentRoom}/${this.run.totalRooms()} and won ${this.run.battlesWon} battle(s).`;
    this.overlayEl.innerHTML = `
      <div class="dialog">
        <div class="dialog-inner">
          <h1>${title}</h1>
          <p>${escapeHtml(body)}</p>
          <p>Level ${this.run.playerLevel}. Attack ${this.run.playerAttack}. Moves: ${this.run.loadout.map((id) => getMove(id).name).join(", ")}.</p>
          <div class="button-row">
            <button class="command" data-action="restart">Start a new run</button>
          </div>
        </div>
      </div>
    `;
    this.overlayEl.querySelector("[data-action='restart']").addEventListener("click", () => this.startRun());
  }

  makeTexturedPlane(texture, width, height) {
    const material = new THREE.MeshBasicMaterial({ map: texture });
    return new THREE.Mesh(new THREE.PlaneGeometry(width, height), material);
  }

  makeRectMesh(rect, color, opacity = 1, z = 0) {
    const material = new THREE.MeshBasicMaterial({
      color,
      transparent: opacity < 1,
      opacity,
      depthWrite: opacity >= 1
    });
    const mesh = new THREE.Mesh(new THREE.PlaneGeometry(rect.width, rect.height), material);
    const center = rectCenter(rect);
    setWorldPosition(mesh, center, z);
    return mesh;
  }

  makeShadow(width, height, opacity) {
    const shadow = new THREE.Mesh(
      new THREE.CircleGeometry(1, 32),
      new THREE.MeshBasicMaterial({
        color: 0x000000,
        transparent: true,
        opacity,
        depthWrite: false
      })
    );
    shadow.scale.set(width, height, 1);
    shadow.position.z = 12;
    return shadow;
  }

  makeSprite(textureKey, height) {
    const texture = this.textures[textureKey];
    const material = new THREE.SpriteMaterial({
      map: texture,
      transparent: true,
      depthWrite: false
    });
    const sprite = new THREE.Sprite(material);
    const aspect = this.spriteAspect(textureKey);
    sprite.scale.set(height * aspect, height, 1);
    return sprite;
  }

  spriteAspect(textureKey) {
    const texture = this.textures[textureKey];
    if (!texture?.image?.height) return 1;
    return texture.image.width / texture.image.height;
  }

  makeTextSprite(text, options = {}) {
    const width = options.width || 320;
    const height = options.height || 96;
    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;
    const context = canvas.getContext("2d");
    context.clearRect(0, 0, width, height);
    context.font = `800 ${options.fontSize || 32}px Inter, system-ui, sans-serif`;
    context.textAlign = "center";
    context.textBaseline = "middle";
    context.lineJoin = "round";
    context.strokeStyle = "rgba(0, 0, 0, 0.68)";
    context.lineWidth = 8;
    context.fillStyle = options.color || "#fff6db";
    const lines = String(text).split("\n");
    const lineHeight = (options.fontSize || 32) * 1.1;
    const startY = height / 2 - ((lines.length - 1) * lineHeight) / 2;
    lines.forEach((line, index) => {
      const y = startY + index * lineHeight;
      context.strokeText(line, width / 2, y);
      context.fillText(line, width / 2, y);
    });
    const texture = new THREE.CanvasTexture(canvas);
    texture.colorSpace = THREE.SRGBColorSpace;
    const material = new THREE.SpriteMaterial({
      map: texture,
      transparent: true,
      depthWrite: false
    });
    const sprite = new THREE.Sprite(material);
    sprite.scale.set(width / 2, height / 2, 1);
    return sprite;
  }
}

const game = new SlimaniaGame();
game.start().catch((error) => {
  console.error(error);
  document.querySelector("#overlay").innerHTML = `
    <div class="dialog">
      <div class="dialog-inner">
        <h1>Could not start Slimania</h1>
        <p>${escapeHtml(error.message || error)}</p>
      </div>
    </div>
  `;
});
