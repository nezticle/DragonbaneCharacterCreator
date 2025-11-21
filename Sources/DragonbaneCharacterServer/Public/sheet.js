const KIN_OPTIONS = [
  "Human",
  "Halfling",
  "Dwarf",
  "Elf",
  "Mallard",
  "Wolfkin",
  "Goblin",
  "Hobgoblin",
  "Ogre",
  "Orc",
  "Cat People",
  "Frog People",
  "Karkion",
  "Lizard People",
  "Satyr"
];

const PROFESSION_OPTIONS = [
  "Artisan",
  "Bard",
  "Fighter",
  "Hunter",
  "Knight",
  "Mage (Animist)",
  "Mage (Elementalist)",
  "Mage (Mentalist)",
  "Mariner",
  "Merchant",
  "Scholar",
  "Thief"
];

const AGE_OPTIONS = ["Young", "Adult", "Old"];
const SECONDARY_SKILL_OPTIONS = ["Animism", "Elementalism", "Mentalism"];
const GRIP_OPTIONS = ["", "R", "L", "RL"];
const THEME_STORAGE_KEY = "dragonbaneTheme";

const HEROIC_ABILITIES = [
  "Adaptive",
  "Assassin",
  "Backstabbing",
  "Battle Cry",
  "Berserk",
  "Body Slam",
  "Camouflage",
  "Catlike",
  "Companion",
  "Contortionist",
  "Defensive",
  "Deflect Arrow",
  "Disguise",
  "Double Slash",
  "Dragonslayer",
  "Dual Wield",
  "Eagle Eye",
  "Fast Footwork",
  "Fast Healer",
  "Fearless",
  "Focused",
  "Guardian",
  "Hard to Catch",
  "Hunting Instinct",
  "Ill-Tempered",
  "Inner Peace",
  "Insight",
  "Intuition",
  "Iron Fist",
  "Iron Grip",
  "Leaping",
  "Lightning Fast",
  "Lone Wolf",
  "Magic Talent",
  "Massive Blow",
  "Master Blacksmith",
  "Master Carpenter",
  "Master Chef",
  "Master Spellcaster",
  "Master Tanner",
  "Monster Hunter",
  "Musician",
  "Nine Lives",
  "Pathfinder",
  "Quartermaster",
  "Raise Spirits",
  "Resilient",
  "Robust",
  "Sea Legs",
  "Shield Block",
  "Throwing Arm",
  "Tough",
  "Treasure Hunter",
  "Twin Shot",
  "Unforgiving",
  "Veteran",
  "Webbed Feet",
  "Weasel",
  "Wings"
];

const SPELL_LIBRARY = [
  "Animate Bones",
  "Blinding Light",
  "Breath of Life",
  "Call Lightning",
  "Chain Lightning",
  "Earth Spike",
  "Fireball",
  "Gale Burst",
  "Healing Hands",
  "Illusion Veil",
  "Mind Blast",
  "Shadow Cloak",
  "Stone Skin",
  "Summon Beast",
  "Telekinesis",
  "Water Walk"
];

const ABILITY_LIBRARY = [...HEROIC_ABILITIES].sort();
const SKILL_ATTRIBUTE_MAP = {
  Acrobatics: "AGL",
  Awareness: "INT",
  Bartering: "CHA",
  "Beast Lore": "INT",
  Bluffing: "CHA",
  Bushcraft: "INT",
  Crafting: "STR",
  Evade: "AGL",
  Healing: "INT",
  "Hunting & Fishing": "AGL",
  Language: "INT",
  "Myths & Legends": "INT",
  Performance: "CHA",
  Persuasion: "CHA",
  Riding: "AGL",
  Seamanship: "INT",
  "Slight of Hand": "AGL",
  Sneaking: "AGL",
  "Spot Hidden": "INT",
  Swimming: "AGL",
  Axes: "STR",
  Bows: "AGL",
  Brawling: "STR",
  Crossbows: "AGL",
  Hammers: "STR",
  Knives: "AGL",
  Slings: "AGL",
  Spears: "STR",
  Staves: "AGL",
  Swords: "STR"
};

function resolveThemePreference() {
  if (typeof localStorage !== "undefined") {
    const stored = localStorage.getItem(THEME_STORAGE_KEY);
    if (stored === "dark" || stored === "light") {
      return stored;
    }
  }
  const mediaQuery = typeof window !== "undefined" && window.matchMedia
    ? window.matchMedia("(prefers-color-scheme: dark)")
    : null;
  return mediaQuery?.matches ? "dark" : "light";
}

function applyTheme(theme) {
  const resolved = theme === "dark" ? "dark" : "light";
  const root = document.documentElement;
  root.dataset.theme = resolved;
  root.classList.toggle("theme-dark", resolved === "dark");
  root.classList.toggle("theme-light", resolved === "light");
  const toggle = document.getElementById("themeToggle");
  if (toggle) {
    toggle.textContent = resolved === "dark" ? "Light mode" : "Dark mode";
    toggle.setAttribute("aria-pressed", resolved === "dark" ? "true" : "false");
  }
}

