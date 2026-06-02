import { createPrivateKey, sign } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";

const [, , keyPath, tokenPath] = process.argv;

if (!keyPath || !tokenPath) {
  console.error("Usage: node scripts/sign-jwt.mjs <private-key> <token-output>");
  process.exit(1);
}

function base64url(input) {
  return Buffer.from(input).toString("base64url");
}

const header = { alg: "EdDSA", typ: "JWT" };
const now = Math.floor(Date.now() / 1000);
const payload = {
  a: "rw",
  iat: now,
  exp: now + 60 * 60 * 24,
};

const signingInput = `${base64url(JSON.stringify(header))}.${base64url(
  JSON.stringify(payload),
)}`;
const key = createPrivateKey(readFileSync(keyPath));
const signature = sign(null, Buffer.from(signingInput), key).toString("base64url");

writeFileSync(tokenPath, `${signingInput}.${signature}\n`, { mode: 0o600 });
