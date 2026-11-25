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
