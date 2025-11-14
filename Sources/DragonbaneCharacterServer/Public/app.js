const kinOptions = [
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

const professionOptions = [
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

const ageOptions = ["Young", "Adult", "Old"];
const LLM_DEFAULTS = {
  openai: {
    server: "https://api.openai.com",
    model: "gpt-4o-mini"
  }
};

const IMAGE_DEFAULTS = {
  server: "https://api.openai.com",
  model: "gpt-image-1"
};

const ADMIN_TOKEN_STORAGE_KEY = "dragonbaneAdminToken";
let appConfig = null;

if (typeof document !== "undefined") {
  document.addEventListener("DOMContentLoaded", async () => {
    await loadAppConfig();
    setupTabs();
    setupAdminTokenField();
    populateSelect(document.getElementById("randomKin"), kinOptions, true);
    populateSelect(document.getElementById("randomProfession"), professionOptions, true);
    populateSelect(document.getElementById("generateKin"), kinOptions);
    populateSelect(document.getElementById("generateProfession"), professionOptions);
    populateSelect(document.getElementById("generateAge"), ageOptions);
    populateSelect(document.getElementById("bulkKin"), kinOptions);
    populateSelect(document.getElementById("bulkProfession"), professionOptions);
    populateSelect(document.getElementById("bulkAge"), ageOptions);

    configureNarrativeModeControls({
      modeSelectId: "generateNarrativeMode",
      serverGroupId: "llmServerGroup",
      modelGroupId: "llmModelGroup",
      keyGroupId: "llmKeyGroup",
      serverInputId: "llmServer",
      modelInputId: "llmModel"
    });
    configureNarrativeModeControls({
      modeSelectId: "bulkNarrativeMode",
      serverGroupId: "bulkLlmServerGroup",
      modelGroupId: "bulkLlmModelGroup",
      keyGroupId: "bulkLlmKeyGroup",
      serverInputId: "bulkLlmServer",
      modelInputId: "bulkLlmModel"
    });

    setEmptyCharacterSheet(
      document.getElementById("randomResult"),
      "Fetch a random character to preview their sheet."
    );
    setEmptyCharacterSheet(
      document.getElementById("generateResult"),
      "Generate a hero to see their stats."
    );

    const randomForm = document.getElementById("randomForm");
    if (randomForm) {
      randomForm.addEventListener("submit", handleRandomSubmit);
    }
    const generateForm = document.getElementById("generateForm");
    if (generateForm) {
      generateForm.addEventListener("submit", handleGenerateSubmit);
    }
    const editSelect = document.getElementById("editCharacter");
    if (editSelect) {
      editSelect.addEventListener("change", handleSelectChange);
    }
    const editForm = document.getElementById("editForm");
    if (editForm) {
      editForm.addEventListener("submit", handleEditSubmit);
    }

    const imageCharacter = document.getElementById("imageCharacter");
    if (imageCharacter) {
      imageCharacter.addEventListener("change", handleImageSelectChange);
    }
    const imageForm = document.getElementById("imageForm");
    if (imageForm) {
      imageForm.addEventListener("submit", handleImageSubmit);
    }

    const bulkForm = document.getElementById("bulkForm");
    if (bulkForm) {
      bulkForm.addEventListener("submit", handleBulkSubmit);
    }
    const refreshRoster = document.getElementById("refreshRoster");
    if (refreshRoster) {
      refreshRoster.addEventListener("click", () => loadCharacterList({ showRosterSpinner: true }));
    }

    loadCharacterList();
  });
}

async function loadAppConfig() {
  if (typeof fetch === "undefined") {
    return;
  }
  try {
    const response = await fetch("/api/config");
    if (!response.ok) {
      throw new Error(`Failed to load config: ${response.status}`);
    }
    const data = await response.json();
    appConfig = { ...data };
    applyNarrativeModeAvailability();
  } catch (error) {
    console.warn("Unable to load UI configuration:", error);
  }
}

function applyNarrativeModeAvailability() {
  if (!appConfig || appConfig.localLLMEnabled) {
    return;
  }
  ["generateNarrativeMode", "bulkNarrativeMode"].forEach((id) => {
    const select = document.getElementById(id);
    if (!select) return;
    const option = select.querySelector('option[value="local"]');
    if (!option) return;
    const wasSelected = option.selected;
    option.remove();
    if (wasSelected) {
      select.value = "offline";
    }
  });
}

function setupTabs() {
  const buttons = document.querySelectorAll(".tab-button");
  const panels = document.querySelectorAll(".tab-panel");
  if (!buttons.length || !panels.length) return;
  const activeButton = document.querySelector(".tab-button.active");
  const defaultTab = activeButton?.dataset.tab || buttons[0].dataset.tab;

  const activate = (tab) => {
    buttons.forEach((button) => {
      const isActive = button.dataset.tab === tab;
      button.classList.toggle("active", isActive);
      button.setAttribute("aria-selected", isActive ? "true" : "false");
      button.tabIndex = isActive ? 0 : -1;
    });
    panels.forEach((panel) => {
      const isActive = panel.dataset.tab === tab;
      panel.classList.toggle("active", isActive);
      panel.hidden = !isActive;
    });
  };

  buttons.forEach((button) => {
    button.addEventListener("click", () => {
      activate(button.dataset.tab);
    });
  });

  activate(defaultTab);
}

function populateSelect(select, options, isMultiple = false) {
  if (!select || !Array.isArray(options)) return;
  options.forEach((value) => {
    const option = document.createElement("option");
    option.value = value;
    option.textContent = value;
    select.appendChild(option);
  });
  if (isMultiple) {
    select.size = Math.min(options.length, 8);
  }
}

function selectedValues(select) {
  return Array.from(select.selectedOptions).map((opt) => opt.value);
}

function configureNarrativeModeControls(config) {
  const select = document.getElementById(config.modeSelectId);
  if (!select) return;
  const handle = () => {
    const mode = select.value;
    const showEndpointFields = mode === "openai" || mode === "custom";
    toggleField(config.serverGroupId, showEndpointFields);
    toggleField(config.modelGroupId, showEndpointFields);
    toggleField(config.keyGroupId, mode === "openai" || mode === "custom");

    if (mode === "openai" && LLM_DEFAULTS.openai) {
      const defaults = LLM_DEFAULTS.openai;
      const serverInput = document.getElementById(config.serverInputId);
      const modelInput = document.getElementById(config.modelInputId);
      if (serverInput) serverInput.value = defaults.server;
      if (modelInput) modelInput.value = defaults.model;
    }
  };
  select.addEventListener("change", handle);
  handle();
}

async function handleRandomSubmit(event) {
  event.preventDefault();
  const kin = selectedValues(document.getElementById("randomKin"));
  const professions = selectedValues(document.getElementById("randomProfession"));
  const params = new URLSearchParams();
  if (kin.length) params.set("kin", kin.join(","));
  if (professions.length) params.set("profession", professions.join(","));

  const resultContainer = document.getElementById("randomResult");
  setBusy(resultContainer, "Fetching character...");

  try {
    const response = await fetch(`/api/characters/random${params.toString() ? `?${params.toString()}` : ""}`);
    if (!response.ok) {
      const message = await extractError(response);
      throw new Error(message || "Failed to fetch a character.");
    }
    const character = await response.json();
    renderCharacter(resultContainer, character);
  } catch (error) {
    setStatus(resultContainer, error.message);
  }
}

async function handleGenerateSubmit(event) {
  event.preventDefault();
  const payload = {};
  const kin = getValue("generateKin");
  const profession = getValue("generateProfession");
  const age = getValue("generateAge");
  const name = getTrimmedValue("generateName");
  const appearance = getTrimmedValue("generateAppearance");
  const background = getTrimmedValue("generateBackground");

  if (kin) payload.race = kin;
  if (profession) payload.profession = profession;
  if (age) payload.age = age;
  if (name) payload.name = name;
  if (appearance) payload.appearance = appearance;
  if (background) payload.background = background;

  const resultContainer = document.getElementById("generateResult");
  const token = ensureAdminToken(resultContainer);
  if (!token) {
    return;
  }
  const narrativeMode = getValue("generateNarrativeMode") || "offline";
  const useLLM = narrativeMode !== "offline";
  if (useLLM) {
    payload.narrativeMode = "llm";
    const needsEndpoint = narrativeMode === "openai" || narrativeMode === "custom";
    const server = needsEndpoint ? getTrimmedValue("llmServer") : "";
    const model = needsEndpoint ? getTrimmedValue("llmModel") : "";
    const apiKey = getTrimmedValue("llmApiKey");

    if (needsEndpoint) {
      if (!server) {
        setStatus(resultContainer, "Provide an LLM server URL.");
        return;
      }
      if (!model) {
        setStatus(resultContainer, "Provide an LLM model identifier.");
        return;
      }
      payload.llmServer = server;
      payload.llmModel = model;
    }

    if (narrativeMode === "openai" && !apiKey) {
      setStatus(resultContainer, "OpenAI requests require an API key.");
      return;
    }
    if (apiKey) {
      payload.llmApiKey = apiKey;
    }
    setBusy(resultContainer, "Generating detailed narrative via LLM...");
  } else {
    setBusy(resultContainer, "Generating character...");
  }

  try {
    const response = await fetch("/api/characters/generate", {
      method: "POST",
      headers: buildAdminHeaders(token, { "Content-Type": "application/json" }),
      body: JSON.stringify(payload)
    });
    if (!response.ok) {
      const message = await extractError(response);
      throw new Error(message || "Generation failed.");
    }
    const character = await response.json();
    renderCharacter(resultContainer, character);
    await loadCharacterList();
  } catch (error) {
    setStatus(resultContainer, error.message);
  }
}

async function handleBulkSubmit(event) {
  event.preventDefault();
  const status = document.getElementById("bulkStatus");
  const token = ensureAdminToken(status);
  if (!token) {
    return;
  }
  const payload = {};
  const kin = getValue("bulkKin");
  const profession = getValue("bulkProfession");
  const age = getValue("bulkAge");
  const count = clampBatchCount(Number(getValue("bulkCount")) || 0);
  if (kin) payload.race = kin;
  if (profession) payload.profession = profession;
  if (age) payload.age = age;
  payload.count = count;

  const mode = getValue("bulkNarrativeMode") || "offline";
  const useLLM = mode !== "offline";
  if (useLLM) {
    payload.narrativeMode = "llm";
    const needsEndpoint = mode === "openai" || mode === "custom";
    const server = needsEndpoint ? getTrimmedValue("bulkLlmServer") : "";
    const model = needsEndpoint ? getTrimmedValue("bulkLlmModel") : "";
    const apiKey = getTrimmedValue("bulkLlmApiKey");

    if (needsEndpoint) {
      if (!server) {
        setStatus(status, "Provide an LLM server URL.");
        return;
      }
      if (!model) {
        setStatus(status, "Provide an LLM model identifier.");
        return;
      }
      payload.llmServer = server;
      payload.llmModel = model;
    }

    if (mode === "openai" && !apiKey) {
      setStatus(status, "OpenAI requests require an API key.");
      return;
    }
    if (apiKey) {
      payload.llmApiKey = apiKey;
    }
  }

  setBusy(status, `Generating ${count} character${count === 1 ? "" : "s"}...`);

  try {
    const response = await fetch("/api/characters/bulk-generate", {
      method: "POST",
      headers: buildAdminHeaders(token, { "Content-Type": "application/json" }),
      body: JSON.stringify(payload)
    });
    if (!response.ok) {
      const message = await extractError(response);
      throw new Error(message || "Bulk generation failed.");
    }
    const characters = await response.json();
    const ids = characters.map((character) => (character.id ? `#${character.id}` : null)).filter(Boolean).join(", ");
    setStatus(
      status,
      `Created ${characters.length} character${characters.length === 1 ? "" : "s"}${ids ? ` (${ids})` : ""}.`
    );
    await loadCharacterList();
  } catch (error) {
    setStatus(status, error.message);
  }
}

async function loadCharacterList(options = {}) {
  const editSelect = document.getElementById("editCharacter");
  const imageSelect = document.getElementById("imageCharacter");
  const rosterStatusEl = document.getElementById("rosterStatus");
  const showRosterSpinner = Boolean(options.showRosterSpinner && rosterStatusEl);
  if (!editSelect && !imageSelect && !rosterStatusEl) return;
  if (showRosterSpinner) {
    setBusy(rosterStatusEl, "Refreshing roster...");
  }

  try {
    const response = await fetch("/api/characters?limit=100");
    if (!response.ok) {
      throw new Error("Unable to load characters.");
    }
    const characters = await response.json();
    if (editSelect) {
      const previousValue = editSelect.value;
      editSelect.innerHTML = '<option value="">Choose a saved character</option>';
      characters.forEach((character) => {
        if (!character.id) return;
        const option = document.createElement("option");
        option.value = character.id;
        option.textContent = `#${character.id} — ${character.name || character.race}`;
        editSelect.appendChild(option);
      });
      if (previousValue) {
        editSelect.value = previousValue;
        if (editSelect.value === previousValue) {
          await populateEditForm(previousValue);
        }
      }
    }
    if (imageSelect) {
      const previousValue = imageSelect.value;
      imageSelect.innerHTML = '<option value="">Choose a saved character</option>';
      characters.forEach((character) => {
        if (!character.id) return;
        const option = document.createElement("option");
        option.value = character.id;
        option.textContent = `#${character.id} — ${character.name || character.race}`;
        imageSelect.appendChild(option);
      });
      if (previousValue) {
        imageSelect.value = previousValue;
      }
      if (imageSelect.value) {
        await loadImageGallery(imageSelect.value);
      } else {
        const imageStatus = document.getElementById("imageStatus");
        if (imageStatus) {
          imageStatus.textContent = "Select a character to view portraits.";
        }
        const gallery = document.getElementById("imageGallery");
        if (gallery) {
          gallery.innerHTML = "";
        }
      }
    }
    renderAdminRoster(characters);
  } catch (error) {
    const editStatus = document.getElementById("editStatus");
    if (editStatus) {
      editStatus.textContent = error.message;
    }
    const imageStatus = document.getElementById("imageStatus");
    if (imageStatus) {
      imageStatus.textContent = error.message;
    }
    if (rosterStatusEl) {
      setStatus(rosterStatusEl, error.message);
    }
  }
}

async function handleSelectChange(event) {
  const id = event.target.value;
  const form = document.getElementById("editForm");
  const status = document.getElementById("editStatus");
  if (!id) {
    if (form) form.classList.add("hidden");
    if (status) status.textContent = "";
    return;
  }
  await populateEditForm(id);
}

async function populateEditForm(id) {
  try {
    const response = await fetch(`/api/characters/${id}`);
    if (!response.ok) {
      throw new Error("Unable to load character details.");
    }
    const character = await response.json();
    document.getElementById("editForm")?.classList.remove("hidden");
    document.getElementById("editName").value = character.name;
    document.getElementById("editAppearance").value = character.appearance;
    document.getElementById("editBackground").value = character.background;
    document.getElementById("editWeakness").value = character.weakness;
    document.getElementById("editMemento").value = character.memento;
    document.getElementById("editGear").value = character.gear.join(", ");
    const status = document.getElementById("editStatus");
    if (status) status.textContent = "";
  } catch (error) {
    const status = document.getElementById("editStatus");
    if (status) status.textContent = error.message;
  }
}

async function handleEditSubmit(event) {
  event.preventDefault();
  const select = document.getElementById("editCharacter");
  if (!select) return;
  const id = select.value;
  if (!id) return;

  const payload = {
    name: getTrimmedValue("editName"),
    appearance: getTrimmedValue("editAppearance"),
    background: getTrimmedValue("editBackground"),
    weakness: getTrimmedValue("editWeakness"),
    memento: getTrimmedValue("editMemento"),
    gear: parseList(getValue("editGear"))
  };

  const status = document.getElementById("editStatus");
  const token = ensureAdminToken(status);
  if (!token) {
    return;
  }
  if (status) status.textContent = "Saving changes...";

  try {
    const response = await fetch(`/api/characters/${id}`, {
      method: "PUT",
      headers: buildAdminHeaders(token, { "Content-Type": "application/json" }),
      body: JSON.stringify(payload)
    });
    if (!response.ok) {
      const message = await extractError(response);
      throw new Error(message || "Failed to save changes.");
    }
    const updated = await response.json();
    if (status) status.textContent = "Character updated.";
    updateOptionLabel(select, updated);
  } catch (error) {
    if (status) status.textContent = error.message;
  }
}

async function handleImageSelectChange(event) {
  await loadImageGallery(event.target.value);
}

async function handleImageSubmit(event) {
  event.preventDefault();
  const characterId = getValue("imageCharacter");
  const status = document.getElementById("imageStatus");
  if (!characterId) {
    setStatus(status, "Select a character first.");
    return;
  }

  const payload = {};
  const server = getTrimmedValue("imageServer") || IMAGE_DEFAULTS.server;
  const model = getTrimmedValue("imageModel") || IMAGE_DEFAULTS.model;
  const apiKey = getTrimmedValue("imageApiKey");
  if (server) payload.server = server;
  if (model) payload.model = model;
  if (apiKey) payload.apiKey = apiKey;

  const token = ensureAdminToken(status);
  if (!token) {
    return;
  }

  setBusy(status, "Requesting portrait from the image model...");

  try {
    const response = await fetch(`/api/characters/${characterId}/images`, {
      method: "POST",
      headers: buildAdminHeaders(token, { "Content-Type": "application/json" }),
      body: JSON.stringify(Object.keys(payload).length ? payload : {})
    });
    if (!response.ok) {
      const message = await extractError(response);
      throw new Error(message || "Image generation failed.");
    }
    const image = await response.json();
    await loadImageGallery(characterId);
    setStatus(status, `Saved portrait #${image.id}.`);
  } catch (error) {
    setStatus(status, error.message);
  }
}

async function loadImageGallery(characterId) {
  const gallery = document.getElementById("imageGallery");
  const status = document.getElementById("imageStatus");
  if (!gallery || !status) return;

  if (!characterId) {
    gallery.innerHTML = "";
    status.textContent = "Select a character to view portraits.";
    return;
  }

  status.textContent = "Loading portraits...";

  try {
    const response = await fetch(`/api/characters/${characterId}/images`);
    if (!response.ok) {
      const message = await extractError(response);
      throw new Error(message || "Unable to load portraits.");
    }
    const images = await response.json();
    gallery.innerHTML = "";
    if (!images.length) {
      status.textContent = "No portraits have been generated yet.";
      return;
    }
    status.textContent = "";
    images.forEach((image) => {
      const figure = document.createElement("figure");
      figure.className = "image-card";
      const img = document.createElement("img");
      img.alt = `Character portrait ${image.id}`;
      img.loading = "lazy";
      img.src = image.downloadURL;
      const caption = document.createElement("figcaption");
      caption.textContent = `#${image.id} • ${formatTimestamp(image.createdAt)}`;
      figure.appendChild(img);
      figure.appendChild(caption);
      gallery.appendChild(figure);
    });
  } catch (error) {
    status.textContent = error.message;
    gallery.innerHTML = "";
  }
}

function updateOptionLabel(select, character) {
  if (!select || !character?.id) return;
  const option = Array.from(select.options).find((opt) => opt.value === String(character.id));
  if (option) {
    option.textContent = `#${character.id} — ${character.name || character.race}`;
  }
}

function renderCharacter(container, character) {
  if (!container) return;
  container.classList.remove("loading");
  container.classList.add("character-sheet");
  container.classList.remove("empty");
  container.innerHTML = "";
  if (!character) {
    setEmptyCharacterSheet(container, "No character to display yet.");
    return;
  }

  const header = document.createElement("div");
  header.className = "sheet-header";
  const headerText = document.createElement("div");
  const name = document.createElement("p");
  name.className = "sheet-name";
  name.textContent = character.name;
  const meta = document.createElement("p");
  meta.className = "sheet-meta";
  meta.textContent = `${character.race} • ${character.profession} • ${character.age}`;
  headerText.appendChild(name);
  headerText.appendChild(meta);
  header.appendChild(headerText);
  if (character.id) {
    const identifier = document.createElement("div");
    identifier.className = "sheet-id";
    identifier.textContent = `#${character.id}`;
    header.appendChild(identifier);
  }
  container.appendChild(header);

  const statGrid = document.createElement("div");
  statGrid.className = "stat-grid";
  [
    ["STR", character.strength],
    ["CON", character.constitution],
    ["AGL", character.agility],
    ["INT", character.intelligence],
    ["WIL", character.willpower],
    ["CHA", character.charisma]
  ].forEach(([label, value]) => {
    statGrid.appendChild(createStatCard(label, value));
  });
  container.appendChild(statGrid);

  const listGrid = document.createElement("div");
  listGrid.className = "list-grid";
  listGrid.appendChild(createListCard("Heroic Abilities", character.heroicAbilities));
  listGrid.appendChild(createListCard("Trained Skills", character.trainedSkills));
  listGrid.appendChild(createListCard("Magic", character.magic));
  listGrid.appendChild(createListCard("Gear", character.gear));
  container.appendChild(listGrid);

  const storyGrid = document.createElement("div");
  storyGrid.className = "list-grid";
  storyGrid.appendChild(createTextCard("Weakness", character.weakness));
  storyGrid.appendChild(createTextCard("Memento", character.memento));
  storyGrid.appendChild(createTextCard("Appearance", character.appearance));
  storyGrid.appendChild(createTextCard("Background", character.background));
  container.appendChild(storyGrid);
}

function createStatCard(label, value) {
  const wrapper = document.createElement("div");
  wrapper.className = "stat-card";
  const statLabel = document.createElement("span");
  statLabel.className = "stat-label";
  statLabel.textContent = label;
  const statValue = document.createElement("span");
  statValue.className = "stat-value";
  statValue.textContent = value ?? "—";
  wrapper.appendChild(statLabel);
  wrapper.appendChild(statValue);
  return wrapper;
}

function createListCard(title, items) {
  const card = document.createElement("div");
  card.className = "list-card";
  const heading = document.createElement("h3");
  heading.textContent = title;
  card.appendChild(heading);
  if (!Array.isArray(items) || items.length === 0) {
    const empty = document.createElement("p");
    empty.textContent = "None";
    card.appendChild(empty);
    return card;
  }
  const list = document.createElement("ul");
  items.forEach((item) => {
    const li = document.createElement("li");
    li.textContent = item;
    list.appendChild(li);
  });
  card.appendChild(list);
  return card;
}

function createTextCard(title, text) {
  const card = document.createElement("div");
  card.className = "list-card";
  const heading = document.createElement("h3");
  heading.textContent = title;
  card.appendChild(heading);
  const paragraph = document.createElement("p");
  paragraph.textContent = text && text.trim().length ? text : "—";
  card.appendChild(paragraph);
  return card;
}

function renderAdminRoster(characters) {
  const body = document.getElementById("rosterTableBody");
  const status = document.getElementById("rosterStatus");
  if (!body || !status) return;
  status.classList.remove("loading");
  body.innerHTML = "";
  if (!Array.isArray(characters) || characters.length === 0) {
    status.textContent = "No characters saved yet.";
    return;
  }
  status.textContent = "";
  characters.forEach((character) => {
    if (!character.id) return;
    const row = document.createElement("tr");
    const idCell = document.createElement("td");
    idCell.textContent = `#${character.id}`;
    const nameCell = document.createElement("td");
    nameCell.textContent = character.name || "Unnamed";
    const kinCell = document.createElement("td");
    kinCell.textContent = character.race;
    const professionCell = document.createElement("td");
    professionCell.textContent = character.profession;
    const actionCell = document.createElement("td");
    const deleteButton = document.createElement("button");
    deleteButton.type = "button";
    deleteButton.className = "action-danger";
    deleteButton.textContent = "Delete";
    deleteButton.addEventListener("click", () => {
      deleteCharacter(character.id, character.name || character.race);
    });
    actionCell.appendChild(deleteButton);
    row.appendChild(idCell);
    row.appendChild(nameCell);
    row.appendChild(kinCell);
    row.appendChild(professionCell);
    row.appendChild(actionCell);
    body.appendChild(row);
  });
}

async function deleteCharacter(id, label) {
  if (!id) return;
  const confirmation = window.confirm(`Delete ${label ? `"${label}" ` : ""}character #${id}?`);
  if (!confirmation) return;

  const status = document.getElementById("rosterStatus");
  const token = ensureAdminToken(status);
  if (!token) {
    return;
  }
  setBusy(status, `Deleting #${id}...`);
  try {
    const response = await fetch(`/api/characters/${id}`, {
      method: "DELETE",
      headers: buildAdminHeaders(token)
    });
    if (!response.ok) {
      const message = await extractError(response);
      throw new Error(message || "Failed to delete character.");
    }
    await loadCharacterList();
    setStatus(status, `Deleted character #${id}.`);
  } catch (error) {
    setStatus(status, error.message);
  }
}

function parseList(value) {
  return value
    .split(/[,\n]/)
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
}

function setBusy(element, message) {
  if (!element) return;
  element.classList.add("loading");
  element.classList.remove("empty");
  element.innerHTML = `<div class="spinner" aria-hidden="true"></div><span>${message}</span>`;
}

function setStatus(element, message) {
  if (!element) return;
  element.classList.remove("loading");
  element.textContent = message || "";
}

function setEmptyCharacterSheet(element, message) {
  if (!element) return;
  element.classList.remove("loading");
  element.classList.add("character-sheet", "empty");
  element.textContent = message;
}

function toggleField(id, show) {
  const el = document.getElementById(id);
  if (!el) return;
  el.classList.toggle("hidden", !show);
}

function clampBatchCount(value) {
  if (!Number.isFinite(value) || value <= 0) return 1;
  return Math.min(Math.max(Math.floor(value), 1), 20);
}

function getValue(id) {
  const element = document.getElementById(id);
  return element ? element.value : "";
}

function getTrimmedValue(id) {
  return getValue(id).trim();
}

function setupAdminTokenField() {
  const input = document.getElementById("adminToken");
  if (!input) return;
  const stored = getStoredAdminToken();
  if (stored) {
    input.value = stored;
  }
  input.addEventListener("input", () => {
    persistAdminToken(input.value.trim());
  });
}

function getStoredAdminToken() {
  if (typeof localStorage === "undefined") {
    return "";
  }
  return localStorage.getItem(ADMIN_TOKEN_STORAGE_KEY) || "";
}

function persistAdminToken(value) {
  if (typeof localStorage === "undefined") {
    return;
  }
  const trimmed = value.trim();
  if (trimmed) {
    localStorage.setItem(ADMIN_TOKEN_STORAGE_KEY, trimmed);
  } else {
    localStorage.removeItem(ADMIN_TOKEN_STORAGE_KEY);
  }
}

function getAdminToken() {
  const input = document.getElementById("adminToken");
  if (input && input.value.trim()) {
    return input.value.trim();
  }
  return getStoredAdminToken();
}

function ensureAdminToken(statusElement) {
  const token = getAdminToken();
  if (!token) {
    setStatus(statusElement, "Enter the admin API token first.");
    return null;
  }
  return token;
}

function buildAdminHeaders(token, base = {}) {
  return { ...base, Authorization: `Bearer ${token}` };
}

function formatTimestamp(value) {
  if (!value) return "Just now";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }
  return date.toLocaleString();
}

async function extractError(response) {
  try {
    const data = await response.json();
    if (data?.reason) return data.reason;
    if (data?.error) return data.error;
    if (typeof data === "string") return data;
  } catch {
    // Ignore parse errors and fall back to status text.
  }
  return response.statusText;
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    setupTabs,
    populateSelect,
    configureNarrativeModeControls,
    setEmptyCharacterSheet,
    renderCharacter,
    renderAdminRoster,
    clampBatchCount,
    createStatCard,
    createListCard,
    createTextCard
  };
}
