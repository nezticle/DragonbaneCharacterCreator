import test from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import { fileURLToPath } from "node:url";
import fs from "node:fs";
import vm from "node:vm";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const clientPath = path.resolve(__dirname, "../Sources/DragonbaneCharacterServer/Public/app.js");
const clientSource = fs.readFileSync(clientPath, "utf8");

class ClassList {
  constructor(element) {
    this.element = element;
    this.tokens = new Set();
  }

  add(...names) {
    names.forEach((name) => {
      if (name) this.tokens.add(name);
    });
    this.#sync();
  }

  remove(...names) {
    names.forEach((name) => this.tokens.delete(name));
    this.#sync();
  }

  toggle(name, force) {
    if (force === true) {
      this.add(name);
      return true;
    }
    if (force === false) {
      this.remove(name);
      return false;
    }
    if (this.tokens.has(name)) {
      this.tokens.delete(name);
      this.#sync();
      return false;
    }
    this.tokens.add(name);
    this.#sync();
    return true;
  }

  contains(name) {
    return this.tokens.has(name);
  }

  replaceTokens(tokens) {
    this.tokens = new Set(tokens);
    this.#sync();
  }

  #sync() {
    this.element._className = Array.from(this.tokens).join(" ");
  }
}

class Element {
  constructor(tagName, document) {
    this.tagName = tagName.toLowerCase();
    this.document = document;
    this.children = [];
    this.parentNode = null;
    this.attributes = new Map();
    this.classList = new ClassList(this);
    this._className = "";
    this.eventListeners = new Map();
    this._textContent = "";
    this.value = "";
    this.tabIndex = 0;
    this.hidden = false;
    this._datasetStore = {};
    this.dataset = new Proxy(this._datasetStore, {
      get: (_, prop) => this._datasetStore[prop],
      set: (_, prop, value) => {
        const attr = datasetAttrName(String(prop));
        this._datasetStore[prop] = String(value);
        this.attributes.set(attr, String(value));
        return true;
      }
    });
  }

  appendChild(child) {
    child.parentNode = this;
    this.children.push(child);
    return child;
  }

  set innerHTML(value) {
    this.children = [];
    this._textContent = typeof value === "string" ? value : "";
  }

  get innerHTML() {
    return this._textContent;
  }

  set textContent(value) {
    this.children = [];
    this._textContent = String(value);
  }

  get textContent() {
    if (this.children.length === 0) {
      return this._textContent;
    }
    return this._textContent + this.children.map((child) => child.textContent).join("");
  }

  setAttribute(name, value) {
    const stringValue = String(value);
    if (name === "id") {
      this.id = stringValue;
      return;
    }
    if (name === "class") {
      this.className = stringValue;
      return;
    }
    this.attributes.set(name, stringValue);
    if (name.startsWith("data-")) {
      const key = datasetKeyFromAttr(name);
      this._datasetStore[key] = stringValue;
    }
  }

  getAttribute(name) {
    if (name === "id") return this._id;
    if (name === "class") return this.className;
    return this.attributes.get(name);
  }

  addEventListener(type, handler) {
    const handlers = this.eventListeners.get(type) ?? [];
    handlers.push(handler);
    this.eventListeners.set(type, handlers);
  }

  dispatchEvent(event) {
    const handlers = this.eventListeners.get(event.type) ?? [];
    handlers.forEach((handler) => handler.call(this, event));
  }

  click() {
    this.dispatchEvent({ type: "click", target: this, preventDefault() {} });
  }

  matches(selector) {
    return matchesSelector(this, selector);
  }

  querySelectorAll(selector) {
    return this.document.querySelectorAll(selector, this);
  }

  querySelector(selector) {
    return this.querySelectorAll(selector)[0] ?? null;
  }

  get className() {
    return this._className;
  }

  set className(value) {
    const tokens = String(value)
      .split(/\s+/)
      .map((token) => token.trim())
      .filter(Boolean);
    this.classList.replaceTokens(tokens);
  }

  get id() {
    return this._id;
  }

  set id(value) {
    this._id = String(value);
    this.attributes.set("id", this._id);
    this.document?.registerId(this);
  }
}

class Document {
  constructor() {
    this.body = new Element("body", this);
    this._ids = new Map();
    this.eventListeners = new Map();
  }

  createElement(tagName) {
    return new Element(tagName, this);
  }

  registerId(element) {
    if (element.id) {
      this._ids.set(element.id, element);
    }
  }

  getElementById(id) {
    return this._ids.get(String(id)) ?? null;
  }

  querySelectorAll(selector, root = this.body) {
    const matches = [];
    const visit = (node) => {
      if (node.matches && matchesSelector(node, selector)) {
        matches.push(node);
      }
      node.children.forEach(visit);
    };
    visit(root);
    return matches;
  }

  querySelector(selector) {
    return this.querySelectorAll(selector)[0] ?? null;
  }

  appendChild(child) {
    return this.body.appendChild(child);
  }

  addEventListener(type, handler) {
    const handlers = this.eventListeners.get(type) ?? [];
    handlers.push(handler);
    this.eventListeners.set(type, handlers);
  }

  dispatchEvent(event) {
    const handlers = this.eventListeners.get(event.type) ?? [];
    handlers.forEach((handler) => handler.call(this, event));
  }
}