function setupThemeToggle() {
  if (typeof document === "undefined") return;
  applyTheme(resolveThemePreference());
  const toggle = document.getElementById("themeToggle");
  if (!toggle) return;
  toggle.addEventListener("click", () => {
    const nextTheme = document.documentElement.dataset.theme === "dark" ? "light" : "dark";
    if (typeof localStorage !== "undefined") {
      localStorage.setItem(THEME_STORAGE_KEY, nextTheme);
    }
    applyTheme(nextTheme);
  });
}

const state = {
  sheetId: "",
  data: null,
  dirty: false,
  saving: false,
  pendingSave: false,
  saveTimer: null,
  bindings: new Map(),
  statusElement: null,
  skillSectionsReady: false,
  lockedSections: new Set(),
  magicEditing: false
};

document.addEventListener("DOMContentLoaded", initializeSheet);
window.addEventListener("beforeunload", (event) => {
  if (state.dirty || state.saving) {
    event.preventDefault();
    event.returnValue = "";
  }
});

function ensureDataShape() {
  if (!state.data) return;
  state.data.attributes = state.data.attributes || {
    strength: 0,
    constitution: 0,
    agility: 0,
    intelligence: 0,
    willpower: 0,
    charisma: 0
  };
  state.data.abilitiesAndSpells = Array.isArray(state.data.abilitiesAndSpells)
    ? state.data.abilitiesAndSpells.map((value) => (typeof value === "string" ? value.trim() : "")).filter(Boolean)
    : [];
  const migratedSpells = [];
  state.data.abilitiesAndSpells = state.data.abilitiesAndSpells.filter((value) => {
    if (!value) return false;
    if (SPELL_LIBRARY.includes(value)) {
      migratedSpells.push(value);
      return false;
    }
    return true;
  });
  state.data.spells = Array.isArray(state.data.spells)
    ? normalizeSpells(state.data.spells)
    : migratedSpells.map((name) => ({ name, inGrimoire: true, prepared: false }));
  state.data.inventory = Array.isArray(state.data.inventory)
    ? state.data.inventory.map((item) => ({
        name: item?.name ?? "",
        details: item?.details ?? "",
        slots: Math.max(Number(item?.slots) || 0, 0)
      }))
    : [];
  state.data.skills = state.data.skills || { primary: [], weapon: [], secondary: [] };
  state.data.skills.primary = state.data.skills.primary || [];
  state.data.skills.weapon = state.data.skills.weapon || [];
  state.data.skills.secondary = state.data.skills.secondary || [];
  state.data.weapons = Array.isArray(state.data.weapons) ? state.data.weapons : [];
  while (state.data.weapons.length < 3) {
    state.data.weapons.push(emptyWeapon());
  }
  state.data.rests = state.data.rests || { roundRest: false, stretchRest: false };
  state.data.deathRolls = state.data.deathRolls || { successes: [false, false, false], failures: [false, false, false] };
  state.data.deathRolls.successes = normalizeToggleArray(state.data.deathRolls.successes);
  state.data.deathRolls.failures = normalizeToggleArray(state.data.deathRolls.failures);
  state.data.armour = state.data.armour || { armourType: "", rating: 0, banes: { sneaking: false, evade: false, acrobatics: false } };
  state.data.armour.banes = state.data.armour.banes || { sneaking: false, evade: false, acrobatics: false };
  state.data.helmet = state.data.helmet || { helmetType: "", rating: 0, banes: { awareness: false, rangedAttacks: false } };
  state.data.helmet.banes = state.data.helmet.banes || { awareness: false, rangedAttacks: false };
  state.data.willpower = state.data.willpower || { max: 0, current: 0 };
  state.data.hitPoints = state.data.hitPoints || { max: 0, current: 0 };
  if (typeof state.data.movement !== "number") {
    const agility = state.data.attributes?.agility ?? 0;
    state.data.movement = calculateMovement(state.data.kin ?? "", agility);
  }
  const strength = state.data.attributes?.strength ?? 0;
  const baseEncumbrance = calculateEncumbranceBaseLimit(strength);
  state.data.encumbranceLimit = sanitizeEncumbranceLimit(state.data.encumbranceLimit, baseEncumbrance);
}

function normalizeToggleArray(source) {
  const toggles = Array.isArray(source) ? source.slice(0, 3) : [];
  while (toggles.length < 3) {
    toggles.push(false);
  }
  return toggles;
}

function emptyWeapon() {
  return { name: "", grip: "", range: "", damage: "", durability: 0, features: "" };
}

