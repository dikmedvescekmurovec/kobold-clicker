// The game's web build, a file of the R2 bucket per path. Each one is checked again on every load
// (no-cache, answered 304 by its ETag) so a new upload reaches players at once.
export default {
  async fetch(request, env) {
    const key = new URL(request.url).pathname.slice(1) || "index.html";
    const object = await env.GAME.get(key, { onlyIf: request.headers });
    if (object === null) return new Response("Not found", { status: 404 });
    const headers = new Headers();
    object.writeHttpMetadata(headers);
    headers.set("etag", object.httpEtag);
    headers.set("cache-control", "no-cache");
    return "body" in object ? new Response(object.body, { headers }) : new Response(null, { status: 304, headers });
  },
};