function matchesSelector(element, selector) {
  const trimmed = selector.trim();
  if (!trimmed) return false;
  const attrMatch = trimmed.match(/^([a-zA-Z]+)?\[(data-[^\]=]+)="?([^"]+)"?\]$/);
  if (attrMatch) {
    const [, tag, attr, value] = attrMatch;
    if (tag && element.tagName !== tag.toLowerCase()) return false;
    return element.getAttribute(attr) === value;
  }
  if (trimmed.startsWith(".")) {
    return element.classList.contains(trimmed.slice(1));
  }
  if (trimmed.startsWith("#")) {
    return element.id === trimmed.slice(1);
  }
  if (trimmed.startsWith("[") && trimmed.endsWith("]")) {
    const match = trimmed.match(/^\[(data-[^\]=]+)="?([^"]+)"?\]$/);
    if (!match) return false;
    return element.getAttribute(match[1]) === match[2];
  }
  return element.tagName === trimmed.toLowerCase();
}

function datasetAttrName(prop) {
  return `data-${String(prop).replace(/[A-Z]/g, (char) => `-${char.toLowerCase()}`)}`;
}

function datasetKeyFromAttr(attr) {
  return attr
    .slice(5)
    .split("-")
    .map((segment, index) => (index === 0 ? segment : segment.charAt(0).toUpperCase() + segment.slice(1)))
    .join("");
}

function createEnvironment() {
  const document = new Document();
  const window = { document };
  window.fetch = async () => ({
    ok: true,
    json: async () => [],
    text: async () => ""
  });
  window.confirm = () => true;

  global.window = window;
  global.document = document;
  global.fetch = window.fetch;
  global.confirm = window.confirm;

  const sandbox = {
    module: { exports: {} },
    exports: {},
    window: global.window,
    document: global.document,
    fetch: global.fetch,
    console,
    URLSearchParams,
    setTimeout,
    clearTimeout
  };
  vm.runInNewContext(clientSource, sandbox, { filename: clientPath });
  const client = sandbox.module.exports;
  return { document, window, client };
}

function destroyEnvironment() {
  delete global.window;
  delete global.document;
  delete global.fetch;
  delete global.confirm;
}

function runClientTest(name, fn) {
  test(name, () => {
    const env = createEnvironment();
    try {
      fn(env);
    } finally {
      destroyEnvironment();
    }
  });
}

function sampleCharacter(overrides = {}) {
  return {
    id: 1,
    name: "Test Hero",
    race: "Human",
    profession: "Fighter",
    age: "Adult",
    strength: 12,
    constitution: 11,
    agility: 10,
    intelligence: 13,
    willpower: 9,
    charisma: 15,
    heroicAbilities: ["Defender"],
    trainedSkills: ["Swordplay"],
    magic: [],
    gear: ["Sword", "Shield"],
    weakness: "Pride",
    memento: "Family crest",
    appearance: "Tall and determined.",
    background: "Raised in a border keep.",
    ...overrides
  };
}

runClientTest("clampBatchCount bounds values to 1...20", ({ client }) => {
  assert.equal(client.clampBatchCount(0), 1);
  assert.equal(client.clampBatchCount(7), 7);
  assert.equal(client.clampBatchCount(50), 20);
});

runClientTest("setEmptyCharacterSheet marks placeholder state", ({ client, document }) => {
  const container = document.createElement("div");
  client.setEmptyCharacterSheet(container, "Waiting...");
  assert(container.classList.contains("character-sheet"));
  assert(container.classList.contains("empty"));
  assert(container.textContent.includes("Waiting"));
});

runClientTest("renderCharacter builds stat and story blocks", ({ client, document }) => {
  const container = document.createElement("div");
  client.renderCharacter(container, sampleCharacter());
  assert(container.classList.contains("character-sheet"));
  assert.equal(container.querySelectorAll(".stat-card").length, 6);
  assert(container.textContent.includes("Family crest"));
});

runClientTest("renderAdminRoster populates rows", ({ client, document }) => {
  const status = document.createElement("div");
  status.id = "rosterStatus";
  const body = document.createElement("tbody");
  body.id = "rosterTableBody";
  document.body.appendChild(status);
  document.body.appendChild(body);

  client.renderAdminRoster([sampleCharacter({ id: 42, name: "Archivist" })]);

  const rows = body.children;
  assert.equal(rows.length, 1);
  assert(rows[0].textContent.includes("#42"));
  assert(rows[0].textContent.includes("Archivist"));
});

runClientTest("setupTabs toggles active panel", ({ client, document }) => {
  const tabs = document.createElement("div");
  tabs.classList.add("tabs");
  const alphaButton = document.createElement("button");
  alphaButton.classList.add("tab-button", "active");
  alphaButton.dataset.tab = "alpha";
  const betaButton = document.createElement("button");
  betaButton.classList.add("tab-button");
  betaButton.dataset.tab = "beta";
  tabs.appendChild(alphaButton);
  tabs.appendChild(betaButton);
  const alphaPanel = document.createElement("section");
  alphaPanel.classList.add("tab-panel", "active");
  alphaPanel.dataset.tab = "alpha";
  const betaPanel = document.createElement("section");
  betaPanel.classList.add("tab-panel");
  betaPanel.dataset.tab = "beta";
  document.body.appendChild(tabs);
  document.body.appendChild(alphaPanel);
  document.body.appendChild(betaPanel);

  client.setupTabs();
  betaButton.click();

  assert(betaButton.classList.contains("active"));
  assert(!alphaButton.classList.contains("active"));
  assert(betaPanel.classList.contains("active"));
  assert(!alphaPanel.classList.contains("active"));
});
