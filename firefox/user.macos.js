// Enter uses the current tab; Command+Enter opens address-bar text in a new tab.
// Disable Command+Enter's www./.com completion on macOS.
user_pref("browser.urlbar.ctrlCanonizesURLs", false);
user_pref("browser.urlbar.openintab", false);
// Preserve the existing preference for the separate search bar.
user_pref("browser.search.openintab", true);
