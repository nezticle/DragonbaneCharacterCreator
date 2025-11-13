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
  flyndre: {
    server: "http://flyndre.local:1234",
    model: "deepseek-r1-distill-qwen-7b"
  },
  openai: {
    server: "https://api.openai.com",
    model: "gpt-4o-mini"
  }
};

const IMAGE_DEFAULTS = {
  server: "https://api.openai.com",
  model: "gpt-image-1"
};

document.addEventListener("DOMContentLoaded", () => {
  populateSelect(document.getElementById("randomKin"), kinOptions, true);
  populateSelect(document.getElementById("randomProfession"), professionOptions, true);
  populateSelect(document.getElementById("generateKin"), kinOptions);
  populateSelect(document.getElementById("generateProfession"), professionOptions);
  populateSelect(document.getElementById("generateAge"), ageOptions);
  loadCharacterList();
  const narrativeSelect = document.getElementById("generateNarrativeMode");
  if (narrativeSelect) {
    narrativeSelect.addEventListener("change", handleNarrativeModeChange);
    handleNarrativeModeChange();
  }

  document.getElementById("randomForm").addEventListener("submit", handleRandomSubmit);
  document.getElementById("generateForm").addEventListener("submit", handleGenerateSubmit);
  document.getElementById("editCharacter").addEventListener("change", handleSelectChange);
  document.getElementById("editForm").addEventListener("submit", handleEditSubmit);
  const imageCharacter = document.getElementById("imageCharacter");
  if (imageCharacter) {
    imageCharacter.addEventListener("change", handleImageSelectChange);
  }
  const imageForm = document.getElementById("imageForm");
  if (imageForm) {
    imageForm.addEventListener("submit", handleImageSubmit);
  }
});

function populateSelect(select, options, isMultiple = false) {
  if (!select) return;
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

function handleNarrativeModeChange() {
  const mode = document.getElementById("generateNarrativeMode").value;
  const showLLMFields = mode !== "offline";
  toggleField("llmServerGroup", showLLMFields);
  toggleField("llmModelGroup", showLLMFields);
  toggleField("llmKeyGroup", mode === "openai" || mode === "custom");

  if (mode !== "custom" && mode !== "offline" && LLM_DEFAULTS[mode]) {
    document.getElementById("llmServer").value = LLM_DEFAULTS[mode].server;
    document.getElementById("llmModel").value = LLM_DEFAULTS[mode].model;
  }
}

function toggleField(id, show) {
  const el = document.getElementById(id);
  if (!el) return;
  el.classList.toggle("hidden", !show);
}

async function handleRandomSubmit(event) {
  event.preventDefault();
  const kin = selectedValues(document.getElementById("randomKin"));
  const professions = selectedValues(document.getElementById("randomProfession"));
  const params = new URLSearchParams();
  if (kin.length) params.set("kin", kin.join(","));
  if (professions.length) params.set("profession", professions.join(","));

  const resultContainer = document.getElementById("randomResult");
  resultContainer.textContent = "Fetching character...";

  try {
    const response = await fetch(`/api/characters/random${params.toString() ? `?${params.toString()}` : ""}`);
    if (!response.ok) {
      const message = await extractError(response);
      throw new Error(message || "Failed to fetch a character");
    }
    const character = await response.json();
    renderCharacter(resultContainer, character);
  } catch (error) {
    resultContainer.textContent = error.message;
  }
}

async function handleGenerateSubmit(event) {
  event.preventDefault();
  const payload = {};
  const kin = document.getElementById("generateKin").value;
  const profession = document.getElementById("generateProfession").value;
  const age = document.getElementById("generateAge").value;
  const name = document.getElementById("generateName").value.trim();
  const appearance = document.getElementById("generateAppearance").value.trim();
  const background = document.getElementById("generateBackground").value.trim();

  if (kin) payload.race = kin;
  if (profession) payload.profession = profession;
  if (age) payload.age = age;
  if (name) payload.name = name;
  if (appearance) payload.appearance = appearance;
  if (background) payload.background = background;

  const resultContainer = document.getElementById("generateResult");
  const narrativeMode = document.getElementById("generateNarrativeMode").value;
  const useLLM = narrativeMode !== "offline";
  if (useLLM) {
    payload.narrativeMode = "llm";
    const server = document.getElementById("llmServer").value.trim();
    const model = document.getElementById("llmModel").value.trim();
    const apiKey = document.getElementById("llmApiKey").value.trim();
    if (server) payload.llmServer = server;
    if (model) payload.llmModel = model;
    if (narrativeMode === "openai" && !apiKey) {
      setStatus(resultContainer, "OpenAI requests require an API key.");
      return;
    }
    if (apiKey) payload.llmApiKey = apiKey;
    setBusy(resultContainer, "Generating detailed narrative via LLM...");
  } else {
    setBusy(resultContainer, "Generating character...");
  }

  try {
    const response = await fetch("/api/characters/generate", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });
    if (!response.ok) {
      const message = await extractError(response);
      throw new Error(message || "Generation failed");
    }
    const character = await response.json();
    renderCharacter(resultContainer, character);
    await loadCharacterList();
  } catch (error) {
    setStatus(resultContainer, error.message);
  }
}