async function initializeSheet() {
  setupThemeToggle();
  state.sheetId = extractSheetId();
  const app = document.getElementById("sheetApp");
  if (state.sheetId) {
    app.dataset.sheetId = state.sheetId;
  }
  state.statusElement = document.getElementById("saveStatus");

  populateSelect("kinField", KIN_OPTIONS);
  populateSelect("professionField", PROFESSION_OPTIONS);
  populateSelect("ageField", AGE_OPTIONS);
  populateSecondarySelect();
  populateAbilityOptions();
  populateSpellOptions();
  setupToolbar();
  setupSectionLocks();
  setupMagicEditing();

  if (!state.sheetId) {
    showError("Missing character sheet identifier in the URL.");
    return;
  }

  setShareLink();
  await loadSheet();
}

function extractSheetId() {
  const segments = window.location.pathname.split("/").filter(Boolean);
  if (segments.length >= 2 && segments[0] === "sheet") {
    return segments[1];
  }
  const url = new URL(window.location.href);
  return url.searchParams.get("id")?.trim() ?? "";
}

function populateSelect(id, options) {
  const select = document.getElementById(id);
  if (!select || !Array.isArray(options)) return;
  const current = select.value;
  select.innerHTML = '<option value="">Select</option>';
  options.forEach((value) => {
    const option = document.createElement("option");
    option.value = value;
    option.textContent = value;
    select.appendChild(option);
  });
  if (current) {
    select.value = current;
  }
}

function populateSecondarySelect() {
  const select = document.getElementById("secondarySkillSelect");
  if (!select) return;
  select.innerHTML = '<option value="">Add school</option>';
  SECONDARY_SKILL_OPTIONS.forEach((value) => {
    const option = document.createElement("option");
    option.value = value;
    option.textContent = value;
    if (state.data?.skills?.secondary?.some((entry) => entry.name === value)) {
      option.disabled = true;
    }
    select.appendChild(option);
  });
}

function populateAbilityOptions() {
  const datalist = document.getElementById("abilitiesOptions");
  if (!datalist) return;
  datalist.innerHTML = "";
  ABILITY_LIBRARY.forEach((value) => {
    const option = document.createElement("option");
    option.value = value;
    datalist.appendChild(option);
  });
}

function populateSpellOptions() {
  const datalist = document.getElementById("spellsOptions");
  if (!datalist) return;
  datalist.innerHTML = "";
  SPELL_LIBRARY.forEach((value) => {
    const option = document.createElement("option");
    option.value = value;
    datalist.appendChild(option);
  });
}

function setupToolbar() {
  document.getElementById("copyLinkButton")?.addEventListener("click", copyShareLink);
  document.getElementById("saveButton")?.addEventListener("click", () => saveSheet(true));
}

function setupSectionLocks() {
  const buttons = document.querySelectorAll(".lock-button[data-lock]");
  buttons.forEach((button) => {
    const sectionId = button.dataset.lock;
    if (!sectionId) return;
    button.type = "button";
    button.addEventListener("click", () => toggleSectionLock(sectionId));
    applySectionLock(sectionId, state.lockedSections.has(sectionId), false);
  });
}

function setupMagicEditing() {
  const toggle = document.getElementById("toggleMagicEdit");
  if (!toggle) return;
  toggle.addEventListener("click", () => {
    if (state.lockedSections.has("magic")) return;
    state.magicEditing = !state.magicEditing;
    updateMagicEditUI();
    renderSpellList();
  });
  updateMagicEditUI();
}

function updateMagicEditUI() {
  const toggle = document.getElementById("toggleMagicEdit");
  if (!toggle) return;
  const locked = state.lockedSections.has("magic");
  const editing = isMagicEditable();
  toggle.textContent = editing ? "Done" : "Edit";
  toggle.classList.toggle("locked", editing);
  toggle.setAttribute("aria-pressed", editing ? "true" : "false");
  toggle.disabled = locked;
}

function isMagicEditable() {
  if (state.lockedSections.has("magic")) return false;
  return Boolean(state.magicEditing);
}

function toggleSectionLock(sectionId) {
  if (!sectionId) return;
  const shouldLock = !state.lockedSections.has(sectionId);
  applySectionLock(sectionId, shouldLock);
}

function applySectionLock(sectionId, locked, persist = true) {
  const section = document.querySelector(`[data-section="${sectionId}"]`);
  if (!section) return;
  if (persist) {
    if (locked) {
      state.lockedSections.add(sectionId);
    } else {
      state.lockedSections.delete(sectionId);
    }
  }
  section.classList.toggle("locked", locked);
  const controls = section.querySelectorAll("input, textarea, select, button");
  controls.forEach((control) => {
    if (control.closest(".section-title")) return;
    if (control.dataset.lockExempt === "true") return;
    const tag = control.tagName.toLowerCase();
    const type = (control.type || "").toLowerCase();
    const isTextualInput =
      tag === "textarea" ||
      (tag === "input" && !["checkbox", "radio", "button", "submit", "reset", "file", "color"].includes(type));
    if (isTextualInput) {
      control.readOnly = locked;
      control.classList.toggle("field-locked", locked);
    } else {
      control.disabled = locked;
    }
  });
  const button = document.querySelector(`.lock-button[data-lock="${sectionId}"]`);
  if (button) {
    button.textContent = locked ? "Unlock" : "Lock";
    button.classList.toggle("locked", locked);
    button.setAttribute("aria-pressed", locked ? "true" : "false");
  }
  if (sectionId === "magic") {
    if (locked) {
      state.magicEditing = false;
    }
    updateMagicEditUI();
    renderSpellList();
  }
}

