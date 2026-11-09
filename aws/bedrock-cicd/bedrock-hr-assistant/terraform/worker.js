// Forwards each request to the Lambda Function URL. A Function URL only answers to its
// own host name, and the origin secret proves the request came through Cloudflare.
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    url.hostname = env.FUNCTION_URL_HOST;

    const upstream = new Request(url, request);
    upstream.headers.set(env.ORIGIN_HEADER, env.ORIGIN_SECRET);

    // Keep redirects for the browser, so the sign-in cookie reaches it.
    return fetch(upstream, { redirect: "manual" });
  },
};