async function loadCharacterList() {
  const editSelect = document.getElementById("editCharacter");
  const imageSelect = document.getElementById("imageCharacter");
  if (!editSelect && !imageSelect) return;

  try {
    const response = await fetch("/api/characters?limit=100");
    if (!response.ok) {
      throw new Error("Unable to load characters");
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
  } catch (error) {
    const editStatus = document.getElementById("editStatus");
    if (editStatus) {
      editStatus.textContent = error.message;
    }
    const imageStatus = document.getElementById("imageStatus");
    if (imageStatus) {
      imageStatus.textContent = error.message;
    }
  }
}

async function handleSelectChange(event) {
  const id = event.target.value;
  if (!id) {
    document.getElementById("editForm").classList.add("hidden");
    document.getElementById("editStatus").textContent = "";
    return;
  }
  await populateEditForm(id);
}

async function populateEditForm(id) {
  try {
    const response = await fetch(`/api/characters/${id}`);
    if (!response.ok) {
      throw new Error("Unable to load character details");
    }
    const character = await response.json();
    document.getElementById("editForm").classList.remove("hidden");
    document.getElementById("editName").value = character.name;
    document.getElementById("editAppearance").value = character.appearance;
    document.getElementById("editBackground").value = character.background;
    document.getElementById("editWeakness").value = character.weakness;
    document.getElementById("editMemento").value = character.memento;
    document.getElementById("editGear").value = character.gear.join(", ");
    document.getElementById("editStatus").textContent = "";
  } catch (error) {
    document.getElementById("editStatus").textContent = error.message;
  }
}

async function handleEditSubmit(event) {
  event.preventDefault();
  const select = document.getElementById("editCharacter");
  const id = select.value;
  if (!id) return;

  const payload = {
    name: document.getElementById("editName").value.trim(),
    appearance: document.getElementById("editAppearance").value.trim(),
    background: document.getElementById("editBackground").value.trim(),
    weakness: document.getElementById("editWeakness").value.trim(),
    memento: document.getElementById("editMemento").value.trim(),
    gear: parseList(document.getElementById("editGear").value)
  };

  const status = document.getElementById("editStatus");
  status.textContent = "Saving changes...";

  try {
    const response = await fetch(`/api/characters/${id}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });
    if (!response.ok) {
      const message = await extractError(response);
      throw new Error(message || "Failed to save changes");
    }
    const updated = await response.json();
    status.textContent = "Character updated.";
    updateOptionLabel(select, updated);
  } catch (error) {
    status.textContent = error.message;
  }
}

async function handleImageSelectChange(event) {
  await loadImageGallery(event.target.value);
}

async function handleImageSubmit(event) {
  event.preventDefault();
  const characterId = document.getElementById("imageCharacter").value;
  const status = document.getElementById("imageStatus");
  if (!characterId) {
    setStatus(status, "Select a character first.");
    return;
  }

  const payload = {};
  const server = document.getElementById("imageServer").value.trim();
  const model = document.getElementById("imageModel").value.trim();
  const apiKey = document.getElementById("imageApiKey").value.trim();
  if (server) payload.server = server;
  if (model) payload.model = model;
  if (apiKey) payload.apiKey = apiKey;

  setBusy(status, "Requesting portrait from the image model...");

  try {
    const response = await fetch(`/api/characters/${characterId}/images`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(Object.keys(payload).length ? payload : { })
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
  const option = Array.from(select.options).find((opt) => opt.value === String(character.id));
  if (option) {
    option.textContent = `#${character.id} — ${character.name || character.race}`;
  }
}

function parseList(value) {
  return value
    .split(/[,\n]/)
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
}

function renderCharacter(container, character) {
  container.classList.remove("loading");
  const lines = [];
  lines.push(`Name: ${character.name}`);
  lines.push(`Kin: ${character.race}`);
  lines.push(`Profession: ${character.profession}`);
  lines.push(`Age: ${character.age}`);
  lines.push("Attributes:");
  lines.push(`  STR ${character.strength}  CON ${character.constitution}  AGL ${character.agility}`);
  lines.push(`  INT ${character.intelligence}  WIL ${character.willpower}  CHA ${character.charisma}`);
  lines.push(`Heroic Abilities: ${formatList(character.heroicAbilities)}`);
  lines.push(`Trained Skills: ${formatList(character.trainedSkills)}`);
  lines.push(`Magic: ${formatList(character.magic)}`);
  lines.push(`Gear: ${formatList(character.gear)}`);
  lines.push(`Weakness: ${character.weakness}`);
  lines.push(`Memento: ${character.memento}`);
  lines.push(`Appearance: ${character.appearance}`);
  lines.push(`Background: ${character.background}`);
  container.textContent = lines.join("\n");
}

function formatTimestamp(value) {
  if (!value) return "Just now";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }
  return date.toLocaleString();
}

function setBusy(element, message) {
  if (!element) return;
  element.classList.add("loading");
  element.innerHTML = `<div class="spinner" aria-hidden="true"></div><span>${message}</span>`;
}

function setStatus(element, message) {
  if (!element) return;
  element.classList.remove("loading");
  element.textContent = message;
}

function formatList(list) {
  if (!Array.isArray(list) || list.length === 0) {
    return "None";
  }
  return list.join(", ");
}

async function extractError(response) {
  try {
    const data = await response.json();
    if (data?.reason) return data.reason;
    if (data?.error) return data.error;
    if (typeof data === "string") return data;
  } catch (error) {
    // Ignore parse errors and fall back to status text.
  }
  return response.statusText;
}