function setShareLink() {
  const field = document.getElementById("shareLink");
  if (!field || !state.sheetId) return;
  const url = `${window.location.origin}/sheet/${state.sheetId}`;
  field.value = url;
}

async function copyShareLink() {
  const field = document.getElementById("shareLink");
  if (!field) return;
  try {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(field.value);
    } else {
      throw new Error("Clipboard unavailable");
    }
    indicateCopied(field);
  } catch {
    field.select();
    field.setSelectionRange(0, field.value.length);
    const success = typeof document.execCommand === "function" && document.execCommand("copy");
    if (success) {
      indicateCopied(field);
    }
  }
}

function indicateCopied(field) {
  field.classList.add("success");
  setTimeout(() => field.classList.remove("success"), 1200);
}

async function loadSheet() {
  toggleLoading(true);
  try {
    const response = await fetch(`/api/sheets/${state.sheetId}`);
    if (!response.ok) {
      const message = await response.text();
      throw new Error(message || "Unable to load sheet.");
    }
    const payload = await response.json();
    state.data = payload.data;
    ensureDataShape();
    toggleLoading(false);
    initializeBindings();
    renderDynamicSections(true);
    updateDerivedFields();
    updateSaveStatus("All changes saved.");
  } catch (error) {
    showError(error.message);
  }
}

function toggleLoading(isLoading) {
  const loading = document.getElementById("sheetLoading");
  const form = document.getElementById("sheetForm");
  if (isLoading) {
    if (loading) {
      loading.classList.remove("hidden");
      loading.style.display = "flex";
    }
    form?.classList.add("hidden");
  } else {
    if (loading) {
      loading.classList.add("hidden");
      loading.style.display = "none";
    }
    form?.classList.remove("hidden");
  }
}

function showError(message) {
  const box = document.getElementById("sheetError");
  if (box) {
    box.textContent = message;
    box.classList.remove("hidden");
  }
  toggleLoading(false);
  document.getElementById("sheetForm")?.classList.add("hidden");
}

function initializeBindings() {
  state.bindings.clear();
  const fields = document.querySelectorAll("[data-bind]");
  fields.forEach((element) => {
    const path = element.dataset.bind;
    const type = element.dataset.type || inferType(element);
    const entry = { element, path, type };
    if (!state.bindings.has(path)) {
      state.bindings.set(path, []);
    }
    state.bindings.get(path).push(entry);
    setElementValue(entry, getValueByPath(state.data, path));
    const eventName = element.type === "checkbox" ? "change" : "input";
    element.addEventListener(eventName, () => {
      const value = readElementValue(entry);
      setValueByPath(state.data, path, value);
      handleDerivedUpdates(path);
      markDirty();
    });
  });
}

function refreshBindings() {
  state.bindings.forEach((entries, path) => {
    entries.forEach((entry) => {
      setElementValue(entry, getValueByPath(state.data, path));
    });
  });
}

function inferType(element) {
  if (element.type === "number") return "number";
  if (element.type === "checkbox") return "boolean";
  return "string";
}

function setElementValue(binding, rawValue) {
  const { element, type } = binding;
  if (!element) return;
  if (type === "boolean") {
    element.checked = Boolean(rawValue);
  } else if (type === "number") {
    element.value = Number.isFinite(rawValue) ? Number(rawValue) : "";
  } else {
    element.value = rawValue ?? "";
  }
}

function readElementValue(binding) {
  const { element, type } = binding;
  if (type === "boolean") {
    return element.checked;
  }
  if (type === "number") {
    const value = parseInt(element.value, 10);
    return Number.isFinite(value) ? value : 0;
  }
  return element.value;
}

function getValueByPath(source, path) {
  return path.split(".").reduce((acc, key) => (acc && typeof acc === "object" ? acc[key] : undefined), source);
}

function setValueByPath(target, path, value) {
  const parts = path.split(".");
  let current = target;
  for (let i = 0; i < parts.length - 1; i += 1) {
    const key = parts[i];
    if (!current[key] || typeof current[key] !== "object") {
      current[key] = {};
    }
    current = current[key];
  }
  current[parts[parts.length - 1]] = value;
}

