import adapter from '@sveltejs/adapter-static'; // Change from adapter-auto
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/kit').Config} */
const config = {
	preprocess: vitePreprocess(),
	kit: {
		adapter: adapter({
			pages: 'build',  // This is the directory Nginx will look for
			assets: 'build',
			fallback: 'index.html', // Required for Single Page App behavior
			precompress: false,
			strict: true
		})
	}
};

export default config;
