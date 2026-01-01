export default {
  defaultBrowser: 'Brave Browser',
  handlers: [
    {
      match: ['youtube.com/*', 'github.com/*'],
      browser: 'Helium',
    },
    {
      match: ['spotify.com/*'],
      browser: 'Safari',
    },
  ],
};