function handleDerivedUpdates(path) {
  if (path.startsWith("attributes.") || path === "kin") {
    updateDerivedFields();
  }
  if (path.startsWith("inventory")) {
    updateEncumbranceDisplay();
  }
  if (path === "encumbranceLimit") {
    updateEncumbranceDisplay();
  }
}

function updateDerivedFields() {
  const strength = state.data?.attributes?.strength ?? 0;
  const agility = state.data?.attributes?.agility ?? 0;
  const kin = state.data?.kin ?? "";
  document.getElementById("damageBonusStr").value = calculateDamageBonus(strength);
  document.getElementById("damageBonusAgl").value = calculateDamageBonus(agility);
  const movement = calculateMovement(kin, agility);
  if (state.data) {
    state.data.movement = movement;
    refreshBindingsForPath("movement");
  }
  updateEncumbranceDisplay();
}

function refreshBindingsForPath(path) {
  const entries = state.bindings.get(path);
  if (!entries) return;
  entries.forEach((entry) => setElementValue(entry, getValueByPath(state.data, path)));
}

function calculateDamageBonus(attribute) {
  if (attribute >= 17) return "+D6";
  if (attribute >= 13) return "+D4";
  return "—";
}

function calculateMovement(kin, agility) {
  let base = 10;
  switch (kin) {
  case "Halfling":
  case "Dwarf":
  case "Mallard":
    base = 8;
    break;
  case "Wolfkin":
    base = 12;
    break;
  case "Human":
  case "Elf":
    base = 10;
    break;
  default:
    base = 10;
    break;
  }

  let modifier = 0;
  if (agility <= 6) modifier = -4;
  else if (agility <= 9) modifier = -2;
  else if (agility <= 12) modifier = 0;
  else if (agility <= 15) modifier = 2;
  else modifier = 4;
  return Math.max(base + modifier, 0);
}

function calculateEncumbranceBaseLimit(strength) {
  return Math.max(Math.ceil(strength / 2), 0);
}

function sanitizeEncumbranceLimit(value, fallback) {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) return fallback;
  return Math.max(numeric, 0);
}

