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

const navToggle = document.querySelector("#nav-toggle");
const mobileNav = document.querySelector("#mobile-nav");

function setMenuOpen(open) {
  navToggle.setAttribute("aria-expanded", String(open));
  navToggle.setAttribute("aria-label", open ? "Close menu" : "Open menu");
  mobileNav.classList.toggle("is-open", open);
}

navToggle.addEventListener("click", () => {
  setMenuOpen(navToggle.getAttribute("aria-expanded") !== "true");
});

mobileNav.querySelectorAll("a").forEach((link) => {
  link.addEventListener("click", () => setMenuOpen(false));
});

document.addEventListener("click", (event) => {
  if (navToggle.getAttribute("aria-expanded") !== "true") return;
  if (!navToggle.contains(event.target) && !mobileNav.contains(event.target)) setMenuOpen(false);
});

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape" && navToggle.getAttribute("aria-expanded") === "true") {
    setMenuOpen(false);
    navToggle.focus();
  }
});

const desktopQuery = window.matchMedia("(min-width: 761px)");
function closeMenuOnDesktop(event) {
  if (event.matches) setMenuOpen(false);
}
if (desktopQuery.addEventListener) desktopQuery.addEventListener("change", closeMenuOnDesktop);
else desktopQuery.addListener(closeMenuOnDesktop);
