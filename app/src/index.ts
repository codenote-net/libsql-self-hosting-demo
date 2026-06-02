import { readFileSync } from "node:fs";
import {
  countItems,
  createDemoClient,
  endpointFor,
  initializeSchema,
  insertItem,
  listItems,
  type DemoTarget,
} from "./libsql.js";

interface ParsedArgs {
  command: string;
  target: DemoTarget;
  namespace?: string;
  label: string;
  tokenPath: string;
  token?: string;
}

function readToken(path: string): string {
  return readFileSync(path, "utf8").trim();
}

function parseArgs(argv: string[]): ParsedArgs {
  const [command = "demo", ...rest] = argv;
  const parsed: ParsedArgs = {
    command,
    target: "primary",
    label: `demo-${Date.now()}`,
    tokenPath: "../.local/jwt/jwt.token",
  };

  for (let index = 0; index < rest.length; index += 1) {
    const flag = rest[index];
    const value = rest[index + 1];
    if (!flag?.startsWith("--")) {
      continue;
    }
    if (value === undefined) {
      throw new Error(`Missing value for ${flag}`);
    }
    index += 1;
    if (flag === "--target") {
      if (value !== "primary" && value !== "replica") {
        throw new Error("--target must be primary or replica");
      }
      parsed.target = value;
    } else if (flag === "--namespace") {
      parsed.namespace = value;
    } else if (flag === "--label") {
      parsed.label = value;
    } else if (flag === "--token-path") {
      parsed.tokenPath = value;
    } else if (flag === "--token") {
      parsed.token = value;
    } else {
      throw new Error(`Unknown flag ${flag}`);
    }
  }

  return parsed;
}

async function run(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));
  const token = args.token ?? readToken(args.tokenPath);
  const client = createDemoClient({
    target: args.target,
    namespace: args.namespace,
    token,
  });

  if (args.command === "init") {
    await initializeSchema(client);
    console.log(
      `Initialized schema on ${endpointFor(args.target, args.namespace)}`,
    );
    return;
  }

  if (args.command === "insert") {
    await initializeSchema(client);
    const id = await insertItem(client, args.label);
    console.log(
      `Inserted row ${id} on ${endpointFor(args.target, args.namespace)}`,
    );
    return;
  }

  if (args.command === "read") {
    const rows = await listItems(client);
    console.log(JSON.stringify(rows, null, 2));
    return;
  }

  if (args.command === "count") {
    const count = await countItems(client);
    console.log(String(count));
    return;
  }

  if (args.command === "auth-check") {
    await countItems(client);
    console.log("Authentication succeeded");
    return;
  }

  if (args.command === "demo") {
    await initializeSchema(client);
    const id = await insertItem(client, args.label);
    const rows = await listItems(client);
    console.log(
      JSON.stringify(
        {
          endpoint: endpointFor(args.target, args.namespace),
          insertedId: id,
          rows,
        },
        null,
        2,
      ),
    );
    return;
  }

  throw new Error(`Unknown command ${args.command}`);
}

run().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(message);
  process.exit(1);
});
