/* Shared UI preferences for app.devhorizon.online.
 *
 * Language (ru / en / de) and one of ten colour themes are stored in
 * localStorage under "ui_lang" and "ui_theme" so that both /index.html and
 * /ai-providers/index.html share the same choice.
 *
 * The <head> of either page applies the saved values before the first paint;
 * this file only keeps the header switchers (and the theme list in the current
 * language) in sync with them.
 */
(function (global) {
  "use strict";

  var LANG_KEY = "ui_lang";
  var THEME_KEY = "ui_theme";

  var LANGS = ["ru", "en", "de"];

  var THEMES = [
    "day",
    "day-yellow",
    "day-red",
    "day-green",
    "day-orange",
    "night-red",
    "night-blue",
    "night-yellow",
    "night-green",
    "night-orange",
  ];

  /* Shown in their own language, so they never change with the current one. */
  var LANG_LABELS = { ru: "Русский", en: "English", de: "Deutsch" };

  var FIELD_LABELS = {
    ru: { language: "Язык", theme: "Тема" },
    en: { language: "Language", theme: "Theme" },
    de: { language: "Sprache", theme: "Design" },
  };

  var THEME_LABELS = {
    ru: {
      day: "Дневная",
      "day-yellow": "Дневная (жёлтая)",
      "day-red": "Дневная (красная)",
      "day-green": "Дневная (зелёная)",
      "day-orange": "Дневная (оранжевая)",
      "night-red": "Ночная (красная)",
      "night-blue": "Ночная (голубая)",
      "night-yellow": "Ночная (жёлтая)",
      "night-green": "Ночная (зелёная)",
      "night-orange": "Ночная (оранжевая)",
    },
    en: {
      day: "Day",
      "day-yellow": "Day (yellow)",
      "day-red": "Day (red)",
      "day-green": "Day (green)",
      "day-orange": "Day (orange)",
      "night-red": "Night (red)",
      "night-blue": "Night (blue)",
      "night-yellow": "Night (yellow)",
      "night-green": "Night (green)",
      "night-orange": "Night (orange)",
    },
    de: {
      day: "Tag",
      "day-yellow": "Tag (gelb)",
      "day-red": "Tag (rot)",
      "day-green": "Tag (grün)",
      "day-orange": "Tag (orange)",
      "night-red": "Nacht (rot)",
      "night-blue": "Nacht (blau)",
      "night-yellow": "Nacht (gelb)",
      "night-green": "Nacht (grün)",
      "night-orange": "Nacht (orange)",
    },
  };

  function store(key, value) {
    try {
      global.localStorage.setItem(key, value);
    } catch (err) {
      /* private mode: preferences simply do not persist */
    }
  }

  function load(key) {
    try {
      return global.localStorage.getItem(key);
    } catch (err) {
      return null;
    }
  }

  /* navigator.language wins only when it starts with en / de / ru. */
  function detectLang() {
    var stored = load(LANG_KEY);
    if (LANGS.indexOf(stored) >= 0) {
      return stored;
    }
    var nav = String((global.navigator && global.navigator.language) || "");
    var code = nav.slice(0, 2).toLowerCase();
    return LANGS.indexOf(code) >= 0 ? code : "ru";
  }

  function detectTheme() {
    var stored = load(THEME_KEY);
    return THEMES.indexOf(stored) >= 0 ? stored : "day";
  }

  var listeners = [];

  var UI = {
    LANGS: LANGS,
    THEMES: THEMES,
    lang: detectLang(),
    theme: detectTheme(),

    langLabel: function (code) {
      return LANG_LABELS[code] || code;
    },

    /* Theme names follow the current language. */
    themeLabel: function (id) {
      var pack = THEME_LABELS[UI.lang] || THEME_LABELS.ru;
      return pack[id] || id;
    },

    fieldLabel: function (key) {
      var pack = FIELD_LABELS[UI.lang] || FIELD_LABELS.ru;
      return pack[key] || key;
    },

    onChange: function (fn) {
      if (typeof fn === "function") {
        listeners.push(fn);
      }
    },

    setLang: function (code) {
      if (LANGS.indexOf(code) < 0 || code === UI.lang) {
        return;
      }
      UI.lang = code;
      store(LANG_KEY, code);
      applyLang();
      refreshSwitchers();
      emit();
    },

    setTheme: function (id) {
      if (THEMES.indexOf(id) < 0 || id === UI.theme) {
        return;
      }
      UI.theme = id;
      store(THEME_KEY, id);
      applyTheme();
      refreshSwitchers();
      emit();
    },

    mount: function () {
      var langSelect = document.getElementById("ui-lang");
      var themeSelect = document.getElementById("ui-theme");

      if (langSelect) {
        langSelect.textContent = "";
        LANGS.forEach(function (code) {
          var option = document.createElement("option");
          option.value = code;
          option.textContent = LANG_LABELS[code];
          langSelect.appendChild(option);
        });
        langSelect.addEventListener("change", function () {
          UI.setLang(langSelect.value);
        });
      }

      if (themeSelect) {
        themeSelect.addEventListener("change", function () {
          UI.setTheme(themeSelect.value);
        });
      }

      refreshSwitchers();
      applyLang();
      applyTheme();
    },
  };

  function applyLang() {
    if (global.document) {
      global.document.documentElement.setAttribute("lang", UI.lang);
    }
  }

  function applyTheme() {
    if (global.document) {
      global.document.documentElement.setAttribute("data-theme", UI.theme);
    }
  }

  function refreshSwitchers() {
    var langSelect = document.getElementById("ui-lang");
    var themeSelect = document.getElementById("ui-theme");
    var langLabel = document.getElementById("ui-lang-label");
    var themeLabel = document.getElementById("ui-theme-label");

    var language = UI.fieldLabel("language");
    var theme = UI.fieldLabel("theme");

    if (langLabel) {
      langLabel.textContent = language;
    }
    if (themeLabel) {
      themeLabel.textContent = theme;
    }

    if (langSelect) {
      langSelect.value = UI.lang;
      langSelect.setAttribute("aria-label", language);
    }

    if (themeSelect) {
      /* Rebuilt on every language change so the labels follow it. */
      themeSelect.textContent = "";
      THEMES.forEach(function (id) {
        var option = document.createElement("option");
        option.value = id;
        option.textContent = UI.themeLabel(id);
        themeSelect.appendChild(option);
      });
      themeSelect.value = UI.theme;
      themeSelect.setAttribute("aria-label", theme);
    }
  }

  function emit() {
    listeners.slice().forEach(function (fn) {
      try {
        fn();
      } catch (err) {
        /* a broken listener must not stop the others */
      }
    });
  }

  /* Persist the resolved defaults so both pages definitely agree. */
  if (load(LANG_KEY) !== UI.lang) {
    store(LANG_KEY, UI.lang);
  }
  if (load(THEME_KEY) !== UI.theme) {
    store(THEME_KEY, UI.theme);
  }

  applyLang();
  applyTheme();

  global.UI = UI;
})(window);
