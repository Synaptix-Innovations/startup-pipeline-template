import assert from "node:assert/strict";
import { after, before, test } from "node:test";

import { createApp } from "./server.js";

let server;
let baseUrl;

before(async () => {
  server = createApp();
  await new Promise((resolve) => server.listen(0, resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(() => server.close());

test("/health returns 200 with status ok", async () => {
  const res = await fetch(`${baseUrl}/health`);
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.status, "ok");
});

test("/ greets", async () => {
  const res = await fetch(`${baseUrl}/`);
  assert.equal(res.status, 200);
});

test("unknown route is 404", async () => {
  const res = await fetch(`${baseUrl}/nope`);
  assert.equal(res.status, 404);
});
