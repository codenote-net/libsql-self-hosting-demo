import { createClient, type Client } from "@libsql/client";

export type DemoTarget = "primary" | "replica";

export interface ClientOptions {
  target: DemoTarget;
  namespace?: string;
  token?: string;
}

const DEFAULT_PORTS: Record<DemoTarget, string> = {
  primary: "18080",
  replica: "18083",
};

export function endpointFor(target: DemoTarget, namespace?: string): string {
  const portEnv =
    target === "primary" ? "PRIMARY_HTTP_PORT" : "REPLICA_HTTP_PORT";
  const port = process.env[portEnv] ?? DEFAULT_PORTS[target];
  const host = namespace ? `${namespace}.localhost` : "127.0.0.1";
  return `http://${host}:${port}`;
}

export function createDemoClient(options: ClientOptions): Client {
  return createClient({
    url: endpointFor(options.target, options.namespace),
    authToken: options.token,
  });
}

export async function initializeSchema(client: Client): Promise<void> {
  await client.execute(`
    CREATE TABLE IF NOT EXISTS demo_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      label TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
  `);
}

export async function insertItem(
  client: Client,
  label: string,
): Promise<number> {
  const result = await client.execute({
    sql: "INSERT INTO demo_items (label) VALUES (?) RETURNING id",
    args: [label],
  });
  const id = result.rows[0]?.id;
  if (typeof id !== "number" && typeof id !== "bigint") {
    throw new Error("Insert did not return a row id");
  }
  return Number(id);
}

export async function listItems(client: Client): Promise<unknown[]> {
  const result = await client.execute(
    "SELECT id, label, created_at FROM demo_items ORDER BY id",
  );
  return [...result.rows];
}

export async function countItems(client: Client): Promise<number> {
  const result = await client.execute(
    "SELECT COUNT(*) AS count FROM demo_items",
  );
  const count = result.rows[0]?.count;
  if (typeof count !== "number" && typeof count !== "bigint") {
    throw new Error("Count query did not return a numeric count");
  }
  return Number(count);
}
