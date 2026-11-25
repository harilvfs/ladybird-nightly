const themeSwitch = document.querySelector("#theme-switch");
const themeButtons = [...themeSwitch.querySelectorAll("[data-theme-choice]")];

function moveThemeThumb(theme) {
  const active = themeButtons.find((button) => button.dataset.themeChoice === theme);
  const bounds = themeSwitch.getBoundingClientRect();
  const target = active.getBoundingClientRect();
  const border = Number.parseFloat(getComputedStyle(themeSwitch).borderLeftWidth) || 0;
  const thumb = themeSwitch.querySelector(".theme-thumb");
  thumb.style.width = `${target.width}px`;
  thumb.style.transform = `translateX(${Math.round(target.left - bounds.left - border - 2)}px)`;
  requestAnimationFrame(() => themeSwitch.classList.add("is-ready"));
}

function applyTheme(theme, remember) {
  document.documentElement.dataset.theme = theme;
  themeButtons.forEach((button) => {
    button.setAttribute("aria-pressed", String(button.dataset.themeChoice === theme));
  });
  document.querySelector('meta[name="theme-color"]').content = theme === "dark" ? "#14131b" : "#f8f8fb";
  if (remember) {
    try {
      localStorage.setItem("ladybird-theme", theme);
    } catch {}
  }
  moveThemeThumb(theme);
}

themeButtons.forEach((button) => {
  button.addEventListener("click", () => applyTheme(button.dataset.themeChoice, true));
});

applyTheme(document.documentElement.dataset.theme, false);
window.addEventListener("resize", () => moveThemeThumb(document.documentElement.dataset.theme), { passive: true });
window.addEventListener("load", () => moveThemeThumb(document.documentElement.dataset.theme));

const toTop = document.querySelector("#to-top");
const topbar = document.querySelector(".topbar");
const nativeScrollProgress = window.CSS?.supports?.("animation-timeline: scroll(root block)") ?? false;
let scrollProgressPending = false;

function updateScrollProgress() {
  const doc = document.documentElement;
  const maxScroll = doc.scrollHeight - window.innerHeight;
  const progress = maxScroll > 0 ? Math.min(1, window.scrollY / maxScroll) : 0;
  topbar.style.setProperty("--scroll-progress", progress.toFixed(4));
  scrollProgressPending = false;
}

window.addEventListener("scroll", () => {
  toTop.classList.toggle("is-visible", window.scrollY > 300);
  if (!nativeScrollProgress && !scrollProgressPending) {
    scrollProgressPending = true;
    requestAnimationFrame(updateScrollProgress);
  }
}, { passive: true });
if (!nativeScrollProgress) {
  updateScrollProgress();
  window.addEventListener("resize", updateScrollProgress, { passive: true });
}
toTop.addEventListener("click", () => {
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  window.scrollTo({ top: 0, behavior: reduceMotion ? "auto" : "smooth" });
});

document.querySelectorAll("[data-copy-target]").forEach((button) => {
  button.addEventListener("click", async () => {
    const command = document.getElementById(button.dataset.copyTarget).textContent;
    try {
      await navigator.clipboard.writeText(command);
      button.textContent = "COPIED";
      window.setTimeout(() => { button.textContent = "COPY"; }, 1500);
    } catch {
      button.textContent = "SELECT COMMAND";
    }
  });
});