function normalizeSpells(source) {
  const seen = new Set();
  const list = Array.isArray(source) ? source : [];
  return list
    .map((spell) => ({
      name: (spell?.name ?? "").trim(),
      inGrimoire: spell?.inGrimoire !== undefined ? Boolean(spell.inGrimoire) : true,
      prepared: Boolean(spell?.prepared)
    }))
    .filter((spell) => {
      if (!spell.name) return false;
      const key = spell.name.toLowerCase();
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
}

function renderDynamicSections(initialRender = false) {
  renderAbilityList();
  renderSpellList();
  if (initialRender || !state.skillSectionsReady) {
    renderSkillSections();
    state.skillSectionsReady = true;
  } else {
    refreshSkillInputsValues();
    renderSecondarySkills();
  }
  renderInventoryList();
  renderWeaponsTable();
  renderDeathRolls();
  state.lockedSections.forEach((id) => applySectionLock(id, true, false));
}

function renderAbilityList() {
  const container = document.getElementById("abilitiesList");
  const addButton = document.getElementById("addAbilityButton");
  const abilityInput = document.getElementById("abilityInput");
  if (!container || !addButton || !abilityInput) return;
  container.innerHTML = "";
  const abilities = Array.isArray(state.data?.abilitiesAndSpells) ? state.data.abilitiesAndSpells : [];
  if (!abilities.length) {
    container.innerHTML = "<p class=\"empty-note\">No abilities added yet.</p>";
  } else {
    abilities.forEach((name, index) => {
      const pill = document.createElement("span");
      pill.className = "chip";
      pill.textContent = name;
      const remove = document.createElement("button");
      remove.type = "button";
      remove.className = "chip-remove";
      remove.ariaLabel = `Remove ${name}`;
      remove.textContent = "×";
      remove.addEventListener("click", () => {
        state.data.abilitiesAndSpells.splice(index, 1);
        renderAbilityList();
        markDirty();
      });
      pill.appendChild(remove);
      container.appendChild(pill);
    });
  }

  addButton.onclick = () => {
    const value = abilityInput.value.trim();
    if (!value) return;
    if (!state.data.abilitiesAndSpells.includes(value)) {
      state.data.abilitiesAndSpells.push(value);
      renderAbilityList();
      markDirty();
    }
    abilityInput.value = "";
  };
}

function renderSpellList() {
  const container = document.getElementById("spellsList");
  const addButton = document.getElementById("addSpellButton");
  const spellInput = document.getElementById("spellInput");
  const controls = document.querySelector(".magic-controls");
  if (!container || !addButton || !spellInput) return;
  container.innerHTML = "";
  const spells = Array.isArray(state.data?.spells) ? state.data.spells : [];
  const editing = isMagicEditable();
  addButton.disabled = !editing;
  spellInput.disabled = !editing;
  if (controls) {
    controls.classList.toggle("hidden", !editing);
  }
  if (!spells.length) {
    container.innerHTML = "<p class=\"empty-note\">No spells learned yet.</p>";
  } else {
    spells.forEach((spell, index) => {
      const card = document.createElement("div");
      card.className = "spell-card";

      const nameInput = document.createElement("input");
      nameInput.placeholder = "Spell name";
      nameInput.value = spell.name ?? "";
      nameInput.readOnly = true;

      const flags = document.createElement("div");
      flags.className = "spell-flags";

      const grimoireLabel = document.createElement("label");
      const grimoireToggle = document.createElement("input");
      grimoireToggle.type = "checkbox";
      grimoireToggle.checked = spell.inGrimoire ?? true;
      grimoireToggle.disabled = !editing;
      grimoireToggle.addEventListener("change", () => {
        state.data.spells[index].inGrimoire = grimoireToggle.checked;
        markDirty();
      });
      grimoireLabel.appendChild(grimoireToggle);
      grimoireLabel.appendChild(document.createTextNode(" In Grimoire"));

      const preparedLabel = document.createElement("label");
      const preparedToggle = document.createElement("input");
      preparedToggle.type = "checkbox";
      preparedToggle.checked = Boolean(spell.prepared);
      preparedToggle.disabled = !editing;
      preparedToggle.addEventListener("change", () => {
        state.data.spells[index].prepared = preparedToggle.checked;
        markDirty();
      });
      preparedLabel.appendChild(preparedToggle);
      preparedLabel.appendChild(document.createTextNode(" Prepared"));

      flags.appendChild(grimoireLabel);
      flags.appendChild(preparedLabel);

      const remove = document.createElement("button");
      remove.type = "button";
      remove.className = "chip-remove";
      remove.textContent = "✕";
      remove.ariaLabel = `Remove ${spell.name || "spell"}`;
      remove.style.display = editing ? "" : "none";
      remove.addEventListener("click", () => {
        state.data.spells.splice(index, 1);
        renderSpellList();
        markDirty();
      });

      card.appendChild(nameInput);
      card.appendChild(remove);
      card.appendChild(flags);
      container.appendChild(card);
    });
  }

  addButton.onclick = () => {
    const name = spellInput.value.trim();
    if (!editing || !name) return;
    state.data.spells.push({ name, inGrimoire: true, prepared: false });
    spellInput.value = "";
    renderSpellList();
    markDirty();
  };
}

function renderSkillSections() {
  renderSkillList("primarySkills", state.data.skills?.primary ?? [], "primary", false);
  renderSkillList("weaponSkills", state.data.skills?.weapon ?? [], "weapon", false);
  renderSecondarySkills();
}

function refreshSkillInputsValues() {
  updateSkillSectionInputs("primarySkills", state.data.skills?.primary ?? []);
  updateSkillSectionInputs("weaponSkills", state.data.skills?.weapon ?? []);
}

function updateSkillSectionInputs(containerId, entries) {
  const container = document.getElementById(containerId);
  if (!container) return;
  const rows = container.querySelectorAll(".skill-row");
  rows.forEach((row, index) => {
    const entry = entries[index];
    if (!entry) return;
    const level = row.querySelector(".skill-value");
    if (level) {
      level.value = entry.level ?? 0;
    }
    const toggle = row.querySelector(".skill-toggle");
    if (toggle) {
      toggle.checked = Boolean(entry.needsImprovement);
    }
  });
}

function renderSkillList(containerId, skills, sectionKey, allowRemove) {
  const container = document.getElementById(containerId);
  if (!container) return;
  container.innerHTML = "";
  skills.forEach((entry, index) => {
    const row = document.createElement("div");
    row.className = "skill-row";
    const level = document.createElement("input");
    level.type = "number";
    level.min = "0";
    level.value = entry.level ?? 0;
    level.className = "skill-value";
    level.addEventListener("input", () => {
      updateSkill(sectionKey, index, "level", Number(level.value) || 0);
    });
    const checkbox = document.createElement("input");
    checkbox.type = "checkbox";
    checkbox.className = "skill-toggle";
    checkbox.checked = Boolean(entry.needsImprovement);
    checkbox.addEventListener("change", () => {
      updateSkill(sectionKey, index, "needsImprovement", checkbox.checked);
    });
    const attr = SKILL_ATTRIBUTE_MAP[entry.name] ? ` (${SKILL_ATTRIBUTE_MAP[entry.name]})` : "";
    const name = document.createElement("span");
    name.className = "skill-label";
    name.textContent = `${entry.name}${attr}`;
    row.appendChild(checkbox);
    row.appendChild(level);
    row.appendChild(name);

    if (allowRemove) {
      row.classList.add("removable");
      const remove = document.createElement("button");
      remove.type = "button";
      remove.className = "chip-remove";
      remove.textContent = "Remove";
      remove.addEventListener("click", () => {
        state.data.skills[sectionKey].splice(index, 1);
        renderSecondarySkills();
        markDirty();
      });
      row.appendChild(remove);
    }
    container.appendChild(row);
  });
}

function renderSecondarySkills() {
  renderSkillList("secondarySkills", state.data.skills?.secondary ?? [], "secondary", true);
  populateSecondarySelect();
  const select = document.getElementById("secondarySkillSelect");
  const button = document.getElementById("addSecondarySkillButton");
  if (!select || !button) return;
  button.onclick = () => {
    const value = select.value;
    if (!value) return;
    const exists = state.data.skills.secondary.some((entry) => entry.name === value);
    if (exists) return;
    state.data.skills.secondary.push({ name: value, level: 0, needsImprovement: false });
    renderSecondarySkills();
    markDirty();
  };
}

function updateSkill(sectionKey, index, field, value) {
  if (!state.data.skills?.[sectionKey] || !state.data.skills[sectionKey][index]) return;
  state.data.skills[sectionKey][index][field] = value;
  markDirty();
}

function renderInventoryList() {
  const container = document.getElementById("inventoryList");
  const button = document.getElementById("addInventoryButton");
  if (!container || !button) return;
  const items = Array.isArray(state.data.inventory) ? state.data.inventory : [];
  container.innerHTML = "";
  items.forEach((item, index) => {
    const card = document.createElement("div");
    card.className = "inventory-card";

    const nameField = document.createElement("input");
    nameField.placeholder = "Item name";
    nameField.value = item.name ?? "";
    nameField.addEventListener("input", () => {
      state.data.inventory[index].name = nameField.value;
      markDirty();
      updateEncumbranceDisplay();
    });

    const detailField = document.createElement("textarea");
    detailField.placeholder = "Details, traits, costs...";
    detailField.value = item.details ?? "";
    detailField.rows = 2;
    detailField.addEventListener("input", () => {
      state.data.inventory[index].details = detailField.value;
      markDirty();
    });

    const slotRow = document.createElement("div");
    slotRow.className = "inventory-slots";
    const slotLabel = document.createElement("span");
    slotLabel.textContent = "Weight";
    const slotInput = document.createElement("input");
    slotInput.type = "number";
    slotInput.min = "0";
    if (typeof state.data.inventory[index].slots !== "number") {
      state.data.inventory[index].slots = 0;
    }
    slotInput.value = state.data.inventory[index].slots ?? 0;
    slotInput.addEventListener("input", () => {
      const value = Math.max(parseInt(slotInput.value, 10) || 0, 0);
      slotInput.value = value;
      state.data.inventory[index].slots = value;
      updateEncumbranceDisplay();
      markDirty();
    });
    slotRow.appendChild(slotLabel);
    slotRow.appendChild(slotInput);

    const remove = document.createElement("button");
    remove.type = "button";
    remove.className = "chip-remove";
    remove.textContent = "Remove";
    remove.addEventListener("click", () => {
      state.data.inventory.splice(index, 1);
      renderInventoryList();
      markDirty();
    });

    card.appendChild(nameField);
    card.appendChild(detailField);
    card.appendChild(slotRow);
    card.appendChild(remove);
    container.appendChild(card);
  });
  updateEncumbranceDisplay();

  button.onclick = () => {
    state.data.inventory.push({ name: "", details: "", slots: 1 });
    renderInventoryList();
    markDirty();
  };
}

function updateEncumbranceDisplay() {
  const strength = state.data?.attributes?.strength ?? 0;
  const baseLimit = calculateEncumbranceBaseLimit(strength);
  const limitInput = document.getElementById("encumbranceLimit");
  const baseLabel = document.getElementById("encumbranceBase");
  const usedEl = document.getElementById("encumbranceUsage");
  if (baseLabel) {
    baseLabel.textContent = baseLimit;
  }
  let limit = sanitizeEncumbranceLimit(state.data?.encumbranceLimit, baseLimit);
  if (state.data && state.data.encumbranceLimit !== limit) {
    state.data.encumbranceLimit = limit;
    refreshBindingsForPath("encumbranceLimit");
  }
  if (limitInput) {
    const renderedValue = String(limit);
    if (limitInput.value !== renderedValue) {
      limitInput.value = renderedValue;
    }
  }
  let used = 0;
  const cards = document.querySelectorAll("#inventoryList .inventory-card");
  cards.forEach((card, index) => {
    const slots = Math.max(Number(state.data?.inventory?.[index]?.slots) || 0, 0);
    used += slots;
    card.classList.toggle("over-limit", limit >= 0 && used > limit);
  });
  if (usedEl) {
    usedEl.textContent = used;
  }
}

function renderWeaponsTable() {
  const body = document.getElementById("weaponsTable");
  if (!body) return;
  const weapons = state.data.weapons ?? [];
  body.innerHTML = "";
  weapons.forEach((weapon, index) => {
    const row = document.createElement("tr");

    const nameCell = document.createElement("td");
    const nameInput = document.createElement("input");
    nameInput.value = weapon.name ?? "";
    nameInput.addEventListener("input", () => {
      state.data.weapons[index].name = nameInput.value;
      markDirty();
    });
    nameCell.appendChild(nameInput);

    const gripCell = document.createElement("td");
    const gripSelect = document.createElement("select");
    GRIP_OPTIONS.forEach((optionValue) => {
      const option = document.createElement("option");
      option.value = optionValue;
      option.textContent = optionValue || "—";
      gripSelect.appendChild(option);
    });
    gripSelect.value = weapon.grip ?? "";
    gripSelect.addEventListener("change", () => {
      state.data.weapons[index].grip = gripSelect.value;
      markDirty();
    });
    gripCell.appendChild(gripSelect);

    const rangeCell = document.createElement("td");
    const rangeInput = document.createElement("input");
    rangeInput.className = "tiny-input";
    rangeInput.value = weapon.range ?? "";
    rangeInput.addEventListener("input", () => {
      state.data.weapons[index].range = rangeInput.value;
      markDirty();
    });
    rangeCell.appendChild(rangeInput);

    const damageCell = document.createElement("td");
    const damageInput = document.createElement("input");
    damageInput.className = "tiny-input";
    damageInput.value = weapon.damage ?? "";
    damageInput.addEventListener("input", () => {
      state.data.weapons[index].damage = damageInput.value;
      markDirty();
    });
    damageCell.appendChild(damageInput);

    const durabilityCell = document.createElement("td");
    const durabilityInput = document.createElement("input");
    durabilityInput.type = "number";
    durabilityInput.min = "0";
    durabilityInput.className = "tiny-input";
    durabilityInput.value = weapon.durability ?? 0;
    durabilityInput.addEventListener("input", () => {
      state.data.weapons[index].durability = Number(durabilityInput.value) || 0;
      markDirty();
    });
    durabilityCell.appendChild(durabilityInput);

    const featureCell = document.createElement("td");
    const featuresInput = document.createElement("textarea");
    featuresInput.rows = 2;
    featuresInput.value = weapon.features ?? "";
    featuresInput.addEventListener("input", () => {
      state.data.weapons[index].features = featuresInput.value;
      markDirty();
    });
    featureCell.appendChild(featuresInput);

    row.appendChild(nameCell);
    row.appendChild(gripCell);
    row.appendChild(rangeCell);
    row.appendChild(damageCell);
    row.appendChild(durabilityCell);
    row.appendChild(featureCell);
    body.appendChild(row);
  });
}

function renderDeathRolls() {
  renderDeathTrack("deathSuccesses", state.data.deathRolls?.successes ?? [], "successes");
  renderDeathTrack("deathFailures", state.data.deathRolls?.failures ?? [], "failures");
}

function renderDeathTrack(containerId, toggles, field) {
  const container = document.getElementById(containerId);
  if (!container) return;
  container.innerHTML = "";
  toggles.forEach((value, index) => {
    const label = document.createElement("label");
    label.className = "death-box";
    const checkbox = document.createElement("input");
    checkbox.type = "checkbox";
    checkbox.checked = Boolean(value);
    checkbox.addEventListener("change", () => {
      state.data.deathRolls[field][index] = checkbox.checked;
      markDirty();
    });
    label.appendChild(checkbox);
    container.appendChild(label);
  });
}

function markDirty() {
  state.dirty = true;
  updateSaveStatus("Unsaved changes…");
  scheduleAutoSave();
}

function scheduleAutoSave() {
  if (state.saveTimer) {
    clearTimeout(state.saveTimer);
  }
  state.saveTimer = setTimeout(() => {
    saveSheet();
  }, 1200);
}

async function saveSheet(force = false) {
  if (state.saveTimer) {
    clearTimeout(state.saveTimer);
    state.saveTimer = null;
  }
  if (!state.dirty && !force) return;
  if (state.saving) {
    state.pendingSave = true;
    return;
  }
  state.saving = true;
  updateSaveStatus("Saving…");
  try {
    const response = await fetch(`/api/sheets/${state.sheetId}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(state.data)
    });
    if (!response.ok) {
      const message = await response.text();
      throw new Error(message || "Unable to save sheet.");
    }
    const payload = await response.json();
    state.data = payload.data;
    state.dirty = false;
    renderDynamicSections();
    refreshBindings();
    updateDerivedFields();
    updateSaveStatus(`Saved ${new Date().toLocaleTimeString()}`);
  } catch (error) {
    updateSaveStatus(error.message || "Failed to save.", true);
  } finally {
    state.saving = false;
    if (state.pendingSave) {
      state.pendingSave = false;
      saveSheet();
    }
  }
}

function updateSaveStatus(message, isError = false) {
  if (!state.statusElement) return;
  state.statusElement.textContent = message;
  state.statusElement.classList.toggle("error", isError);
}
