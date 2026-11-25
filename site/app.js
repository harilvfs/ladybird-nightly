async function loadPackages() {
  const status = document.querySelector("#release-status");
  try {
    const response = await fetch("./releases.json", { cache: "no-store" });
    if (!response.ok) throw new Error(`Could not load package index: ${response.status}`);
    const releases = await response.json();
    const latest = Object.fromEntries(["ubuntu", "fedora", "arch"].map((distro) => [distro, null]));

    for (const release of releases) {
      for (const distro of Object.keys(latest)) {
        if (!latest[distro] && release.packages?.[distro]) latest[distro] = release;
      }
      if (Object.values(latest).every(Boolean)) break;
    }

    for (const [distro, release] of Object.entries(latest)) {
      const card = document.querySelector(`[data-distro="${distro}"]`);
      const link = card.querySelector(".download-link");
      const state = card.querySelector(".asset-state");
      const pkg = release?.packages?.[distro];
      if (pkg) {
        link.href = pkg.url;
        link.innerHTML = `Download package <span aria-hidden="true">↓</span>`;
        link.removeAttribute("aria-disabled");
        link.removeAttribute("target");
        link.removeAttribute("rel");
        state.textContent = `${release.tag} · ${formatDate(release.published_at)}`;
      } else {
        link.textContent = "Package unavailable";
        state.textContent = "No package found in recent releases";
        state.classList.add("error-state");
      }
    }

    const newest = releases[0];
    status.textContent = newest ? `Latest package build · ${formatDate(newest.published_at)}` : "No package releases published yet";
    if (newest) document.querySelector("#preview-date").textContent = newest.tag.toUpperCase();
  } catch (error) {
    status.textContent = "Could not load release information";
    document.querySelectorAll(".download-link").forEach((link) => {
      link.textContent = "Download unavailable";
    });
    document.querySelectorAll(".asset-state").forEach((state) => {
      state.textContent = "Package links are temporarily unavailable.";
      state.classList.add("error-state");
    });
    console.error("Could not load Ladybird nightly releases:", error);
  }
}

const themeToggle = document.querySelector("#theme-toggle");

function updateThemeToggle() {
  const theme = document.documentElement.dataset.theme;
  const nextTheme = theme === "dark" ? "light" : "dark";
  themeToggle.textContent = `${nextTheme === "light" ? "Light" : "Dark"} mode`;
  themeToggle.setAttribute("aria-label", `Switch to ${nextTheme} theme`);
  themeToggle.setAttribute("aria-pressed", String(theme === "light"));
  document.querySelector('meta[name="theme-color"]').content = theme === "dark" ? "#14131b" : "#f8f8fb";
}

themeToggle.addEventListener("click", () => {
  const nextTheme = document.documentElement.dataset.theme === "dark" ? "light" : "dark";
  document.documentElement.dataset.theme = nextTheme;
  try {
    localStorage.setItem("ladybird-theme", nextTheme);
  } catch {}
  updateThemeToggle();
});

updateThemeToggle();

const toTop = document.querySelector("#to-top");
window.addEventListener("scroll", () => {
  toTop.classList.toggle("is-visible", window.scrollY > 300);
}, { passive: true });
toTop.addEventListener("click", () => window.scrollTo({ top: 0, behavior: "auto" }));

function formatDate(value) {
  if (!value) return "recently";
  return new Intl.DateTimeFormat(undefined, { dateStyle: "medium" }).format(new Date(value));
}

document.querySelector("#copy-command").addEventListener("click", async (event) => {
  const button = event.currentTarget;
  const command = document.querySelector("#install-command").textContent;
  try {
    await navigator.clipboard.writeText(command);
    button.textContent = "COPIED";
    window.setTimeout(() => { button.textContent = "COPY"; }, 1500);
  } catch {
    button.textContent = "SELECT COMMAND";
  }
});

loadPackages();
