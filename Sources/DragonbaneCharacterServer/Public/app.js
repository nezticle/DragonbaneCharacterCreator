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

document.addEventListener("DOMContentLoaded", () => {
  populateSelect(document.getElementById("randomKin"), kinOptions, true);
  populateSelect(document.getElementById("randomProfession"), professionOptions, true);
  populateSelect(document.getElementById("generateKin"), kinOptions);
  populateSelect(document.getElementById("generateProfession"), professionOptions);
  populateSelect(document.getElementById("generateAge"), ageOptions);
  loadCharacterList();

  document.getElementById("randomForm").addEventListener("submit", handleRandomSubmit);
  document.getElementById("generateForm").addEventListener("submit", handleGenerateSubmit);
  document.getElementById("editCharacter").addEventListener("change", handleSelectChange);
  document.getElementById("editForm").addEventListener("submit", handleEditSubmit);
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
  resultContainer.textContent = "Generating character...";

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
    resultContainer.textContent = error.message;
  }
}

async function loadCharacterList() {
  const select = document.getElementById("editCharacter");
  if (!select) return;

  const previousValue = select.value;
  select.innerHTML = '<option value="">Choose a saved character</option>';

  try {
    const response = await fetch("/api/characters?limit=100");
    if (!response.ok) {
      throw new Error("Unable to load characters");
    }
    const characters = await response.json();
    characters.forEach((character) => {
      const option = document.createElement("option");
      option.value = character.id;
      option.textContent = `#${character.id} — ${character.name || character.race}`;
      select.appendChild(option);
    });
    if (previousValue) {
      select.value = previousValue;
      if (select.value === previousValue) {
        await populateEditForm(previousValue);
      }
    }
  } catch (error) {
    const status = document.getElementById("editStatus");
    status.textContent = error.message;
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
