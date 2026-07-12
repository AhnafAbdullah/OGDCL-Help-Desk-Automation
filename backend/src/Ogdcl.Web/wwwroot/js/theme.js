// Theme persistence for the OGDCL dashboard.
// The initial theme is applied by an inline script in App.razor (before first
// paint) to avoid a flash; this module handles reading and toggling afterward.
window.ogdclTheme = {
    key: "ogdcl-theme",
    get() {
        return document.documentElement.getAttribute("data-theme") || "light";
    },
    set(theme) {
        try { localStorage.setItem(this.key, theme); } catch (e) { /* storage blocked */ }
        document.documentElement.setAttribute("data-theme", theme);
        return theme;
    },
    toggle() {
        return this.set(this.get() === "dark" ? "light" : "dark");
    }
};
